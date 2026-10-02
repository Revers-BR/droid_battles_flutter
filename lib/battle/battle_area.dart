import 'dart:math';

import '../core/explosion.dart';
import '../core/screen_object.dart';
import '../vm/common_symbols.dart';
import 'battle_config.dart';
import 'text_mode_battle_area.dart';

// Porte da LOGICA de src/battlearea.h e src/battlearea.cpp
// (droidbattles original) -- a arena INTERATIVA. No C++ ela nao herda
// de TextmodeBattleArea: reimplementa `execute`/`explosions` com
// regras de colisao e pontuacao ligeiramente diferentes das da versao
// headless (torneios/modo rapido). Como o jogo que o usuario ve e
// esta versao, a logica dela foi mantida fiel aqui, como uma
// subclasse que sobrescreve so o que muda:
//
// - Colisao: objetos com o MESMO dono nunca colidem, e so colide se
//   ao menos um dos dois tem `collisionId() == collEnabled` (a versao
//   headless usa uma regra diferente). Distancia em float e teste
//   `dist > soma -> nao colidiu` (headless: `dist < soma`).
// - Cada colisao cria um `Explosion` (slots 254..129) e soma
//   `collisionStrength` em `scorePoints[dono]`.
// - `explosions()` usa aritmetica em double (o dano cai um pouco
//   diferente do headless) e cria um `Explosion` no fim.
// - Sorteio de posicao inicial e inclusivo (0..xSize), como
//   `uniform_int_distribution`.
// - `maxPoints` vem de `battleConfig.maxPoints` (o headless usa
//   `numFights`, quirk do original).
// - Fim de partida: mensagens usam o "baseName" do arquivo do bot;
//   em torneio (`isTournament`) o ramo normal/survival emite
//   `onBattleDone` em vez do dialogo.
//
// Fica de fora (so UI, Qt): timer/botoes Play-Pause-Singlestep/slider,
// janelas de info e debug, desenho (`Drawable`), geometria salva, e
// `storeScores()` (grava scores.txt e depende de `BotInfo.score()`;
// entra junto com a persistencia e o BotInfo).
//
// O "clock" da simulacao agora e de quem usar a classe: chame
// `execRound()` a cada tick (o original: ~50/s, 20 ms; modo rapido:
// o mais rapido possivel). Retorna 3 quando a partida inteira acabou.
class BattleArea extends TextModeBattleArea {
  BattleArea(
    super.battleConfig, {
    super.random,
    super.createRobot,
    super.createMissile,
    super.createMine,
    super.createRadarMissile,
    super.createBeam,
    super.createRocket,
    super.createChaff,
    this.onFightEnded,
    this.onBattleDone,
  }) {
    // O UI usa maxPoints da config (o headless usa numFights).
    maxPoints = battleConfig.maxPoints;
  }

  /// Era `m_showResults = !battleConfig.isTournament`.
  bool get showResults => !battleConfig.isTournament;

  /// Substitui o `QMessageBox::information(...)` de fim de luta.
  final void Function(String message)? onFightEnded;

  /// Era o signal `battledone(fightswon[0], fightswon[1])`, emitido
  /// em torneio no fim de uma luta normal/survival sem times.
  final void Function(int won0, int won1)? onBattleDone;

  /// True depois que a partida terminou de vez (era `ifdelete`, que
  /// dispara `storeScores()` + `deleteLater()`).
  // (o campo `ifDelete` ja existe na base)

  @override
  int nextRandomX() => random.nextInt(xSize + 1);

  @override
  int nextRandomY() => random.nextInt(ySize + 1);

  /// `QFileInfo(name).baseName()`: sem diretorio e sem nada a partir
  /// do primeiro ponto.
  @override
  String displayName(String name) {
    var n = name;
    final slash = max(n.lastIndexOf('/'), n.lastIndexOf('\\'));
    if (slash >= 0) n = n.substring(slash + 1);
    final dot = n.indexOf('.');
    if (dot >= 0) n = n.substring(0, dot);
    return n;
  }

  @override
  void battleFinished(String message, {bool nonTeamBrief = false}) {
    lastResultMessage = message;
    if (nonTeamBrief && !showResults) {
      onBattleDone?.call(fightsWon[0], fightsWon[1]);
    } else {
      onFightEnded?.call(message);
    }
    ifDelete = true;
  }

  /// Cria uma explosao visual no primeiro slot livre de 254 ate 129.
  void _spawnExplosion(int x, int y) {
    for (var xxx = 254; xxx > 128; xxx--) {
      if (objects[xxx].type() == ScreenObject.destroyed) {
        objects[xxx] = Explosion(x, y, this);
        break;
      }
    }
  }

