import 'screen_object.dart';

// Porte de src/device.h e src/device.cpp (droidbattles original).
// Classe base de todos os dispositivos que um bot pode equipar
// (armadura, escudo, motor, scanner, torreta, CPU, etc.).
class Device {
  Device([ScreenObject? object]) : ourbot = object;

  /// Nomes dos tipos de device, na mesma ordem/indices do
  /// `s_deviceNames` original -- usado pela tela de montagem do bot.
  static const List<String> _deviceNames = [
    'CPU',
    'engine',
    'steering',
    'plasmagun',
    'armor',
    'scanner',
    'fuel',
    'chaff',
    'turret',
    'scanwarner',
    'timedev',
    'shield',
    'repair',
    'radio',
    'chiller',
    'cloaker',
    'minelayer',
    'missile',
    'beam',
    'AS-rocket',
  ];

  static String deviceName(int index) {
    if (index >= 0 && index < _deviceNames.length) {
      return _deviceNames[index];
    }
    return 'Unknown device $index';
  }

  static int deviceId(String name) {
    final i = _deviceNames.indexOf(name);
    return i == -1 ? 0 : i;
  }

  /// Era `ScreenObject *ourbot` -- o robo (ou outro screen object) dono
  /// deste device.
  ScreenObject? ourbot;

  // Era `int portstack[4][4]` / `bool stacktaken[4][4]`: uma fila de
  // ate 4 valores pendentes por porta (0-3), usada pra comunicacao
  // CPU <-> device via OUT/IN.
  final List<List<int>> portStack = List.generate(4, (_) => List.filled(4, 0));
  final List<List<bool>> stackTaken = List.generate(4, (_) => List.filled(4, false));

  int relang = 0;
  int ourlevel = 0;
  bool intEnabled = false;
  bool intEnabled2 = false;

  /// Era `Device::addInputPort` -- um OUT da CPU empilha um valor
  /// numa porta do device.
  ///
  /// NOTA: o C++ original tem um bug -- o loop procura a primeira
  /// posicao livre em `stacktaken[port][count]`, mas sempre ESCREVE
  /// em `[port][0]` (`stacktaken[port][0] = true`), nao em
  /// `[port][count]`. Ou seja, na pratica so a posicao 0 e usada de
  /// verdade, mesmo quando ja esta ocupada. Replicado aqui de
  /// propósito, fiel ao original.
  void addInputPort(int port, int value) {
    for (var count = 0; count < 4; count++) {
      if (!stackTaken[port][count]) {
        stackTaken[port][0] = true;
        portStack[port][0] = value;
        break;
      }
    }
  }

  /// Era `Device::moveportstack` -- desloca a fila da porta uma
  /// posicao pra baixo (consome o valor mais antigo).
  void movePortStack(int port) {
    for (var count = 0; count < 3; count++) {
      portStack[port][count] = portStack[port][count + 1];
      stackTaken[port][count] = stackTaken[port][count + 1];
    }
    portStack[port][3] = 0;
    stackTaken[port][3] = false;
  }

  void setRelativeAngle(int x) => relang = x;

  /// Chamado uma vez por tick; subclasses (Armor, Shield, Engine...)
  /// fazem sua logica aqui.
  void execute() {}

  int readPort(int port) => 0;

  /// Era `Device::absorbHit` -- por padrao devolve o dano sem
  /// absorver nada; Armor/Shield sobrescrevem isso.
  int absorbHit(int str, int ifInt) => str;

  int type() => 0;
  int specialValue() => 0;

  void doSpecial(int x, [int y = 0]) {}
}
