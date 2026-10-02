import 'dart:math';

import '../core/screen_object.dart';
import '../vm/common_symbols.dart';
import 'battle_config.dart';

// Porte de src/textmodebattlearea.h e src/textmodebattlearea.cpp
// (droidbattles original) -- e o "motor" real da arena, sem UI (a
// versao com janela, BattleArea/battlearea.cpp, so adiciona Qt Widgets
// em cima disso). Esta e a classe que de fato importa portar: fisica,
// colisoes, condicoes de fim de partida.
//
// STATUS: `startonebattle`, `execround` (o loop principal, incluindo
// deteccao/resolucao de colisao e as 3 condicoes de fim de jogo:
// normal, survival, deathmatch), `addscrobject`, `devio`,
// `getareainfo` e `explosions` estao portados fielmente a partir do
// C++. O que falta:
// - Criar de fato um `Robots` (robo com CPU) ou um `Missile`/`Mine`/
//   `RadarMissile`/`Beam`/`Rocket`/`Chaff` de verdade -- essas classes
//   ainda sao stubs vazios em lib/core e lib/weapons. Por isso esta
//   classe recebe "factories" (`createRobot`, `createMissile`, etc.)
//   injetadas de fora: por enquanto, se voce nao passar uma factory,
//   ela cai num `ScreenObject()` vazio (equivalente ao "slot livre" do
//   original), e a arena roda sem travar, so sem bots/projeteis de
//   verdade. Troque as factories assim que Robots/Missile/etc
//   estiverem portados.
// - `config.load(...)` (ConfStruct, o arquivo de configuracao global)
//   nao e usado aqui ainda -- ver lib/battle/conf_struct.dart.
class TextModeBattleArea {
  TextModeBattleArea(
    this.battleConfig, {
    Random? random,
    this.createRobot,
    this.createMissile,
    this.createMine,
    this.createRadarMissile,
    this.createBeam,
    this.createRocket,
    this.createChaff,
  }) : random = random ?? (battleConfig.randomSeed != null ? Random(battleConfig.randomSeed) : Random()) {
    battleMode = battleConfig.mode;
    maxPoints = battleConfig.numFights;
    isTeams = battleConfig.isTeams;
    xSize = battleConfig.xSize;
    ySize = battleConfig.ySize;
    ifDelete = false;
    maxRounds = battleConfig.maxRounds;

    for (var i = 0; i < maxBots; i++) {
      botTeams[i] = battleConfig.teams[i];
    }

    numFights = battleConfig.numFights;
    fightsFought = 0;
    names = List<String>.from(battleConfig.names);

    startOneBattle(firstRun);
  }

  final BattleConfig battleConfig;
  final Random random;

  // ---- factories (substituem `new Robots(...)`, `new Missile(...)` etc.) ----
  ScreenObject Function(String name, int slot, int team)? createRobot;
  ScreenObject Function(int x, int y, int dir, int arg1, int slot, int owner)? createMissile;
  ScreenObject Function(int x, int y, int owner)? createMine;
  ScreenObject Function(int x, int y, int dir, int arg1, int arg2, int slot, int owner, Object? extra)? createRadarMissile;
  ScreenObject Function(int x, int y, int dir, int arg1, int owner)? createBeam;
  ScreenObject Function(int x, int y, int dir, int arg1, int slot, int owner)? createRocket;
  ScreenObject Function(int x, int y, int dir, int arg1)? createChaff;

  /// Sorteia uma coordenada X/Y inicial. No original headless e
  /// `qrand() % m_xSize` (0..xSize-1); a BattleArea interativa
  /// sobrescreve pra `uniform_int_distribution(0, xSize)` (inclusivo).
  int nextRandomX() => random.nextInt(xSize);
  int nextRandomY() => random.nextInt(ySize);

  /// Nome mostrado nas mensagens de resultado. Headless usa o nome
  /// cru; a BattleArea interativa usa `QFileInfo(name).baseName()`.
  String displayName(String name) => name;

