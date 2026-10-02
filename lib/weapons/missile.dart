import 'dart:math' as math;

import '../battle/text_mode_battle_area.dart';
import '../core/screen_object.dart';
import '../vm/common_symbols.dart';

// Porte de src/missile.h e src/missile.cpp (droidbattles original) --
// o tiro disparado pelo canhao de plasma. Anda em linha reta, causa
// dano ao colidir e some ao sair da arena.
//
// Fica de fora (so UI, Qt): eraseObject/drawObject e os pixmaps.
class Missile extends ScreenObject {
  Missile(
    int x,
    int y,
    int dir,
    int owner,
    int mnum,
    this.ourArea, {
    bool ui = true,
  }) {
    useUI = ui;
    myowner = owner;
    mynum = mnum;
    strength = 20;
    mDirection = dir;
    mSpeed = 256;
    // Nao colide com o proprio dono (ver o teste de collisionId na arena).
    noncollid = owner;

    oldX = x;
    oldY = y;
    final dira = direction() * math.pi / 512;
    xPosRaw = x + math.cos(dira) * 1500;
    yPosRaw = y + math.sin(dira) * 1500;
  }

  final TextModeBattleArea ourArea;
  int strength = 20;

  /// Anda um passo na direcao atual.
  @override
  int execute() {
    final dir = direction() * math.pi / 512;
    return setPosition(math.cos(dir) * speed(), math.sin(dir) * speed());
  }

  @override
  int type() => ScreenObject.collidable;

  @override
  int collisionType() => 2;

  @override
  int collisionStrength() => 15;

  @override
  int objectHit(int type, int strength) => objHitDestroyed;

  /// Se o tiro sai do campo de batalha, ele se destroi (retorna
  /// `destroySelf`, que a arena usa pra liberar o slot).
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
  int returnRadar() => 1;
}
