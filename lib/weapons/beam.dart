import 'dart:math' as math;

import '../battle/text_mode_battle_area.dart';
import '../core/screen_object.dart';
import '../vm/common_symbols.dart';

// Porte de src/beam.h e src/beam.cpp (droidbattles original) -- o
// "laser": um segmento instantaneo que fica visivel por 5 ciclos e so
// causa dano no ultimo (quando `type()` vira Collidable).
//
// Fica de fora (so UI, Qt): eraseObject/drawObject.
class Beam extends ScreenObject {
  Beam(int x, int y, int dir, int l, this.ourArea, int owner, {bool ui = true}) {
    useUI = ui;
    myowner = owner;
    noncollid = collEnabled;
    length = l;
    if (length > maxBeamLength) length = maxBeamLength;
    if (length < minBeamLength) length = minBeamLength;
    mDirection = dir;
    xPosRaw = x.toDouble();
    yPosRaw = y.toDouble();
    uX = x;
    uY = y;
    final dira = direction() * toRadians;
    final tempX = math.cos(dira) * length;
    final tempY = math.sin(dira) * length;
    maxx = ourArea.getAreaInfo(0);
    maxy = ourArea.getAreaInfo(1);
    setPosition(tempX, tempY);
    effect = 5;
  }

  final TextModeBattleArea ourArea;
  int length = 0;
  int effect = 5;

  /// Ponto de origem do feixe (era `uX`/`uY`, usado so pra desenhar).
  int uX = 0;
  int uY = 0;

  /// Conta o tempo ate o efeito; se ninguem colidiu, se destroi.
  @override
  int execute() {
    if (effect == 0) return destroySelf;
    if (effect > 0) effect--;
    return 0;
  }

  @override
  int objectHit(int type, int strength) => objHitDestroyed;

  /// Collidable so nos 2 ultimos ciclos de vida; antes disso e
  /// apenas visual.
  @override
  int type() => effect <= 1 ? ScreenObject.collidable : ScreenObject.nonCollidable;

  @override
  int collisionStrength() => beamDamage;

  @override
  int collisionType() => 2;
}