  /// Chamado quando a partida INTEIRA terminou, com o texto do
  /// resultado. [nonTeamBrief] e true so no ramo normal/survival sem
  /// times (o unico onde o UI original emite `battledone` em vez do
  /// dialogo quando roda como torneio). Headless: so guarda a mensagem.
  void battleFinished(String message, {bool nonTeamBrief = false}) {
    lastResultMessage = message;
  }

  ScreenObject newRobot(String name, int slot, int team) =>
      createRobot?.call(name, slot, team) ?? ScreenObject();

  // ---- estado (era `protected:` no C++) ----
  final List<ScreenObject> objects = List<ScreenObject>.generate(maxObjects, (_) => ScreenObject());
  List<String> names = List.filled(8, '');
  int numFights = 1;
  final List<int> fightsWon = List.filled(8, 0);
  final List<int> scorePoints = List.filled(8, 0);
  int fightsFought = 0;
  int roundsRun = 0;
  int maxRounds = 6000;
  int xSize = 32768;
  int ySize = 32768;
  bool isTeams = false;
  bool checkWin = false;
  final List<int> botTeams = List.filled(8, 0);
  final List<int> alive = List.filled(4, 0);
  bool ifDelete = false;
  int maxPoints = 10;
  int battleMode = FightMode.normal;
  final List<int> xStarts = List.filled(8, 0);
  final List<int> yStarts = List.filled(8, 0);

  /// Resultado textual da ultima partida encerrada (era o `qDebug()`
  /// com a mensagem de resultado no original, que so ia pro console).
  String? lastResultMessage;

  /// Era `TextmodeBattleArea::startonebattle` -- (re)inicia uma
  /// rodada: sorteia posicoes iniciais (garantindo distancia minima
  /// entre bots) e recria os robos.
  void startOneBattle(int firstOrNot) {
    if (firstOrNot == notFirstRound) {
      for (var x = 0; x < maxObjects; x++) {
        objects[x] = ScreenObject();
      }
    }

    xStarts[0] = nextRandomX();
    yStarts[0] = nextRandomY();
    for (var x = 1; x < maxBots; x++) {
      var dst = minStartDistance - 1;
      var tries = 0;
      while (dst < minStartDistance && tries < 128) {
        dst = minStartDistance;
        xStarts[x] = nextRandomX();
        yStarts[x] = nextRandomY();
        for (var y = 0; y < x; y++) {
          final xdiff = (xStarts[y] - xStarts[x]).abs();
          final ydiff = (yStarts[y] - yStarts[x]).abs();
          final tdist = sqrt((xdiff * xdiff + ydiff * ydiff).toDouble()).toInt();
          if (tdist < dst) dst = tdist;
        }
        tries++;
      }
    }

    for (var x = 0; x < maxBots; x++) {
      final name = names[x];
      objects[x] = name.isNotEmpty ? newRobot(name, x, botTeams[x]) : ScreenObject();
    }
    for (var x = maxBots; x < maxObjects; x++) {
      objects[x] = ScreenObject();
    }

    roundsRun = 0;
  }

  /// Era `TextmodeBattleArea::execround` -- executado ~50x por
  /// segundo; um "tick" da simulacao inteira. Retorna 3 quando a
  /// partida/torneio termina (mesmo codigo do original), 0 caso
  /// contrario.
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

