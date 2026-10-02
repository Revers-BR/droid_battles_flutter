import 'dart:math';

import '../core/robots.dart';
import '../vm/common_symbols.dart';
import '../weapons/beam.dart';
import '../weapons/chaff.dart';
import '../weapons/mine.dart';
import '../persistence/bot_file_access.dart';
import '../vm/ram.dart';
import '../weapons/missile.dart';
import '../weapons/radar_missile.dart';
import '../weapons/rocket.dart';
import 'conf_struct.dart';
import 'text_mode_battle_area.dart';

/// Liga na arena as factories dos objetos que ja foram portados de
/// verdade: robos (`Robots`), misseis, misseis de radar, minas,
/// feixes, foguetes e chaff -- todos os tipos que a arena cria.
///
/// [fileAccess] liga a instrucao READFILE/WRITEFILE da VM (0x93/0x94)
/// a um acesso de arquivo de verdade -- ver
/// persistence/bot_file_access.dart. Sem ele, essas instrucoes sempre
/// falham (-1), como no original quando o arquivo nao abre.
///
/// [botFiles] mapeia o nome do bot (o mesmo de `BattleConfig.names`)
/// para os bytes do arquivo .bot correspondente; ler o arquivo do
/// disco/assets e responsabilidade de quem chama (a persistencia
/// ainda nao foi portada).
///
/// [ui] = true liga os callbacks de tela (`onArmorChanged`,
/// `onFuelChanged`, `onMessageChanged`, erros de configuracao) nos
/// objetos criados -- use com `BattleArea` (interativa); a arena
/// headless (`TextModeBattleArea`) usa false, como no original.
///
/// Chame logo apos criar a arena, antes do primeiro `execRound()`:
/// ao final ela reinicia a rodada (sorteia novas posicoes iniciais).
void installDefaultFactories(
  TextModeBattleArea area, {
  required Map<String, List<int>> botFiles,
  ConfStruct? config,
  Random? random,
  void Function(String rule, String botName)? onConfigError,
  bool ui = false,
  BotFileAccess? fileAccess,
}) {
  final conf = config ?? ConfStruct();

  // O original mostra cada erro de configuracao do bot uma vez so
  // (o respawn cria o robo com `showerror = false`); deduplicamos aqui.
  final reported = <String>{};
  void reportOnce(String rule, String botName) {
    if (reported.add('$botName|$rule')) {
      onConfigError?.call(rule, botName);
    }
  }

  area.createRobot = (name, slot, team) => Robots(
        name,
        area,
        slot,
        conf,
        team,
        showErrorFlag: ui,
        ui: ui,
        botFileBytes: botFiles[name],
        random: random,
        onConfigError: reportOnce,
        fileAccess: fileAccess,
      );

  area.createMissile = (x, y, dir, arg1, slot, owner) =>
      Missile(x, y, dir, arg1, slot, area, ui: ui);

  area.createMine = (x, y, owner) => Mine(x, y, area, owner, ui: ui);

  area.createBeam = (x, y, dir, arg1, owner) =>
      Beam(x, y, dir, arg1, area, owner, ui: ui);

  area.createRadarMissile = (x, y, dir, arg1, arg2, slot, owner, extra) =>
      RadarMissile(x, y, dir, arg1, arg2, slot, area, extra! as Ram, owner, ui: ui, fileAccess: fileAccess);

  area.createRocket = (x, y, dir, arg1, slot, owner) =>
      Rocket(x, y, dir, arg1, slot, area, owner, ui: ui);

  area.createChaff = (x, y, dir, arg1) => Chaff(x, y, dir, arg1, area, ui: ui);

  // O construtor da arena ja chamou `startOneBattle` ANTES das
  // factories existirem (os slots ficaram com `ScreenObject` vazio);
  // reinicia a rodada agora pra criar os robos de verdade.
  area.startOneBattle(firstRun);
}
