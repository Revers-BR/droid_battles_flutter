import '../vm/common_symbols.dart';
import 'device.dart';
import 'screen_object.dart';

// Porte de src/armor.h e src/armor.cpp (droidbattles original) --
// blindagem: absorve dano ate esgotar, e tambem serve como "vida"
// (armorval chega a 0 -> bot morre, ver Robots::execute).
class Armor extends Device {
  Armor(ScreenObject object, int arg1) : super(object) {
    strength = arg1;
    orStrength = strength;
    ourbot!.armorval += strength;
    ourlevel = arg1;
    intEnabled = false;
    intEnabled2 = false;
    heatIntLevel = 1000;
  }

  int strength = 0;
  int orStrength = 0;
  int armorIntLevel = 0;
  int heatIntLevel = 1000;

  @override
  void execute() {
    if (intEnabled2) {
      if (ourbot!.armorval < armorIntLevel) {
        ourbot!.addInterrupt(armLevelInt);
      }
    }
    if (ourbot!.heat() > heatIntLevel) {
      ourbot!.addInterrupt(5); // interrupcao de superaquecimento -- o original usa o literal 5 direto, sem constante nomeada em commonsymbols.h
    }
    if (stackTaken[0][0]) {
      intEnabled = portStack[0][0] != 0;
      movePortStack(0);
    }
    if (stackTaken[1][0]) {
      intEnabled2 = portStack[1][0] != 0;
      movePortStack(1);
    }
    if (stackTaken[2][0]) {
      armorIntLevel = portStack[2][0];
      movePortStack(2);
    }
    if (stackTaken[3][0]) {
      heatIntLevel = portStack[3][0];
      movePortStack(3);
    }
  }

  /// Retorna quanto do dano NAO foi absorvido (0 = absorveu tudo).
  @override
  int absorbHit(int str, int ifInt) {
    if (strength >= str) {
      strength -= str;
      ourbot!.armorval -= str;
      if (intEnabled && ifInt == 1) {
        ourbot!.addInterrupt(hitInterrupt);
      }
      return 0;
    }
    final left = str - strength;
    ourbot!.armorval -= strength;
    strength = 0;
    return left;
  }

  @override
  int type() => armorType;

  /// Quanto de blindagem ja foi perdido (original menos atual).
  @override
  int specialValue() => orStrength - strength;

  @override
  int readPort(int port) {
    switch (port) {
      case 0:
        return ourbot!.armor();
      case 1:
        return ourbot!.heat();
    }
    return 0;
  }

  /// Reduz a blindagem sem contar como "hit" (usada pelo Repair pra
  /// nao disparar a interrupcao de dano a cada reparo).
  @override
  void doSpecial(int x, [int y = 0]) {
    ourbot!.armorval -= x;
    strength -= x;
  }
}
