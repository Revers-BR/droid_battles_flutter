import 'device.dart';
import 'screen_object.dart';

// Porte de src/chiller.h e src/chiller.cpp (droidbattles original) --
// resfriador: dissipa calor todo ciclo; ligado (e com combustivel)
// dissipa o dobro, gastando 5 de combustivel.
class Chiller extends Device {
  Chiller(ScreenObject object, int arg1) : super(object) {
    isOn = false;
    heatDiss = arg1;
  }

  bool isOn = false;
  int heatDiss = 0;

  @override
  void execute() {
    if (isOn && ourbot!.fuel() > 5) {
      ourbot!.changeHeat(-(heatDiss * 2));
      ourbot!.setFuel(-5);
    } else {
      ourbot!.changeHeat(-heatDiss);
    }
    if (stackTaken[0][0]) {
      isOn = portStack[0][0] != 0;
      movePortStack(0);
    }
  }
}
