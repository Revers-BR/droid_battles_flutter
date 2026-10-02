import '../vm/common_symbols.dart';
import 'device.dart';
import 'screen_object.dart';

// Porte de src/repair.h e src/repair.cpp (droidbattles original) --
// reparo automatico: a cada `ourlevel` ciclos recupera 1 ponto de
// blindagem (procura o primeiro device tipo 99 = Armor que ja perdeu
// vida).
class Repair extends Device {
  Repair(ScreenObject object, int arg1) : super(object) {
    ourlevel = arg1;
    repairCycles = ourlevel;
  }

  int repairCycles = 0;

  @override
  void execute() {
    if (--repairCycles <= 0) {
      repairCycles = ourlevel;
      for (var count = 0; count < 32; count++) {
        if (ourbot!.writeToDevice(count, 2, 0) == armorType &&
            ourbot!.writeToDevice(count, 3, 0) > 0) {
          ourbot!.writeToDevice(count, 4, -1); // repara 1 de dano
          break;
        }
      }
      return;
    }
  }

  @override
  int readPort(int port) => 0;
}
