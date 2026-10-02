import 'dart:math';
import 'dart:typed_data';

import '../battle/conf_struct.dart';
import '../battle/text_mode_battle_area.dart';
import '../persistence/bot_file_access.dart';
import '../vm/common_symbols.dart';
import '../vm/communication.dart';
import '../vm/ram.dart';
import '../vm/rob_cpu.dart';
import 'armor.dart';
import 'chiller.dart';
import 'cloaker.dart';
import 'device.dart';
import 'engine.dart';
import 'fuel.dart';
import 'repair.dart';
import 'screen_object.dart';
import '../weapons/beamer.dart';
import '../weapons/chaff_launcher.dart';
import '../weapons/mine_layer.dart';
import '../weapons/plasma.dart';
import '../weapons/radar_missile_launcher.dart';
import '../weapons/scan_detect.dart';
import '../weapons/rocket_launcher.dart';
import '../weapons/scanner.dart';
import '../weapons/turret.dart';
import 'shield.dart';
import 'steering.dart';
import 'timed_ev.dart';

// Porte de src/robots.h e src/robots.cpp (droidbattles original) -- o
// robo de verdade: le o arquivo .bot, monta a lista de ate 32
// devices, e liga tudo em cima de ScreenObject/Device.
//
// STATUS: portado por inteiro a partir de robots.cpp -- execute/
// objectHit/roteamento de portas/radio/debug/custo/erro de config e
// os 21 tipos de device (0 = generico ate 20 = RocketLauncher), todos
// instanciados de verdade.
//
// Tambem faltam (TODO, mesma categoria de pendencia de I/O de
// arquivos que ha em cpu.dart e conf_struct.dart):
// - Parse do arquivo .bot de verdade a partir de bytes brutos do
//   disco/QDataStream (aqui recebemos `botFileBytes` ja como o array
//   `my` do original -- sem o framing de QDataStream::readBytes).
// - Carregar graficos (`erasegfx`/`graphics`, tudo Qt) -- isso vai pra
//   camada de UI (lib/ui), nao pro modelo do robo.
class Robots extends ScreenObject {
  Robots(
    String name,
    this.ourArea,
    int mnum,
    ConfStruct config,
    int team, {
    bool showErrorFlag = true,
    bool ui = true,
    List<int>? botFileBytes,
    Random? random,
    void Function(String rule, String botName)? onConfigError,
    BotFileAccess? fileAccess,
  })  : showError_ = showErrorFlag,
        _fileAccess = fileAccess,
        onConfigError = onConfigError {
    useUI = ui;
    mTeam = team;
    myfile = name.length > 3 ? '${name.substring(0, name.length - 3)}dat' : name;

    xPosRaw = ourArea.getStartX(mnum).toDouble();
    yPosRaw = ourArea.getStartY(mnum).toDouble();
    final rnd = random ?? Random();
    mDirection = rnd.nextInt(1025);

    fuelval = 0;
    mynum = mnum;
    myowner = mnum;
    maxx = ourArea.getAreaInfo(0);
    maxy = ourArea.getAreaInfo(1);
    armorval = 0;
    mSpeed = 0;

    if (botFileBytes != null && botFileBytes.isNotEmpty) {
      final my = botFileBytes;
      showExtraGfx = true;

      final ramSel = my.length > 1 ? my[1] : 0;
      if (ramSel > config.maxRam) {
        _reportError('Max amount of ram', name);
      }
      if (ramSel <= 8) {
        mCost += config.ramCost[ramSel];
        ramDevice = Ram.fromBotFile(Ram.sizeOptions[ramSel], _asUint8List(my));
        // (_asUint8List apenas converte List<int> -> Uint8List)
      } else {
        _reportError('File format error', name);
        ramDevice = Ram.empty();
      }

      var numDevices = 0;
      var backx = 31;
      var forwardx = 0;
      for (var x = 0; x < 32; x++) {
        final base = x * 6 + 2;
        if (base >= my.length) {
          deviceList[x] = Device(this);
          continue;
        }
        final devType = my[base];
        final level = base + 1 < my.length ? my[base + 1] : 0;
        final args = [
          base + 2 < my.length ? my[base + 2] : 0,
          base + 3 < my.length ? my[base + 3] : 0,
          base + 4 < my.length ? my[base + 4] : 0,
          base + 5 < my.length ? my[base + 5] : 0,
        ];

        if (devType <= numDev) {
          if (devType > 0 && (devType - 1 >= config.enabled.length || !config.enabled[devType - 1])) {
            _reportError('Using disabled device ${Device.deviceName(devType - 1)}', name);
          }
          var levelValue = 0;
          if (level <= 4 && devType > 0) {
            numDevices++;
            if (level < config.cost.length && devType - 1 < config.cost[level].length) {
              mCost += config.cost[level][devType - 1];
              levelValue = config.values[level][devType - 1];
            }
          }
          if (level > 4) {
            _reportError('File format error', name);
            levelValue = 0;
          }

          switch (devType) {
            case 0:
              deviceList[x] = Device(this);
              break;
            case 1: // CPU
              deviceList[x] = RobCpu(
                mem: ramDevice,
                owner: this,
                level: levelValue,
                bootMemLow: args[0],
                bootMemHigh: args[1],
                stackMemLow: args[2],
                stackMemHigh: args[3],
                randomSeed: random == null ? null : rnd.nextInt(1 << 31),
                fileAccess: _fileAccess,
              );
              break;
            case 2: // Engine
              deviceList[x] = Engine(this, levelValue);
              break;
            case 3: // Steering
              deviceList[x] = Steering(this, levelValue);
              break;
            case 4: // Plasma
              deviceList[x] = Plasma(this, levelValue, args[0]);
              break;
            case 6: // Scanner
              deviceList[x] = Scanner(this, levelValue, args[0]);
              break;
            case 8: // ChaffLauncher
              deviceList[x] = ChaffLauncher(this, levelValue);
              break;
            case 17: // MineLayer
              deviceList[x] = MineLayer(this, levelValue);
              break;
            case 19: // Beamer
              deviceList[x] = Beamer(this, levelValue);
              break;
            case 20: // RocketLauncher
              deviceList[x] = RocketLauncher(this, levelValue, args[0]);
              break;
            case 9: // Turret
              deviceList[x] = Turret(this, levelValue, args[0]);
              break;
            case 5: // Armor
              deviceList[x] = Armor(this, levelValue);
              hitAbsorbOrder[backx] = x;
              backx--;
              break;
            case 7: // Fuel
              deviceList[x] = Fuel(this, levelValue);
              break;
            case 12: // Shield
              deviceList[x] = Shield(this, levelValue);
              hitAbsorbOrder[forwardx] = x;
              forwardx++;
              break;
            case 10: // ScanDetect
              deviceList[x] = ScanDetect(this);
              break;
            case 11: // TimeDev
              deviceList[x] = TimeDev(this);
              break;
            case 13: // Repair
              deviceList[x] = Repair(this, levelValue);
              break;
            case 14: // Communication (radio)
              deviceList[x] = Communication(this);
              ourRadioDev = x;
              break;
            case 15: // Chiller
              deviceList[x] = Chiller(this, levelValue);
              break;
            case 16: // Cloaker
              deviceList[x] = Cloaker(this, levelValue);
              break;
            case 18: // RadarMissileLauncher
              deviceList[x] = RadarMissileLauncher(this, levelValue, ramDevice, args[0]);
              break;
            default:
              deviceList[x] = Device(this);
              break;
          }
        } else {
          _reportError('File format error', name);
          deviceList[x] = Device(this);
        }
      }

      if (numDevices > config.maxDev) {
        _reportError('Max number of devices ($numDevices/${config.maxDev})', name);
      }
      if (mCost > config.maxCost) {
        _reportError('Max cost of bot', name);
      }
    } else {
      _reportError("Couldn't open bot file $name!", name);
      ramDevice = Ram.empty();
      for (var x = 0; x < 32; x++) {
        deviceList[x] = Device(this);
      }
    }

    mSize = 16;
    setHeat(0);
  }

