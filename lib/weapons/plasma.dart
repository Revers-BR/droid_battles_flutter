import '../core/device.dart';
import '../core/screen_object.dart';

// Porte de src/plasma.h e src/plasma.cpp (droidbattles original) --
// canhao de plasma: acumula "prontidao" e, quando a CPU manda atirar
// (porta 0), pede pra arena criar um projetil.
//
// NOTA: o esqueleto inicial tinha `Plasma extends ScreenObject`
// (projetil) -- errado: no original `Plasma` e o DEVICE (extends
// Device). O projetil que ele dispara e o objeto de tipo 2 de
// `addScreenObject` (o `Missile`, lib/weapons/missile.dart, ainda nao
// portado).
class Plasma extends Device {
  Plasma(ScreenObject object, int arg1, int offset) : super(object) {
    ourlevel = arg1;
    readiness = 200;
    relang = offset * 4;
  }

  int readiness = 200;

  @override
  void execute() {
    if (readiness < 200) {
      readiness += ourlevel;
    }
    if (stackTaken[0][0] && readiness > 0) {
      movePortStack(0);
      // Dispara o projetil de plasma (objeto tipo 2 na arena).
      ourbot!.addScreenObject(
        ourbot!.xPos(),
        ourbot!.yPos(),
        ourbot!.direction() + relang,
        2,
        ourbot!.number(),
      );
      ourbot!.changeHeat(45);
      readiness -= 80;
    }
  }
}
