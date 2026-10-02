import 'device.dart';
import 'screen_object.dart';

// Porte de src/engine.h e src/engine.cpp (droidbattles original) --
// propulsao: acelera/freia o bot conforme as portas 0 (marcha a
// frente) e 1 (re/freio), gastando combustivel e gerando calor.
//
// NOTA: nao confundir com o antigo lib/ui/engine.dart -- aquele nome
// veio de um mapeamento inicial errado (achava que "engine.h" era o
// loop principal do jogo). O `engine.h` original e este device de
// propulsao mesmo; o loop principal do jogo, se vier a existir, e uma
// peca nova da UI Flutter sem equivalente direto no C++.
class Engine extends Device {
  Engine(ScreenObject object, int arg1) : super(object) {
    ourlevel = arg1;
    thrust = 0;
  }

  int thrust = 0;

  @override
  void execute() {
    if (stackTaken[0][0]) {
      thrust = portStack[0][0];
      if (thrust > ourlevel) thrust = ourlevel;
      if (thrust < 0) thrust = 0;
      movePortStack(0);
    }
    if (stackTaken[1][0]) {
      thrust = -portStack[1][0];
      if (thrust < -(ourlevel ~/ 2)) thrust = -(ourlevel ~/ 2);
      if (thrust > 0) thrust = 0;
      movePortStack(1);
    }

    if (thrust >= 0) {
      ourbot!.changeHeat(thrust ~/ 35);
      if (thrust > ourbot!.speed() && ourbot!.fuel() >= thrust + 1) {
        ourbot!.changeSpeed(1);
        if (thrust > 0) {
          ourbot!.setFuel(-(1 + thrust ~/ 10));
        }
      } else {
        if (ourbot!.speed() > 0) ourbot!.changeSpeed(-1);
        if (ourbot!.speed() < 0) ourbot!.changeSpeed(1);
      }
    }
    if (thrust < 0) {
      ourbot!.changeHeat(-(thrust ~/ 25));
      if (thrust < ourbot!.speed() && ourbot!.fuel() >= (-thrust) + 1) {
        ourbot!.changeSpeed(-1);
        ourbot!.setFuel(-(1 + (-thrust) ~/ 10));
      } else {
        if (ourbot!.speed() < 0) ourbot!.changeSpeed(1);
        if (ourbot!.speed() > 0) ourbot!.changeSpeed(-1);
      }
    }
  }

  @override
  int readPort(int port) {
    switch (port) {
      case 0:
        return thrust;
      case 1:
        return ourbot!.speed();
    }
    return 0;
  }
}