  /// Era `TextmodeBattleArea *ourarea`.
  final TextModeBattleArea ourArea;

  /// Era `Ram *ramdevice`.
  late Ram ramDevice;

  /// Era `Device *devicelist[32]`.
  final List<Device> deviceList = List<Device>.filled(32, Device(), growable: false);

  /// Era `int8_t hitabsorborder[32]` -- ordem em que os devices
  /// absorvem dano (armaduras do fim pro comeco, escudos do comeco pro
  /// fim -- exatamente como o original monta em `backx`/`forwardx`).
  final List<int> hitAbsorbOrder = List<int>.filled(32, 0);

  int mCost = 0;
  int ourRadioDev = 0;
  int currentRadar = 5;
  final bool showError_;

  /// Repassado pra CPU de verdade (RobCpu) -- ver vm/cpu.dart e
  /// persistence/bot_file_access.dart.
  final BotFileAccess? _fileAccess;

  /// Substitui o `QMessageBox::information` do original -- chamado
  /// quando o bot infringe uma regra do arquivo de config, se
  /// `showErrorFlag` e `ui` (useUI) estiverem ligados.
  final void Function(String rule, String botName)? onConfigError;

  void _reportError(String rule, String name) {
    if (showError_ && useUI) {
      onConfigError?.call(rule, name);
    }
  }

  static Uint8List _asUint8List(List<int> raw) => Uint8List.fromList(raw);

  /// Era `Robots::execute()` -- executa todos os devices, atualiza
  /// posicao, aquecimento e checa morte por superaquecimento.
  @override
  int execute() {
    currentRadar = 5;
    for (final d in deviceList) {
      d.execute();
    }
    final dir = direction() * toRadians;
    setPosition(cos(dir) * speed(), sin(dir) * speed());

    upcount++;
    if (upcount > 10) {
      upcount = 0;
      if (useUI) {
        onFuelChanged?.call(fuelval, heat());
      }
    }
    changeHeat(-7);

    if (heat() > 500 && heat() <= 600) objectHit(9, 1);
    if (heat() > 600 && heat() <= 700) objectHit(9, 2);
    if (heat() > 700 && heat() <= 800) objectHit(9, 5);
    if (heat() > 800) objectHit(9, 999);

    if (armorval <= 0) return destroySelf;
    return 0;
  }

