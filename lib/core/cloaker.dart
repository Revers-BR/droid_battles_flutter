import 'device.dart';
import 'screen_object.dart';

// Porte de src/cloaker.h e src/cloaker.cpp (droidbattles original) --
// camuflagem: ligada (e com combustivel) reduz o quao visivel o bot
// e no radar, gastando combustivel e gerando calor.
//
// Fica de fora (so UI, Qt): `draw` (as linhas semitransparentes sobre
// o bot). `cloakOn` e `tickOrTock` ficam expostos pra camada de UI
// mobile usar quando ela existir.
class Cloaker extends Device {
  Cloaker(ScreenObject object, int arg1) : super(object) {
    ourlevel = arg1;
  }

  bool cloakOn = false;
  bool tickOrTock = false;

  @override
  void execute() {
    if (cloakOn && ourbot!.fuel() > 5) {
      ourbot!.setFuel(-6);
      ourbot!.changeHeat(5 + ourlevel);
      ourbot!.setRadar(5 - ourlevel);
    }
    if (stackTaken[0][0]) {
      cloakOn = portStack[0][0] != 0;
      movePortStack(0);
    }
    tickOrTock = !tickOrTock;
  }
}
