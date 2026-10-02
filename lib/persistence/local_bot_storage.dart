import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../assembler/assembler.dart';
import '../battle/conf_struct.dart';
import '../ui/models/bot_draft.dart';
import 'bot_file.dart';

// Camada de persistencia do app -- sem equivalente 1:1 no C++ (la o
// "gerenciador de bots" era so o seletor de arquivo do sistema
// operacional, `QFileDialog`). Guarda cada bot como DOIS arquivos no
// mesmo diretorio, com o mesmo nome base:
//
//   <nome>.bot  -- o arquivo de verdade do jogo (framing + header +
//                  RAM), formato 100% igual ao original, gerado por
//                  `BotDraft.assemble()` + `BotFile.addFraming`.
//   <nome>.asm  -- o CODIGO-FONTE, texto puro. O `.bot` compilado nao
//                  tem como "descompilar" de volta pro texto original
//                  (nao existe no C++ nenhuma forma de recuperar o
//                  fonte a partir do bytecode), entao guardamos o
//                  fonte separado pra poder reabrir no editor. Isso
//                  e uma extensao do app, nao muda o formato do
//                  `.bot` em si.
//
// A config ativa (`ConfStruct`) fica em `config.cfg`, no mesmo
// formato de texto do `current.cfg` original (ver conf_struct.dart).
class LocalBotStorage {
  LocalBotStorage._(this._dir);

  final Directory _dir;

  static LocalBotStorage? _instance;

  /// Usa o diretório de documentos do app (`path_provider`) — os bots
  /// e a config ficam nessa pasta entre uma sessão e outra.
  static Future<LocalBotStorage> open() async {
    if (_instance != null) return _instance!;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}droid_battles_bots');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _instance = LocalBotStorage._(dir);
    return _instance!;
  }

  /// Diretório onde os bots ficam -- passe pra `FileBotFileAccess`
  /// pra ligar READFILE/WRITEFILE da VM nos arquivos `.dat` dos bots.
  Directory get directory => _dir;

  File _botFile(String name) => File('${_dir.path}${Platform.pathSeparator}$name.bot');
  File _asmFile(String name) => File('${_dir.path}${Platform.pathSeparator}$name.asm');

  Directory get _configsDir {
    final d = Directory('${_dir.path}${Platform.pathSeparator}configs');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  File _configFile(String profileName) => File('${_configsDir.path}${Platform.pathSeparator}$profileName.cfg');
  File get _activeMarker => File('${_configsDir.path}${Platform.pathSeparator}active.txt');

  /// Salva o bot (precisa já ter sido montado com sucesso —
  /// `draft.isAssembled`). Se o nome mudou desde o último save, passe
  /// [previousName] pra apagar os arquivos antigos.
  Future<void> save(BotDraft draft, {String? previousName}) async {
    final mem = draft.botFileBytes;
    if (mem == null) {
      throw StateError('Monte o bot (assemble) antes de salvar.');
    }
    if (previousName != null && previousName != draft.name) {
      await delete(previousName);
    }
    await _botFile(draft.name).writeAsBytes(BotFile.addFraming(mem), flush: true);
    await _asmFile(draft.name).writeAsString(draft.sourceCode, flush: true);
  }

  Future<void> delete(String name) async {
    final b = _botFile(name);
    final a = _asmFile(name);
    if (b.existsSync()) await b.delete();
    if (a.existsSync()) await a.delete();
  }

  /// Lista todos os bots salvos, já com o resultado da última
  /// montagem carregado (decodificado direto do header do `.bot` —
  /// não precisa reassemblar o código pra saber os devices/RAM).
  Future<List<BotDraft>> loadAll() async {
    if (!_dir.existsSync()) return [];
    final drafts = <BotDraft>[];
    for (final entry in _dir.listSync()) {
      if (entry is! File || !entry.path.endsWith('.bot')) continue;
      final name = entry.uri.pathSegments.last.replaceAll('.bot', '');
      final draft = await _loadOne(name);
      if (draft != null) drafts.add(draft);
    }
    drafts.sort((a, b) => a.name.compareTo(b.name));
    return drafts;
  }

  Future<BotDraft?> _loadOne(String name) async {
    try {
      final raw = await _botFile(name).readAsBytes();
      final mem = BotFile.stripFraming(raw);
      final ramIndex = BotFile.ramSizeIndex(mem);
      final devices = <DeviceSlot>[
        for (var i = 0; i < 32; i++)
          DeviceSlot(type: mem[2 + i * 6], level: mem[3 + i * 6], arg1: mem[4 + i * 6]),
      ];
      final asm = _asmFile(name);
      final source = asm.existsSync() ? await asm.readAsString() : '';
      final draft = BotDraft(name: name, ramIndex: ramIndex, devices: devices, sourceCode: source);
      // Reassembla a partir do fonte salvo (se houver) pra repopular
      // o cache interno de bytes/erro do draft de forma consistente
      // com o resto do app; se não bater com o `.bot` salvo (o fonte
      // pode ter sido editado por fora), o `.bot` no disco continua
      // sendo a fonte de verdade até o usuário montar de novo.
      if (source.isNotEmpty) draft.assemble();
      return draft;
    } catch (_) {
      return null;
    }
  }

  // ---- perfis de configuração (multiplos, como misc/*.cfg no original) ----
  //
  // Os 4 presets do jogo original (`kBuiltInPresets`, ver
  // conf_struct.dart) sempre aparecem na lista, mesmo sem nenhum
  // arquivo salvo -- são o ponto de partida. Salvar um perfil com o
  // MESMO nome de um preset embutido cria um `.cfg` de verdade que
  // passa a "sombrear" o preset (o disco sempre tem prioridade sobre
  // o embutido); apagar esse arquivo volta a mostrar o preset original.

  /// Nomes de todos os perfis disponíveis: os 4 presets embutidos +
  /// qualquer `.cfg` salvo em `configs/` que não seja um deles.
  Future<List<String>> listConfigProfiles() async {
    final names = <String>{...kBuiltInPresets.keys};
    if (_configsDir.existsSync()) {
      for (final entry in _configsDir.listSync()) {
        if (entry is File && entry.path.endsWith('.cfg')) {
          names.add(entry.uri.pathSegments.last.replaceAll('.cfg', ''));
        }
      }
    }
    final list = names.toList()..sort();
    return list;
  }

  Future<ConfStruct> loadConfigProfile(String name) async {
    final file = _configFile(name);
    if (file.existsSync()) {
      final conf = ConfStruct();
      conf.load(await file.readAsString());
      return conf;
    }
    final preset = kBuiltInPresets[name];
    if (preset != null) return preset.clone();
    return ConfStruct();
  }

  Future<void> saveConfigProfile(String name, ConfStruct config) async {
    await _configFile(name).writeAsString(config.save(), flush: true);
  }

  /// Só apaga o `.cfg` salvo em disco. Se `name` for um dos 4 presets
  /// embutidos, ele continua existindo (volta a aparecer com os
  /// valores originais); só desaparece de vez se não for um preset.
  Future<void> deleteConfigProfile(String name) async {
    final file = _configFile(name);
    if (file.existsSync()) await file.delete();
  }

  Future<String> activeConfigProfileName() async {
    if (_activeMarker.existsSync()) {
      final name = (await _activeMarker.readAsString()).trim();
      if (name.isNotEmpty) return name;
    }
    return 'light';
  }

  Future<void> setActiveConfigProfileName(String name) async {
    await _activeMarker.writeAsString(name, flush: true);
  }
}