  /// Era `Robots::readDevicePort`.
  @override
  int readDevicePort(int port) {
    final tempPort = port % portsPerDev;
    final tempDevice = port ~/ portsPerDev;
    if (tempDevice < 0 || tempDevice >= 32) return 0;
    return deviceList[tempDevice].readPort(tempPort);
  }

  /// Era `Robots::writeDevicePort`.
  @override
  void writeDevicePort(int port, int value) {
    final tempPort = port % portsPerDev;
    final tempDevice = port ~/ portsPerDev;
    if (tempDevice < 0 || tempDevice >= 32) return;
    deviceList[tempDevice].addInputPort(tempPort, value);
  }

  /// Era `Robots::addScreenObject`.
  @override
  void addScreenObject(int x, int y, int dir, int type, [int arg1 = 0, int arg2 = 0, Object? arg3]) {
    ourArea.addScreenObject(mynum, x, y, dir, type, arg1, arg2, arg3);
  }

  @override
  int type() => ScreenObject.botObject;

  /// Era `Robots::writetoBattleArea`.
  @override
  int writeToBattleArea(int bot, int dev, int choice, int arg1, int arg2) {
    return ourArea.devIo(bot, dev, choice, arg1, arg2);
  }

  /// Era `Robots::writeToDevice`.
  @override
  int writeToDevice(int dev, int action, int value) {
    if (dev < 0 || dev >= 32) return 0;
    switch (action) {
      case 1:
        deviceList[dev].setRelativeAngle(value);
        break;
      case 2:
        return deviceList[dev].type();
      case 3:
        return deviceList[dev].specialValue();
      case 4:
        deviceList[dev].doSpecial(value);
        onArmorChanged?.call(armorval);
        break;
    }
    return 0;
  }

  @override
  int collisionType() => 1;

  @override
  int collisionStrength() => mSpeed ~/ 5;

  /// Era `Robots::objectHit` -- armadura/escudo absorvem dano na
  /// ordem de `hitAbsorbOrder`; o que sobrar destroi o robo.
  @override
  int objectHit(int hitType, int strength) {
    var strengthLeft = strength;
    final ifInt = hitType == 9 ? 1 : 0;
    for (var x = 0; x < 32; x++) {
      final xy = hitAbsorbOrder[x];
      strengthLeft = deviceList[xy].absorbHit(strengthLeft, ifInt);
      if (strengthLeft <= 0) break;
    }
    if (useUI) {
      onArmorChanged?.call(armorval);
    }
    return strengthLeft > 0 ? objHitDestroyed : objHitNotDestroyed;
  }

  @override
  int size() => mSize;

  @override
  void setDebugVariable1(int msg) => debug1 = 'Angle is: $msg';

  @override
  void setDebugVariable2(int msg) => debug2 = 'Distance is: $msg';

  /// Era `Robots::writeRadio`.
  @override
  void writeRadio(int sig) {
    if (ourRadioDev >= 0 && ourRadioDev < 32) {
      deviceList[ourRadioDev].doSpecial(sig, 0);
    }
  }

  /// Era `Robots::memorySize`.
  @override
  int memorySize() => ramDevice.returnSize();

  /// Era `Robots::addInterrupt` -- entrega interrupcao pra primeira
  /// CPU com interrupcoes habilitadas.
  @override
  void addInterrupt(int inter) {
    if (inter > 255) return;
    for (final d in deviceList) {
      if (d.type() == cpuType && d.specialValue() == cpuWithInt) {
        d.addInputPort(0, inter);
        break;
      }
    }
  }

  /// Era `Robots::cpuCount`.
  int cpuCount() => deviceList.where((d) => d.type() == cpuType).length;

  /// Acha a primeira CPU do bot -- era a lógica de
  /// `BattleArea`/`DebugWindow` pra decidir qual CPU depurar (sempre
  /// "a primeira"). Não existe no C++ como método nomeado à parte,
  /// mas é a mesma busca que `addInterrupt` faz. Ajuda a tela de
  /// depuração mobile (ver ui/debug_screen.dart).
  RobCpu? firstCpu() {
    for (final d in deviceList) {
      if (d is RobCpu) return d;
    }
    return null;
  }

  @override
  int returnRadar() => currentRadar;

  /// Era `Robots::objectScanned` -- repassa pro primeiro ScanDetect
  /// (device tipo 11 = `scanwarner`, indice 10 na tabela 0-based —
  /// ver `Device.deviceName`).
  @override
  void objectScanned(int intensity, int dir) {
    for (final d in deviceList) {
      if (d.type() == scanWarnType) {
        d.doSpecial(intensity, dir);
        break;
      }
    }
  }

  @override
  void setRadar(int x) => currentRadar = x;

  int cost() => mCost;
}
