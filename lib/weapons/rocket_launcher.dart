import '../core/device.dart';
import '../core/screen_object.dart';

// Porte de src/rocketlauncher.h e src/rocketlauncher.cpp
// (droidbattles original) -- lancador de foguetes AS.
class RocketLauncher extends Device {
  RocketLauncher(ScreenObject object, int level, int offset) : super(object) {
    ourlevel = level;
    readiness = 200;
    relang = offset * 4;
  }

  int readiness = 200;

  /// Distancia de explosao (nao inicializada no C++; comeca em 0).
  int distance = 0;

  @override
  void execute() {
    if (readiness < 200) readiness++;

    // Define a distancia.
    if (stackTaken[0][0]) {
      distance = portStack[0][0];
      movePortStack(0);
    }
    // Dispara um foguete.
    if (stackTaken[1][0]) {
      if (readiness > 100) {
        ourbot!.addScreenObject(
          ourbot!.xPos(),
          ourbot!.yPos(),
          ourbot!.direction() + relang,
          6,
          distance,
        );
        movePortStack(1);
        readiness -= ourlevel;
      }
    }
  }

  @override
  int readPort(int port) {
    switch (port) {
      case 0:
        return readiness;
      case 1:
        return distance;
    }
    return 0;
  }
}
