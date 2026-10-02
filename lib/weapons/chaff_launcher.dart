import '../core/device.dart';
import '../core/screen_object.dart';

// Porte de src/chafflauncher.h e src/chafflauncher.cpp (droidbattles
// original) -- lancador de chaff; o "nivel" e o estoque.
class ChaffLauncher extends Device {
  ChaffLauncher(ScreenObject object, int level) : super(object) {
    chaffLeft = level;
  }

  int chaffLeft = 0;

  @override
  void execute() {
    if (stackTaken[0][0]) {
      movePortStack(0);
      if (chaffLeft > 0) {
        // Velocidade do chaff = metade da do bot (divisao inteira).
        ourbot!.addScreenObject(
          ourbot!.xPos(),
          ourbot!.yPos(),
          ourbot!.direction(),
          7,
          ourbot!.speed() ~/ 2,
        );
        chaffLeft--;
      }
    }
  }

  @override
  int readPort(int port) {
    switch (port) {
      case 0:
        return chaffLeft;
    }
    return 0;
  }
}
