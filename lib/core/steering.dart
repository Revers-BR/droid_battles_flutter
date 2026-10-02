import 'device.dart';
import 'screen_object.dart';

// Porte de src/steering.h e src/steering.cpp (droidbattles original)
// -- direcao: gira o bot suavemente ate a direcao alvo, pelo caminho
// mais curto (direita ou esquerda).
class Steering extends Device {
  Steering(ScreenObject object, int arg1) : super(object) {
    ourlevel = arg1;
    aimAtDir = ourbot!.direction();
  }

  int aimAtDir = 0;

  @override
  void execute() {
    if (stackTaken[0][0]) {
      aimAtDir += portStack[0][0];
      if (aimAtDir > 1024) aimAtDir %= 1024;
      if (aimAtDir < 0) aimAtDir += 1024;
      movePortStack(0);
    }
    if (stackTaken[1][0]) {
      aimAtDir = portStack[1][0];
      if (aimAtDir > 1024) aimAtDir %= 1024;
      if (aimAtDir < 0) aimAtDir += 1024;
      movePortStack(1);
    }
    if (stackTaken[2][0]) {
      aimAtDir = ourbot!.direction() + portStack[2][0];
      if (aimAtDir > 1024) aimAtDir %= 1024;
      if (aimAtDir < 0) aimAtDir += 1024;
      movePortStack(2);
    }

    final dir = ourbot!.direction();
    if (aimAtDir != dir) {
      int diff1, diff2;
      if (aimAtDir < dir) {
        diff1 = dir - aimAtDir;
        diff2 = 1024 - dir + aimAtDir;
      } else {
        diff1 = dir + 1024 - aimAtDir;
        diff2 = aimAtDir - dir;
      }

      if (diff1 < diff2) {
        ourbot!.changeDirection(diff1 < ourlevel ? -diff1 : -ourlevel);
      } else {
        ourbot!.changeDirection(diff2 < ourlevel ? diff2 : ourlevel);
      }
    }
  }

  @override
  int readPort(int port) {
    switch (port) {
      case 0:
        return ourbot!.direction();
      case 1:
        return aimAtDir;
      case 2:
        return ourbot!.xPos();
      case 3:
        return ourbot!.yPos();
    }
    return 0;
  }
}
