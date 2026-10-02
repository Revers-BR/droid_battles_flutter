import 'dart:math' as math;

import '../battle/text_mode_battle_area.dart';
import '../core/screen_object.dart';
import '../vm/common_symbols.dart';

// Porte de src/chaff.h e src/chaff.cpp (droidbattles original) --
// nuvem de chaff: objeto nao colidivel, aparece no radar como alvo
// falso (returnRadar = 5) e some depois de 159 ciclos.
//
// Fica de fora (so UI, Qt): eraseObject/drawObject.
class Chaff extends ScreenObject {
  Chaff(int x, int y, int d, int spd, this.ourArea, {bool ui = true}) {
    mDirection = d;
    xPosRaw = x.toDouble();
    yPosRaw = y.toDouble();
    mSpeed = spd;
    useUI = ui;
    timeLeft = 159;
    maxx = ourArea.getAreaInfo(0);
    maxy = ourArea.getAreaInfo(1);
  }

  final TextModeBattleArea ourArea;
  int timeLeft = 159;

  /// Anda um passo e se destroi quando o tempo acaba.
  @override
  int execute() {
    final dira = direction() * math.pi / 512;
    final tempX = math.cos(dira) * speed();
    final tempY = math.sin(dira) * speed();
    setPosition(tempX, tempY);
    timeLeft--;
    if (timeLeft == 0) return destroySelf;
    return 0;
  }

  @override
  int type() => ScreenObject.nonCollidable;

  @override
  int returnRadar() => 5;
}
