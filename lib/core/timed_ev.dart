import '../vm/common_symbols.dart';
import 'device.dart';
import 'screen_object.dart';

// Porte de src/timedev.h e src/timedev.cpp (droidbattles original) --
// "TimeDev": relogio do bot, com interrupcao de tempo opcional.
//
// NOTA: o esqueleto inicial tinha aqui uma classe `TimedEvent` sem
// equivalente no C++; o `timedev.h` original e este device (`TimeDev`).
class TimeDev extends Device {
  TimeDev(ScreenObject object) : super(object) {
    timeCount = 0;
    intEnabled = false;
  }

  int timeCount = 0;

  /// Nao inicializado no C++ (lixo de memoria); comeca em 0.
  int interruptTime = 0;

  @override
  void execute() {
    timeCount++;
    if (stackTaken[0][0]) {
      timeCount = portStack[0][0];
      movePortStack(0);
    }
    if (stackTaken[1][0]) {
      interruptTime = portStack[1][0];
      movePortStack(1);
    }
    if (stackTaken[2][0]) {
      intEnabled = portStack[2][0] != 0;
      movePortStack(2);
    }
    if (timeCount == interruptTime && intEnabled) {
      ourbot!.addInterrupt(timeInterrupt);
    }
  }

  @override
  int readPort(int port) {
    switch (port) {
      case 0:
        return timeCount;
      case 1:
        return interruptTime;
      case 2:
        return intEnabled ? 1 : 0;
    }
    return 0;
  }
}
