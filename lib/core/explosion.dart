import '../battle/text_mode_battle_area.dart';
import '../vm/common_symbols.dart';
import 'screen_object.dart';

// Porte de src/explosion.h e src/explosion.cpp (droidbattles
// original) -- o circulo amarelo que marca uma colisao/explosao na
// arena. E puramente visual e nao colidivel, mas OCUPA um slot de
// `objects` por 32 ciclos (a BattleArea interativa o cria nos slots
// 254..129; a arena headless nunca cria explosoes).
//
// Fica de fora (so UI, Qt): eraseObject/drawObject. Pra desenhar na
// UI mobile use o original como referencia: circulo amarelo com
// alfa `4 * (32 - cycle)`, diametro `cycle` e centro em
// (`screenX`, `screenY`), com o raio crescendo ate `cycle`.
class Explosion extends ScreenObject {
  Explosion(int x, int y, this.ourArea) {
    maxx = ourArea.getAreaInfo(0);
    maxy = ourArea.getAreaInfo(1);
    // O original guarda a posicao JA em coordenadas de tela (>> 6).
    xPosRaw = (x >> 6).toDouble();
    yPosRaw = (y >> 6).toDouble();
    cycle = 1;
  }

  final TextModeBattleArea ourArea;

  /// Ciclo atual (1..32); a UI usa pra tamanho e transparencia.
  int cycle = 1;

  int get screenX => xPosRaw.toInt();
  int get screenY => yPosRaw.toInt();

  /// Vive 32 ciclos.
  @override
  int execute() {
    if (++cycle > 32) {
      return destroySelf;
    }
    return 0;
  }

  @override
  int type() => ScreenObject.nonCollidable;
}
