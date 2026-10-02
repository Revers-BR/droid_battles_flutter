import '../vm/common_symbols.dart';

// Porte de src/screenobject.h e src/screenobject.cpp (droidbattles
// original). E a classe base de TODO objeto "ativo" na arena: robos,
// projeteis, minas, explosoes, e ate o "objeto vazio" que ocupa um
// slot destruido/nao usado (era `new ScreenObject()` no C++, usado
// como placeholder).
//
// Subclasses (Robot, Missile, Mine, Beam, Rocket, Chaff, RadarMissile,
// Explosion, ...) sobrescrevem os metodos abaixo -- no C++ eram todos
// `virtual`. Aqui cada metodo tem o corpo "vazio" (default) do
// screenobject.cpp original; subclasses fazem `@override`.
class ScreenObject {
  ScreenObject() {
    // NOTA: o construtor original tem um bug/typo -- ele atribui
    // -100000 pra `Xpos` DUAS vezes (`Xpos = -100000; Xpos = -100000;`),
    // entao `Ypos` nunca e inicializado ali (fica com lixo de memoria
    // em C++, comportamento indefinido). Aqui inicializamos Ypos = 0
    // como valor razoavel, ja que nao ha "lixo de memoria" em Dart pra
    // replicar literalmente.
    xPosRaw = -100000;
    yPosRaw = 0;
    noncollid = collEnabled; // 256
    heatval = 0;
  }

  /// Tipo/estado do objeto (era o enum `ObjectType`).
  static const int nonCollidable = -1;
  static const int destroyed = 0;
  static const int botObject = 1;
  static const int collidable = 2;

  // ---- estado interno (era `protected:` no C++) ----
  int upcount = 0;
  int heatval = 0;
  double xPosRaw = 0;
  double yPosRaw = 0;
  int oldX = 0;
  int oldY = 0;
  int mDirection = 0;
  int mSpeed = 0;
  bool canBeHit = false;
  int mynum = 0;
  int mSize = 1;
  String debug1 = '';
  String debug2 = '';
  bool showExtraGfx = false;
  int maxx = 0;
  int maxy = 0;
  int mTeam = 0;
  int noncollid = collEnabled;
  int myowner = 0;
  bool useUI = false;

  // Eram os `signals` Qt (armorchanged/fuelchanged/messagechanged).
  // Guardados aqui como callbacks opcionais pra camada de UI conectar
  // quando `lib/ui` for portado; nao fazem nada por padrao.
  void Function(int value)? onArmorChanged;
  void Function(int fuel, int max)? onFuelChanged;
  void Function(String msg)? onMessageChanged;

  // ---- campos publicos (eram publicos no C++ tambem) ----
  int armorval = 0;
  int fuelval = 0;
  String myfile = '';

  /// Era `ScreenObject::setPosition` -- soma um delta a posicao e
  /// contem dentro dos limites da arena (`maxx`/`maxy`).
  int setPosition(double dx, double dy) {
    oldX = xPosRaw.toInt();
    oldY = yPosRaw.toInt();
    xPosRaw += dx;
    yPosRaw += dy;
    if (xPosRaw < 0) xPosRaw = 0;
    if (xPosRaw > maxx) xPosRaw = maxx.toDouble();
    if (yPosRaw < 0) yPosRaw = 0;
    if (yPosRaw > maxy) yPosRaw = maxy.toDouble();
    return 0;
  }

  /// Era `ScreenObject::changeDirection` -- soma e mantem no intervalo
  /// [0, 1024) ("graus de bot": 1024 = volta completa).
  void changeDirection(int z) {
    mDirection += z;
    if (mDirection >= 1024) mDirection -= 1024;
    if (mDirection < 0) mDirection += 1024;
  }

  /// Era `ScreenObject::changeSpeed` -- soma e limita entre -75 e 100.
  void changeSpeed(int z) {
    mSpeed += z;
    if (mSpeed < -75) mSpeed = -75;
    if (mSpeed > 100) mSpeed = 100;
  }

  int xPos() => xPosRaw.toInt();
  int yPos() => yPosRaw.toInt();
  int direction() => mDirection;
  int speed() => mSpeed;
  void setSpeed(int x) => mSpeed = x;
  int number() => mynum;
  int size() => mSize;
  int team() => mTeam;
  int owner() => myowner;
  int fuel() => fuelval;
  int armor() => armorval;
  int heat() => heatval;
  void setHeat(int x) => heatval = x;

  void setFuel(int x) => fuelval += x;

  void changeHeat(int x) {
    heatval += x;
    if (heatval < 0) heatval = 0;
  }

  /// Era `ScreenObject::execute()` -- chamado uma vez por "tick" da
  /// arena; subclasses fazem a logica de movimento/IA/CPU aqui.
  int execute() => 0;

  int readDevicePort(int port) => 0;
  void writeDevicePort(int port, int value) {}

  /// Era `ScreenObject::objectHit` -- retorna 1 se o dano destruiu o
  /// objeto (objHitDestroyed), 0 caso contrario.
  int objectHit(int type, int strength) => objHitNotDestroyed;

  void addScreenObject(int x, int y, int dir, int type, [int arg1 = 0, int arg2 = 0, Object? arg3]) {}

  /// Era `ScreenObject::type()`. Objetos "vazios" (placeholder) sao
  /// `destroyed` por padrao -- e assim que a arena sabe que o slot
  /// esta livre pra reciclar.
  int type() => destroyed;

  int writeToBattleArea(int bot, int dev, int choice, int arg1, int arg2) => 0;
  int writeToDevice(int dev, int action, int value) => 0;

  String getDebugMessage1() => debug1;
  String getDebugMessage2() => debug2;
  void setDebugVariable1(int msg) {}
  void setDebugVariable2(int msg) {}

  void setExtraGfx(bool x) => showExtraGfx = x;

  int collisionType() => 0;
  int collisionStrength() => 0;

  void writeRadio(int sig) {}

  int memorySize() => 0;

  void addInterrupt(int inter) {}

  bool areaExplosionAffects() => true;

  int returnRadar() => 0;

  /// Era `ScreenObject::collisionId()` -- por padrao `noncollid`
  /// (256/`collEnabled`), o que significa "sempre colide com todo
  /// mundo" (ver o teste em `TextmodeBattleArea::execround`).
  int collisionId() => noncollid;

  /// Era `ScreenObject::sendMessage` -- so dispara o callback de UI se
  /// `useUI` estiver ligado (mesma condicional do original).
  void sendMessage(String msg) {
    if (useUI) {
      onMessageChanged?.call(msg);
    }
  }

  void objectScanned(int intensity, int dir) {}

  void setRadar(int x) {}

  void dumpRam() {}
}
