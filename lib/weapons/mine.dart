import '../battle/text_mode_battle_area.dart';
import '../core/screen_object.dart';
import '../vm/common_symbols.dart';

// Porte de src/mine.h e src/mine.cpp (droidbattles original) -- mina
// estacionaria: fica inerte por 100 ciclos, depois explode ao
// contato; some sozinha apos ~1000 ciclos.
//
// Fica de fora (so UI, Qt): eraseObject/drawObject.
class Mine extends ScreenObject {
  Mine(int x, int y, this.ourArea, int owner, {bool ui = true}) {
    useUI = ui;
    myowner = owner;
    time1 = 0;
    xPosRaw = x.toDouble();
    yPosRaw = y.toDouble();
    mSize = 8;
    noncollid = 256;
  }

  final TextModeBattleArea ourArea;
  int time1 = 0;

  @override
  int collisionStrength() => 70;

  @override
  int collisionType() => 2;

  /// Antes de 100 ciclos a mina e "nao colidivel" (nao explode).
  @override
  int type() => time1 < 100 ? ScreenObject.nonCollidable : ScreenObject.collidable;

  @override
  int objectHit(int type, int strength) => objHitDestroyed;

  /// Vive so ~1000 ciclos.
  @override
  int execute() {
    if (time1++ > 1000) return destroySelf;
    return 0;
  }

  @override
  int returnRadar() => 3;
}
