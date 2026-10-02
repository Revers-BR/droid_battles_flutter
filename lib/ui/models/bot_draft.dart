import 'dart:typed_data';

import '../../assembler/assembler.dart';
import '../../battle/conf_struct.dart';
import '../../persistence/bot_file.dart';

/// Um bot em edição no app -- sem equivalente 1:1 no C++ (lá, o
/// estado vivia espalhado pelos widgets do `CreateBot`). Guarda o
/// texto assembly, o loadout de devices e o resultado da última
/// montagem, pra telas de edição/lista/batalha usarem.
class BotDraft {
  BotDraft({
    required this.name,
    this.ramIndex = 0,
    List<DeviceSlot>? devices,
    this.sourceCode = '',
  }) : devices = devices ?? List.generate(32, (_) => const DeviceSlot());

  String name;
  int ramIndex;
  List<DeviceSlot> devices;
  String sourceCode;

  Uint8List? _lastMem;
  AssembleError? lastError;
  List<int> debugMem = const [];
  List<int> debugLines = const [];

  /// Acha a linha (0-based) do código-fonte correspondente ao
  /// endereço de memória `addr`, usando o mapa gerado na última
  /// montagem. Usado pela tela de depuração pra destacar "você está
  /// aqui". Sem equivalente no C++ original (lá o depurador só
  /// mostrava endereços numéricos, não linha de código).
  int? lineForAddress(int addr) {
    final i = debugMem.indexOf(addr);
    return i == -1 ? null : debugLines[i];
  }

  bool get isAssembled => _lastMem != null;

  /// Bytes prontos pra `Robots(..., botFileBytes: ...)`.
  Uint8List? get botFileBytes => _lastMem;

  /// Monta o assembly atual; guarda erro ou resultado. Retorna se deu certo.
  bool assemble() {
    final result = Assembler.assemble(
      source: sourceCode,
      ramSizeIndex: ramIndex,
      devices: devices,
    );
    if (result.success) {
      _lastMem = result.mem;
      lastError = null;
      debugMem = result.debugMem;
      debugLines = result.debugLines;
      return true;
    }
    _lastMem = null;
    lastError = result.error;
    return false;
  }

  /// Quantos slots de device estão preenchidos (tipo != 0).
  int get deviceCount => devices.where((d) => d.type != 0).length;

  /// Custo total contra uma config (mesma conta usada em `Robots`).
  int estimatedCost(ConfStruct config) {
    var cost = config.ramCost[ramIndex.clamp(0, config.ramCost.length - 1)];
    for (final d in devices) {
      if (d.type == 0) continue;
      cost += config.cost[d.level][d.type - 1];
    }
    return cost;
  }

  /// Bytes prontos pra salvar como arquivo `.bot` de verdade (com o
  /// framing do QDataStream) -- so depois de `assemble()` ter sucesso.
  Uint8List? toBotFile() {
    final mem = _lastMem;
    if (mem == null) return null;
    return BotFile.addFraming(mem);
  }
}

/// Fábrica de código-exemplo pra um bot novo -- não existe no
/// original (lá, um bot novo começava com o editor vazio); ajuda
/// quem está testando o app a já ter algo rodando.
String sampleBotSource() => '''
; bot de exemplo -- gira e atira sempre que o canhao estiver pronto
%CPUboot 0
%CPUstack 0

:loop
  out 16,1        ; Plasmagun0_Shoot (porta do device 4 = 16..19)
  mov ax,4
  out 8,ax         ; Engine0_SetThrust
  jmp loop
''';