  /// Era `BattleArea::execute()` (o "tick" da arena interativa).
  @override
  int execRound() {
    roundsRun++;
    if (roundsRun > maxRounds) {
      if (battleMode == FightMode.normal || battleMode == FightMode.survival) {
        for (var x = 0; x < maxBots; x++) {
          objects[x] = ScreenObject();
        }
      }
      if (battleMode == FightMode.deathmatch) {
        checkWin = true;
        maxPoints = 0;
      }
    }

    for (var x = 0; x < maxObjects; x++) {
      final ifDel = objects[x].execute();
      if (ifDel == destroySelf) {
        // Diferente do headless: some ANTES de checar colisoes.
        objects[x] = ScreenObject();
        continue;
      }

      if (objects[x].type() <= 0) continue;

      for (var x2 = x + 1; x2 < maxObjects; x2++) {
        var a = objects[x];
        var b = objects[x2];
        if (b.type() <= 0) continue;
        if (a.owner() == b.owner()) continue;
        if (a.collisionId() != collEnabled && b.collisionId() != collEnabled) {
          continue;
        }

        // Em C++ sao `float`; Dart usa double (diferenca so nas casas
        // extremas do arredondamento).
        var xx1 = a.xPos().toDouble(), xx2 = b.xPos().toDouble();
        var dx = (xx1 - xx2) / 2;
        var yy1 = a.yPos().toDouble(), yy2 = b.yPos().toDouble();
        var dy = (yy1 - yy2) / 2;
        var dist = sqrt(dx * dx + dy * dy).truncateToDouble();
        dist *= 2;

        if (dist > ((a.size() << 6) + (b.size() << 6))) {
          continue; // nao colidiu
        }

        _spawnExplosion(((xx1 + xx2) / 2).toInt(), ((yy1 + yy2) / 2).toInt());

        final type1 = a.collisionType();
        final type2 = b.collisionType();
        final str1 = a.collisionStrength();
        final str2 = b.collisionStrength();

        scorePoints[a.owner()] += str1;
        scorePoints[b.owner()] += str2;

        if (type1 == 1) {
          b.setSpeed(-(b.speed() ~/ 2));
          final dir = b.direction() * toRadians;
          b.setPosition(cos(dir) * b.speed(), sin(dir) * b.speed());
        }
        if (type2 == 1) {
          a.setSpeed(-(a.speed() ~/ 2));
          final dir = a.direction() * toRadians;
          a.setPosition(cos(dir) * a.speed(), sin(dir) * a.speed());
        }

        xx1 = a.xPos().toDouble();
        xx2 = b.xPos().toDouble();
        dx = xx1 - xx2;
        yy1 = a.yPos().toDouble();
        yy2 = b.yPos().toDouble();
        dy = yy1 - yy2;
        dist = sqrt(dx * dx + dy * dy).truncateToDouble();

        if (dist < ((a.size() << 6) + (b.size() << 6)) &&
            a.type() == ScreenObject.botObject &&
            b.type() == ScreenObject.botObject) {
          final angl = atan2(dy, dx);
          final dst = ((a.size() << 6) + (b.size() << 6) - dist).toInt();
          a.setPosition(cos(angl) * ((dst + 16) ~/ 2), sin(angl) * ((dst + 16) ~/ 2));
          b.setPosition(cos(angl + pi) * ((dst + 16) ~/ 2), sin(angl + pi) * ((dst + 16) ~/ 2));
        }

        final x2owner = b.owner();

        if (b.objectHit(9, str1) == objHitDestroyed) {
          resolveDeath(x2, guardSlot: x, killerOwner: a.owner());
        }
        if (a.objectHit(9, str2) == objHitDestroyed) {
          resolveDeath(x, guardSlot: x, killerOwner: x2owner);
          break; // era `x2 = maxobjects`
        }
      }
    }

    // Fim de luta/partida (mesma logica da base; as diferencas de
    // mensagem/sinal estao em `battleFinished`/`displayName`).
    final ended = checkEndConditions();
    if (ended != 0) return ended;

    if (battleMode == FightMode.deathmatch && checkWin) {
      checkWin = false;
      for (var x = 0; x < 8; x++) {
        if (fightsWon[x] >= maxPoints) {
          final buf = StringBuffer();
          for (var xx = 0; xx < 8; xx++) {
            if (names[xx].isNotEmpty) {
              buf.write(' Bot ${displayName(names[xx])} got ${fightsWon[xx]} frags.\n');
            }
          }
          battleFinished(buf.toString());
          return 3;
        }
      }
    }
    return 0;
  }

  /// Era `BattleArea::explosions` -- igual a versao headless, mas com
  /// o dano calculado em double e um `Explosion` criado no fim.
  @override
  void explosions(int x, int y, int rad, int strength, int whichObject) {
    for (var z = 0; z < maxBots; z++) {
      if (z == whichObject) continue;
      if (!objects[z].areaExplosionAffects()) continue;

      final x1 = objects[z].xPos().toDouble();
      final y1 = objects[z].yPos().toDouble();
      final d1 = sqrt((x1 - x) * (x1 - x) + (y1 - y) * (y1 - y)).truncateToDouble();
      if (d1 >= rad) continue;

      final s1 = strength - (d1 * strength / rad);
      if (objects[z].objectHit(9, s1.toInt()) == objHitDestroyed) {
        resolveDeath(
          z,
          guardSlot: z,
          killerOwner: objects[whichObject].owner(),
          reHit: false,
        );
      }
    }
    _spawnExplosion(x, y);
  }
}
