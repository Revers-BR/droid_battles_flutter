import 'device.dart';
import 'screen_object.dart';

// Porte de src/shield.h e src/shield.cpp (droidbattles original) --
// escudo de energia: absorve uma % do dano enquanto ligado, custando
// combustivel e gerando calor.
class Shield extends Device {
  Shield(ScreenObject object, int arg1) : super(object) {
    ourlevel = arg1;
    isUp = false;
  }

  bool isUp = false;

  /// Liga/desliga o escudo (conforme porta 0), desliga sozinho se o
  /// combustivel acabar; consome combustivel e gera calor enquanto
  /// ligado.
  @override
  void execute() {
    if (stackTaken[0][0]) {
      isUp = portStack[0][0] != 0;
      movePortStack(0);
    }
    if (ourbot!.fuel() <= 3) {
      isUp = false;
    }
    if (isUp) {
      ourbot!.setFuel(-4);
      ourbot!.changeHeat(1);
    }
  }

  @override
  int absorbHit(int strength, int ifInt) {
    if (isUp) {
      var strAbsorb = (strength * ourlevel * 0.01).toInt();
      if (strAbsorb > ourlevel) strAbsorb = ourlevel;
      ourbot!.changeHeat(strAbsorb * 4);
      return strength - strAbsorb;
    }
    return strength;
  }

  @override
  int readPort(int port) {
    switch (port) {
      case 0:
        return isUp ? 1 : 0;
    }
    return 0;
  }

  // draw/erase do original sao puramente Qt (desenhar o circulo azul
  // do escudo); ficam pra camada de UI (lib/ui) quando ela existir.
}
