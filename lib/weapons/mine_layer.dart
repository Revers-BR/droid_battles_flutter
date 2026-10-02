import '../core/device.dart';
import '../core/screen_object.dart';

// Porte de src/minelayer.h e src/minelayer.cpp (droidbattles
// original) -- device que planta minas; o "nivel" e o estoque.
class MineLayer extends Device {
  MineLayer(ScreenObject object, int level) : super(object) {
    minesLeft = level;
  }

  int minesLeft = 0;

  @override
  void execute() {
    if (stackTaken[0][0]) {
      movePortStack(0);
      if (minesLeft > 0) {
        ourbot!.addScreenObject(ourbot!.xPos(), ourbot!.yPos(), ourbot!.direction(), 3);
        minesLeft--;
      }
    }
  }

  /// Qualquer porta devolve quantas minas restam.
  @override
  int readPort(int port) => minesLeft;
}