      if (objects[x].type() > 0) {
        for (var x2 = x + 1; x2 < maxObjects; x2++) {
          final a = objects[x];
          final b = objects[x2];
          if (b.type() > 0 &&
              ((a.collisionId() == collEnabled || b.collisionId() == collEnabled) ||
                  (a.collisionId() != b.collisionId()))) {
            var xx1 = a.xPos(), xx2 = b.xPos();
            var dx = (xx1 - xx2) / 2;
            var yy1 = a.yPos(), yy2 = b.yPos();
            var dy = (yy1 - yy2) / 2;
            var dist = sqrt(dx * dx + dy * dy).toInt();
            dist *= 2;

            if (dist < ((a.size() << 6) + (b.size() << 6))) {
              final type1 = a.collisionType();
              final type2 = b.collisionType();
              final str1 = a.collisionStrength();
              final str2 = b.collisionStrength();

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

              xx1 = a.xPos();
              xx2 = b.xPos();
              dx = (xx1 - xx2).toDouble();
              yy1 = a.yPos();
              yy2 = b.yPos();
              dy = (yy1 - yy2).toDouble();
              dist = sqrt(dx * dx + dy * dy).toInt();

              if (dist < ((a.size() << 6) + (b.size() << 6)) &&
                  a.type() == ScreenObject.botObject &&
                  b.type() == ScreenObject.botObject) {
                final angl = atan2(dy, dx);
                final dst = (a.size() << 6) + (b.size() << 6) - dist;
                a.setPosition(cos(angl) * ((dst + 16) / 2), sin(angl) * ((dst + 16) / 2));
                b.setPosition(cos(angl + pi) * ((dst + 16) / 2), sin(angl + pi) * ((dst + 16) / 2));
              }

              final x2owner = b.owner();
              if (b.objectHit(9, str1) == objHitDestroyed) {
                // O "guard" do survival no original e o indice do laco
                // externo (`x < 8`), nao o do objeto que morreu; e o
                // credito do frag vai pro DONO do atacante.
                resolveDeath(x2, guardSlot: x, killerOwner: a.owner());
              }
              if (a.objectHit(9, str2) == objHitDestroyed) {
                resolveDeath(x, guardSlot: x, killerOwner: x2owner);
                break; // era "x2 = maxobjects; continue" -- sai do loop interno
              }
            }
          }
        }
      }

