import 'dart:math' as math;

import '../battle/text_mode_battle_area.dart';
import '../core/screen_object.dart';
import '../vm/common_symbols.dart';

// Porte de src/rocket.h e src/rocket.cpp (droidbattles original) -- o
// foguete AS: voa em linha reta ate a distancia pedida e entao
// explode causando dano em area (`TextModeBattleArea.explosions`).
//
// Fica de fora (so UI, Qt): eraseObject/drawObject, a chama de
// pontos aleatorios (pointX/pointY/pointD) e os pixmaps.
class Rocket extends ScreenObject {
  Rocket(
    int x,
    int y,
    int dir,
    int leng,
    int mnum,
    this.ourArea,
    int owner, {
    bool ui = true,
  }) {
    useUI = ui;
    myowner = owner;
    mynum = mnum;
    mDirection = dir;
    mSpeed = 220;
    noncollid = 256;

    uX = x;
    uY = y;

    oldX = x;
    oldY = y;
    final dira = direction() * math.pi / 512;
    xPosRaw = x + math.cos(dira) * 1500;
    yPosRaw = y + math.sin(dira) * 1500;

    mSize = 16;
    length = leng;
  }

  final TextModeBattleArea ourArea;
  int length = 0;
  int uX = 0;
  int uY = 0;

  @override
  int objectHit(int type, int strength) => 1;

  @override
  int type() => ScreenObject.collidable;

  /// Move o foguete e, se chegou na distancia pedida, explode.
  @override
  int execute() {
    final dir = direction() * math.pi / 512;
    final ret = setPosition(math.cos(dir) * mSpeed, math.sin(dir) * mSpeed);
    final dx = xPosRaw - uX;
    final dy = yPosRaw - uY;
    final dist = math.sqrt(dx * dx + dy * dy).toInt();
    if (dist > length) {
      ourArea.explosions(xPosRaw.toInt(), yPosRaw.toInt(), 3500, 120, mynum);
      return destroySelf;
    }
    return ret;
  }

  /// Move; se sair do campo de batalha, se destroi.
  @override
  int setPosition(double dx, double dy) {
    oldX = xPosRaw.toInt();
    oldY = yPosRaw.toInt();
    xPosRaw += dx;
    yPosRaw += dy;
    if (xPosRaw < 0) return destroySelf;
    if (xPosRaw > ourArea.getAreaInfo(0)) return destroySelf;
    if (yPosRaw < 0) return destroySelf;
    if (yPosRaw > ourArea.getAreaInfo(1)) return destroySelf;
    return 0;
  }

  @override
  int collisionType() => 2;

  @override
  int collisionStrength() => 0;

  /// Nao e afetado pelas explosoes de outros foguetes.
  @override
  bool areaExplosionAffects() => false;

  @override
  int returnRadar() => 2;
}
