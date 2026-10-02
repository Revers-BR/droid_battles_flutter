import '../vm/common_symbols.dart';
import 'device.dart';
import 'screen_object.dart';

// Porte de src/fuel.h e src/fuel.cpp (droidbattles original) --
// tanque de combustivel: fornece energia pra motor/escudo/laser.
class Fuel extends Device {
  Fuel(ScreenObject object, int arg1) : super(object) {
    ourbot!.setFuel(arg1);
    intEnabled = false;
  }

  int fuelIntLevel = 0;

  @override
  int readPort(int port) {
    switch (port) {
      case 0:
        return ourbot!.fuel();
    }
    return 0;
  }

  /// Primeiro checa se deve disparar a interrupcao de "combustivel
  /// abaixo do nivel", depois processa ordens pendentes nas portas.
  @override
  void execute() {
    if (intEnabled) {
      if (ourbot!.fuel() < fuelIntLevel) {
        ourbot!.addInterrupt(fuelLevelInt);
      }
    }
    if (stackTaken[0][0]) {
      intEnabled = portStack[0][0] != 0;
      movePortStack(0);
    }
    if (stackTaken[1][0]) {
      fuelIntLevel = portStack[1][0];
      movePortStack(1);
    }
  }
}
