import '../core/device.dart';
import '../core/screen_object.dart';

// Porte de src/scandetect.h e src/scandetect.cpp (droidbattles
// original) -- detector de varredura: conta quantas vezes o bot foi
// escaneado e guarda intensidade/direcao da ultima.
class ScanDetect extends Device {
  ScanDetect(ScreenObject object) : super(object);

  int numScans = 0;
  int lastScanIntensity = 0;
  int lastScanDir = 0;

  @override
  void execute() {
    // Porta 0: zera o contador.
    if (stackTaken[0][0]) {
      numScans = 0;
      movePortStack(0);
    }
  }

  @override
  int readPort(int port) {
    switch (port) {
      case 0:
        return numScans;
      case 1:
        return lastScanDir;
      case 2:
        return lastScanIntensity;
    }
    return 0;
  }

  /// Tipo 11 (`scanWarnType`) -- e assim que `Robots.objectScanned`
  /// acha este device.
  @override
  int type() => 11;

  /// Chamado pelo scanner inimigo, via `Robots.objectScanned`.
  @override
  void doSpecial(int intensity, [int dir = 0]) {
    numScans++;
    lastScanDir = dir;
    lastScanIntensity = intensity;
  }
}