      if (ifDel == destroySelf) {
        objects[x] = ScreenObject();
      }
    }

    final endResult = checkEndConditions();
    if (endResult != 0) return endResult;

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

  /// Era o bloco repetido (duas vezes na colisao + uma em
  /// `explosions`) que decide o que acontece quando um objeto morre,
  /// de acordo com `battleMode`.
  ///
  /// - [slot]: indice do objeto que morreu.
  /// - [guardSlot]: no survival, o original testa `x < 8` onde `x` e o
  ///   indice do laco EXTERNO da colisao (nao necessariamente o
  ///   morto) -- ex.: um bot morto por um missil (slot >= 8) so some,
  ///   sem gastar vida nem renascer. Em `explosions` e o proprio `z`.
  /// - [killerOwner]: dono do objeto que causou o dano (recebe o frag
  ///   no deathmatch).
  /// - [reHit]: se true, chama `objectHit(0, 0)` no robo que renasce
  ///   (o original faz isso nas colisoes, mas NAO em `explosions`).
  void resolveDeath(
    int slot, {
    required int guardSlot,
    required int killerOwner,
    bool reHit = true,
  }) {
    switch (battleMode) {
      case FightMode.normal:
        objects[slot] = ScreenObject();
        break;
      case FightMode.survival:
        if (guardSlot < 8 && objects[slot].type() == ScreenObject.botObject) {
          fightsWon[slot]++;
          if (fightsWon[slot] < maxPoints) {
            xStarts[slot] = nextRandomX();
            yStarts[slot] = nextRandomY();
            objects[slot] = newRobot(names[slot], slot, botTeams[slot]);
            if (reHit) objects[slot].objectHit(0, 0);
          } else {
            objects[slot] = ScreenObject();
            fightsWon[slot] = roundsRun;
          }
        } else {
          objects[slot] = ScreenObject();
        }
        break;
      case FightMode.deathmatch:
        if (objects[slot].type() == ScreenObject.botObject) {
          if (killerOwner < 8 && slot != killerOwner) {
            fightsWon[killerOwner]++;
          }
          checkWin = true;
          xStarts[slot] = nextRandomX();
          yStarts[slot] = nextRandomY();
          objects[slot] = newRobot(names[slot], slot, botTeams[slot]);
          if (reHit) objects[slot].objectHit(0, 0);
        } else {
          objects[slot] = ScreenObject();
        }
        break;
    }
  }

  /// Era o trecho final de `execround` que checa se a partida acabou
  /// (por times ou por bots individuais) e, se acabou de vez (todas
  /// as rodadas do combate), monta a mensagem final. Retorna 3 se
  /// terminou tudo, 0 caso contrario (e reinicia a rodada via
  /// `startOneBattle` quando ha rodadas restantes).
  int checkEndConditions() {
    var numOfBots = 0;
    var botNum = 0;

    if (isTeams) {
      for (var i = 0; i < 4; i++) {
        alive[i] = 0;
      }
      for (var x = 0; x < maxBots; x++) {
        if (objects[x].type() == ScreenObject.botObject) {
          var yy = objects[x].team();
          if (yy > 3 || yy < 0) yy = 0;
          alive[yy] = 1;
        }
      }
      for (var x = 0; x < 4; x++) {
        if (alive[x] == 1) {
          numOfBots++;
          botNum = x;
        }
      }
      if (numOfBots <= 1) {
        if (numOfBots == 1) fightsWon[botNum]++;
        fightsFought++;
        if (fightsFought >= numFights) {
          var winBot = 0;
          var curVal = 0;
          var draw = false;
          for (var x = 0; x < maxTeams; x++) {
            if (fightsWon[x] == curVal) draw = true;
            if (fightsWon[x] > curVal) {
              curVal = fightsWon[x];
              winBot = x;
              draw = false;
            }
          }
          battleFinished(draw ? 'Fight was a draw' : ' Team ${winBot + 1} won!');
          return 3;
        }
        startOneBattle(notFirstRound);
      }
    }

    if (!isTeams && (battleMode == FightMode.normal || battleMode == FightMode.survival)) {
      for (var x = 0; x < maxBots; x++) {
        if (objects[x].type() == ScreenObject.botObject) {
          numOfBots++;
          botNum = x;
        }
      }
      if (numOfBots <= 1) {
        if (numOfBots == 1) fightsWon[botNum]++;
        fightsFought++;
        if (fightsFought >= numFights) {
          // O original RECALCULA botnum aqui: passa a ser o bot nomeado
          // com MENOS fightswon (no survival, e quem gastou menos vidas
          // = o vencedor), sobrescrevendo o botnum do bot vivo.
          var curVal2 = 1000;
          for (var x = 0; x < maxBots; x++) {
            if (fightsWon[x] < curVal2 && names[x].isNotEmpty) {
              curVal2 = fightsWon[x];
              botNum = x;
            }
          }
          final buf = StringBuffer();
          switch (battleMode) {
            case FightMode.normal:
              for (var xx = 0; xx < 8; xx++) {
                if (names[xx].isNotEmpty) {
                  buf.write(' Bot ${displayName(names[xx])} won ${fightsWon[xx]} fights.\n');
                }
              }
              break;
            case FightMode.survival:
              buf.write(' Bot ${displayName(names[botNum])} won with ${maxPoints - fightsWon[botNum]} lives left!\n');
              for (var xx = 0; xx < 8; xx++) {
                if (names[xx].isNotEmpty && xx != botNum) {
                  buf.write(' Bot ${displayName(names[xx])} survived ${fightsWon[xx]} cycles.\n');
                }
              }
              break;
          }
          battleFinished(buf.toString(), nonTeamBrief: true);
          return 3;
        } else {
          startOneBattle(notFirstRound);
        }
      }
    }

    return 0;
  }

  /// Era `TextmodeBattleArea::addscrobject` -- um device pede pra
  /// arena criar um novo objeto (tiro, mina, etc.) no primeiro slot
  /// livre (`type() == destroyed`).
  void addScreenObject(int owner, int x, int y, int dir, int type, [int arg1 = 0, int arg2 = 0, Object? arg3]) {
    for (var i = 0; i < maxObjects; i++) {
      if (objects[i].type() == ScreenObject.destroyed) {
        switch (type) {
          case 0:
            objects[i] = ScreenObject();
            break;
          case 1:
            // era "robots" -- o original deixa esse caso vazio tambem
            // (comentado), robos nao sao criados por addscrobject.
            break;
          case 2:
            objects[i] = createMissile?.call(x, y, dir, arg1, i, owner) ?? ScreenObject();
            break;
          case 3:
            objects[i] = createMine?.call(x, y, owner) ?? ScreenObject();
            break;
          case 4:
            objects[i] = createRadarMissile?.call(x, y, dir, arg1, arg2, i, owner, arg3) ?? ScreenObject();
            break;
          case 5:
            objects[i] = createBeam?.call(x, y, dir, arg1, owner) ?? ScreenObject();
            break;
          case 6:
            objects[i] = createRocket?.call(x, y, dir, arg1, i, owner) ?? ScreenObject();
            break;
          case 7:
            objects[i] = createChaff?.call(x, y, dir, arg1) ?? ScreenObject();
            break;
          default:
            objects[i] = ScreenObject();
        }
        break;
      }
    }
  }

  /// Era `TextmodeBattleArea::devio` -- um device (ex: scanner) pede
  /// info sobre outro objeto da arena.
  int devIo(int bot, int dev, int choice, int arg1, int arg2) {
    switch (choice) {
      case 1:
        return objects[arg1].xPos();
      case 2:
        return objects[arg1].yPos();
      case 3:
        return objects[arg1].direction();
      case 4:
        return objects[arg1].speed();
      case 5:
        objects[bot] = ScreenObject();
        break;
      case 6:
        return objects[arg1].returnRadar();
      case 7:
        for (var x = 0; x < maxBots; x++) {
          if (objects[x].type() == ScreenObject.botObject &&
              objects[x].team() == bot &&
              (arg2 == 255 || objects[x].number() == arg2)) {
            objects[x].writeRadio(arg1);
          }
        }
        break;
      case 8:
        return objects[arg1].team();
      case 9:
        objects[bot].objectScanned(arg1, arg2);
        break;
      case 10:
        return getAreaInfo(0);
      case 11:
        return getAreaInfo(1);
      case 12:
        return getAreaInfo(2);
    }
    return 0;
  }

  /// Era `TextmodeBattleArea::getareainfo`.
  int getAreaInfo(int choice) {
    switch (choice) {
      case 0:
        return xSize;
      case 1:
        return ySize;
      case 2:
        return battleMode;
    }
    return 0;
  }

  /// Era `TextmodeBattleArea::explosions` -- dano em area (usado pelo
  /// foguete AS). `whichObject` e o slot que causou a explosao (fica
  /// imune a ela).
  void explosions(int x, int y, int rad, int strength, int whichObject) {
    for (var z = 0; z < maxBots; z++) {
      if (z == whichObject) continue;
      if (!objects[z].areaExplosionAffects()) continue;

      final x1 = objects[z].xPos();
      final y1 = objects[z].yPos();
      final d1 = sqrt(((x1 - x) * (x1 - x) + (y1 - y) * (y1 - y)).toDouble()).toInt();
      if (d1 >= rad) continue;

      final s1 = strength - (d1 * strength ~/ rad);
      if (objects[z].objectHit(9, s1) == objHitDestroyed) {
        resolveDeath(
          z,
          guardSlot: z,
          killerOwner: objects[whichObject].owner(),
          reHit: false,
        );
      }
    }
  }

  int getStartX(int bot) => xStarts[bot];
  int getStartY(int bot) => yStarts[bot];
}
