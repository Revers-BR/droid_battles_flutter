import '../core/device.dart';
import '../core/screen_object.dart';

// Porte de src/turret.h e src/turret.cpp (droidbattles original) --
// torreta: gira, em relacao ao heading do bot, o device apontado por
// `ourdev` (arma/scanner "turretavel") ate o offset desejado.
class Turret extends Device {
  Turret(ScreenObject object, int arg1, int dev) : super(object) {
    ourlevel = arg1;
    ourDev = dev;
    offset = 0;
    wantedOffset = 0;
  }

  int ourDev = 0;
  int wantedOffset = 0;
  int offset = 0;

  @override
  int readPort(int port) {
    switch (port) {
      case 0:
        return offset;
      case 1:
        return wantedOffset;
    }
    return 0;
  }

  @override
  void execute() {
    if (stackTaken[0][0]) {
      wantedOffset = portStack[0][0];
      if (wantedOffset > 1024) wantedOffset %= 1024;
      if (wantedOffset < 0) wantedOffset += 1024;
      movePortStack(0);
    }
    if (stackTaken[1][0]) {
      wantedOffset += portStack[1][0];
      if (wantedOffset > 1023) wantedOffset %= 1024;
      if (wantedOffset < 0) wantedOffset += 1024;
      movePortStack(1);
    }
    if (stackTaken[2][0]) {
      wantedOffset = offset + portStack[2][0];
      if (wantedOffset > 1023) wantedOffset %= 1024;
      if (wantedOffset < 0) wantedOffset += 1024;
      movePortStack(2);
    }

    // Gira a torreta pelo caminho mais curto.
    int left, right;
    if (wantedOffset < offset) {
      left = offset - wantedOffset;
      right = wantedOffset + 1024 - offset;
    } else {
      left = offset + 1024 - wantedOffset;
      right = wantedOffset - offset;
    }

    if (right > left) {
      if (left < ourlevel) {
        offset = wantedOffset;
      } else {
        offset -= ourlevel;
      }
    } else {
      if (right < ourlevel) {
        offset = wantedOffset;
      } else {
        offset += ourlevel;
      }
    }

    if (offset >= 1024) offset -= 1024;
    if (offset < 0) offset += 1024;

    ourbot!.writeToDevice(ourDev, 1, offset);
  }
}
