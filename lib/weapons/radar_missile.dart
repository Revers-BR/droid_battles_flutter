import 'dart:math' as math;

import '../battle/text_mode_battle_area.dart';
import '../core/device.dart';
import '../core/screen_object.dart';
import '../core/steering.dart';
import '../vm/common_symbols.dart';
import '../persistence/bot_file_access.dart';
import '../vm/ram.dart';
import '../vm/rob_cpu.dart';
import 'scanner.dart';

// Porte de src/radarmissile.h e src/radarmissile.cpp (droidbattles
// original) -- missil programavel: um mini-robo com CPU propria
// (rodando a RAM do bot que o lancou), direcao e radar, que persegue
// alvos e explode ao contato.
//
// Fica de fora (so UI, Qt): eraseObject/drawObject, e o
// `createDbgWindow`/`dbgWindow` (janela de depuracao do assembly do
// missil) -- isso volta na camada de telas mobile.
//
// A vida util da `Ram` compartilhada (era contagem de donos com
// addowner/removeowner + delete no destrutor) fica por conta do
// coletor de lixo do Dart.
class RadarMissile extends ScreenObject {
  RadarMissile(
    int x,
    int y,
    int dir,
    int bootm,
    int stm,
    int mnum,
    this.ourArea,
    this.ramDevice,
    int owner, {
    bool ui = true,
    BotFileAccess? fileAccess,
  }) {
    useUI = ui;
    myowner = owner;
    mynum = mnum;
    strength = 175;
    mDirection = dir;
    mSpeed = 150;
    noncollid = 256;
    oldX = x;
    oldY = y;
    final dira = direction() * math.pi / 512;
    xPosRaw = x + math.cos(dira) * 1500;
    yPosRaw = y + math.sin(dira) * 1500;
    mSize = 8;

    // Mesma ordem de criacao do C++: [0]=CPU, [1]=Steering, [2]=Scanner.
    devices = <Device>[
      RobCpu(
        mem: ramDevice,
        owner: this,
        level: 2,
        bootMemLow: bootm % 256,
        bootMemHigh: bootm ~/ 256,
        stackMemLow: stm % 256,
        stackMemHigh: stm ~/ 256,
        randomSeed: ourArea.random.nextInt(1 << 31),
        fileAccess: fileAccess,
      ),
      Steering(this, 4),
      Scanner(this, 20000, 0),
    ];
    fuelval = 300;
  }

  final TextModeBattleArea ourArea;
  final Ram ramDevice;
  int strength = 175;

  /// Era `Device *devices[3]`.
  late final List<Device> devices;

  /// Executa os devices, gasta combustivel e move.
  @override
  int execute() {
    for (final d in devices) {
      d.execute();
    }
    final dir = direction() * math.pi / 512;
    if (--fuelval <= 0) {
      return destroySelf;
    }
    return setPosition(math.cos(dir) * mSpeed, math.sin(dir) * mSpeed);
  }

  @override
  int setPosition(double dx, double dy) {
    oldX = xPosRaw.toInt();
    oldY = yPosRaw.toInt();
    xPosRaw += dx;
    yPosRaw += dy;
    if (xPosRaw < 0) return destroySelf;
    if (xPosRaw > ourArea.getAreaInfo(0)) return destroySelf;
    if (yPosRaw < 0) return destroySelf;
    if (yPosRaw > ourArea.getAreaInfo(1)) return destroySelf;
    return 0;
  }

  @override
  int objectHit(int type, int strength) => objHitDestroyed;

  @override
  int type() => ScreenObject.collidable;

  @override
  int collisionType() => 2;

  @override
  int collisionStrength() => 175;

  /// Intermediario pros devices falarem com a arena.
  @override
  int writeToBattleArea(int bot, int dev, int choice, int arg1, int arg2) {
    return ourArea.devIo(bot, dev, choice, arg1, arg2);
  }

  /// Le uma porta de device (4 portas por device; so ha 3 devices,
  /// senao devolve -1 como o original).
  @override
  int readDevicePort(int port) {
    final tempPort = port % 4;
    final tempDevice = port ~/ 4;
    if (tempDevice < 3) {
      return devices[tempDevice].readPort(tempPort);
    }
    return -1;
  }

  @override
  void writeDevicePort(int port, int value) {
    final tempPort = port % 4;
    final tempDevice = port ~/ 4;
    if (tempDevice < 3) {
      devices[tempDevice].addInputPort(tempPort, value & 0xFFFF);
    }
  }

  @override
  int returnRadar() => 4;
}
