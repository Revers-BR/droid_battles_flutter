import '../core/device.dart';
import '../core/screen_object.dart';
import '../persistence/bot_file_access.dart';
import 'ram.dart';
import 'register_file.dart';

// Porte de src/cpu.h e src/cpu.cpp (droidbattles original).
//
// No C++, `CPU` herda de `Device` (que por sua vez guarda `ourbot`, o
// ScreenObject dono) -- e e assim que a CPU fala com o resto do robo
// (`ourbot->writeDevicePort`, `ourbot->team()`, etc.). Reproduzimos a
// mesma hierarquia aqui: `Cpu extends Device`, usando `ourbot` herdado
// em vez de uma interface separada.
class Cpu extends Device {
  Cpu(this.mem, ScreenObject owner, {this.fileAccess}) : super(owner);

  /// Implementacao de I/O de arquivo injetada por quem cria a CPU
  /// (tipicamente `Robots`/`RadarMissile`); null = leitura/escrita
  /// sempre falha, como um `QFile::open` que nao consegue abrir.
  final BotFileAccess? fileAccess;

  final Ram mem;

  final RegisterFile registers = RegisterFile();

  /// Tabela de latencia por opcode (era `uint8_t instrlatency[256]`).
  /// Preenchida pela subclasse (RobCpu) com os valores extraidos do
  /// construtor original.
  final List<int> instrLatency = List<int>.filled(256, 0);

  /// Enderecos executados no ultimo ciclo, para depuracao (era
  /// `int lastexecmem[30]`).
  final List<int> lastExecMem = List<int>.filled(30, -1);

  int speed = 0;
  int cyclesLeft = 0;
  int bootMem = 0;
  int stackMem = 0;

  /// Era `CPU::callobout` -- OUT escreve numa porta de device do robo.
  void callObOut(int port, int value) => ourbot!.writeDevicePort(port, value);

  /// Era `CPU::callobin` -- IN le uma porta de device do robo.
  int callObIn(int port) => ourbot!.readDevicePort(port);

  /// Era `CPU::sendmsg`. RobCpu sobrescreve para repassar pro host.
  void sendMsg(String msg) {}

  /// Era `CPU::execinstr` -- a subclasse (RobCpu) implementa o loop
  /// real de busca/decodificacao/execucao.
  void execInstr() {}

  /// Portas 0-3 comuns a qualquer CPU (era `CPU::readPort`):
  /// tamanho X/Y da arena, duracao maxima da batalha e time do bot.
  @override
  int readPort(int port) {
    switch (port) {
      case 0:
        return ourbot!.writeToBattleArea(0, 0, 10, 0, 0); // Xsize da arena
      case 1:
        return ourbot!.writeToBattleArea(0, 0, 11, 0, 0); // Ysize da arena
      case 2:
        return ourbot!.writeToBattleArea(0, 0, 12, 0, 0); // duracao maxima
      case 3:
        return ourbot!.team();
    }
    return 0;
  }

  /// Era `CPU::writefile`. Le `length` bytes da RAM a partir de
  /// `address` e escreve no arquivo de dados do robo (`ourbot.myfile`, um ".dat" com o mesmo nome do bot), a partir do byte
  /// `start` -- ver o aviso sobre truncamento em [BotFileAccess].
  int writeFile(int start, int length, int address) {
    final maxBytes = (mem.returnSize() % 1024) * 64;
    if (start + length > maxBytes) return -1;
    if (fileAccess == null) return -1;

    final buffer = List<int>.filled(length, 0);
    for (var x = 0; x < length; x++) {
      buffer[x] = mem.getIByte(address + x);
    }
    return fileAccess!.writeAt(ourbot!.myfile, start, buffer, 0, length);
  }

  /// Era `CPU::readfile`. Le `length` bytes do arquivo de dados do robo (`ourbot.myfile`), a
  /// partir do byte `start`, e escreve na RAM a partir de `address`.
  int readFile(int start, int length, int address) {
    final maxBytes = (mem.returnSize() % 1024) * 64;
    if (start + length > maxBytes) return -1;
    if (fileAccess == null) return -1;

    final buffer = List<int>.filled(length, 0);
    final ret = fileAccess!.readAt(ourbot!.myfile, start, length, buffer, 0);
    for (var x = 0; x < length; x++) {
      mem.setIByte(address + x, buffer[x]);
    }
    return ret;
  }
}
