import '../core/device.dart';
import '../core/screen_object.dart';
import 'common_symbols.dart';

// Porte de src/communication.h e src/communication.cpp (droidbattles
// original) -- radio entre bots do mesmo time: fila de ate 32
// mensagens recebidas + envio pra um receptor do time.
class Communication extends Device {
  Communication(ScreenObject object) : super(object) {
    intEnabled = false;
  }

  final List<int> msgList = List<int>.filled(32, 0);
  int numMsg = 0;

  /// Nao inicializado no C++; comeca em 0.
  int receiver = 0;

  @override
  void execute() {
    // Porta 0: define o receptor.
    if (stackTaken[0][0]) {
      receiver = portStack[0][0];
      movePortStack(0);
    }
    // Porta 1: envia um numero.
    if (stackTaken[1][0]) {
      final numberToSend = portStack[1][0];
      movePortStack(1);
      ourbot!.writeToBattleArea(ourbot!.team(), 0, 7, numberToSend, receiver);
    }
    // Porta 2: liga/desliga a interrupcao de mensagem.
    if (stackTaken[2][0]) {
      intEnabled = portStack[2][0] != 0;
      movePortStack(2);
    }
  }

  @override
  int readPort(int port) {
    switch (port) {
      case 0:
        return numMsg;
      case 1:
        // ATENCAO (bug do original, mantido): o C++ guarda a primeira
        // mensagem em `msg`, desloca a fila e depois retorna
        // `msglist[0]` -- ou seja, a SEGUNDA mensagem, nao a que
        // acabou de sair. Tambem nao limpa `msglist[31]` e deixa
        // `nummsg` ficar negativo com a fila vazia.
        for (var x = 0; x < 31; x++) {
          msgList[x] = msgList[x + 1];
        }
        numMsg--;
        return msgList[0];
      case 2:
        return intEnabled ? 1 : 0;
      case 3:
        return ourbot!.number();
    }
    return 0;
  }

  /// Chamado por `Robots.writeRadio` quando chega uma mensagem.
  @override
  void doSpecial(int x, [int y = 0]) {
    if (numMsg < 32) {
      msgList[numMsg++] = x;
    }
    if (intEnabled) {
      ourbot!.addInterrupt(msgInterrupt);
    }
  }
}
