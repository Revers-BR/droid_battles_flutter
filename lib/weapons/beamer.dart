import '../core/device.dart';
import '../core/screen_object.dart';

// Porte de src/beamer.h e src/beamer.cpp (droidbattles original) --
// device que dispara feixes (Beam). Custa 20 de combustivel por tiro.
class Beamer extends Device {
  Beamer(ScreenObject object, int arg1) : super(object) {
    ourlevel = arg1;
    relang = 0;
  }

  /// Comprimento do feixe (nao inicializado no C++; comeca em 0 e a
  /// Beam o ajusta ao minimo permitido).
  int length = 0;

  @override
  void execute() {
    if (stackTaken[0][0]) {
      movePortStack(0);
      // Sem combustivel suficiente nao dispara.
      if (ourbot!.fuel() <= 20) {
        return;
      }
      ourbot!.setFuel(-20);
      ourbot!.changeHeat(ourlevel);
      ourbot!.addScreenObject(
        ourbot!.xPos(),
        ourbot!.yPos(),
        ourbot!.direction() + relang,
        5,
        length,
      );
    }
    if (stackTaken[1][0]) {
      relang = portStack[1][0];
      movePortStack(1);
    }
    if (stackTaken[2][0]) {
      length = portStack[2][0];
      movePortStack(2);
    }
  }

  @override
  int readPort(int port) {
    switch (port) {
      case 0:
        return relang;
      case 1:
        return length;
    }
    return 0;
  }
}
