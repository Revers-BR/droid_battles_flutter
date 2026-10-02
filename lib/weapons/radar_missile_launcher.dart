import '../core/device.dart';
import '../core/screen_object.dart';
import '../vm/ram.dart';

// Porte de src/radarmissilelauncher.h e src/radarmissilelauncher.cpp
// (droidbattles original) -- lancador de misseis de radar
// programaveis: a CPU do missil roda a MESMA RAM do bot que o
// disparou, a partir de `bootMem`/`stackMem`.
class RadarMissileLauncher extends Device {
  RadarMissileLauncher(ScreenObject object, int level, this.memd, int offset)
      : super(object) {
    ourlevel = level;
    relang = offset * 4;
    reloadTime = 1;
  }

  final Ram memd;
  int reloadTime = 1;

  /// `uint16_t` no C++ e nao inicializados (lixo); comecam em 0.
  int bootMem = 0;
  int stackMem = 0;

  @override
  void execute() {
    if (reloadTime > 0) reloadTime--;

    // Define o endereco de boot.
    if (stackTaken[0][0]) {
      bootMem = portStack[0][0] & 0xFFFF;
      movePortStack(0);
    }
    // Define o endereco da pilha.
    if (stackTaken[1][0]) {
      stackMem = portStack[1][0] & 0xFFFF;
      movePortStack(1);
    }
    // Dispara um missil.
    if (stackTaken[2][0]) {
      if (reloadTime <= 0) {
        ourbot!.addScreenObject(
          ourbot!.xPos(),
          ourbot!.yPos(),
          ourbot!.direction() + relang,
          4,
          bootMem,
          stackMem,
          memd,
        );
        movePortStack(2);
        reloadTime = ourlevel;
      }
    }
  }

  @override
  int readPort(int port) {
    switch (port) {
      case 0:
        return reloadTime;
    }
    return 0;
  }
}
