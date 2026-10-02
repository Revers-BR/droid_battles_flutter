import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/explosion.dart';
import '../../core/robots.dart';
import '../../core/screen_object.dart';
import '../../weapons/beam.dart';
import '../../weapons/chaff.dart';
import '../../weapons/mine.dart';
import '../../weapons/missile.dart';
import '../../weapons/radar_missile.dart';
import '../../weapons/rocket.dart';
import '../app_theme.dart';
import 'sprite_cache.dart';

/// Desenha a arena usando os sprites ORIGINAIS do jogo (convertidos
/// de images/*.png/.bmp/.xpm pra PNG -- ver sprite_cache.dart), não
/// mais formas vetoriais. Precisa de `SpriteCache.instance` já
/// carregado antes de montar este painter (ver battle_screen.dart).
class ArenaPainter extends CustomPainter {
  ArenaPainter({
    required this.objects,
    required this.worldWidth,
    required this.worldHeight,
    required this.selected,
    required this.sprites,
  });

  final List<ScreenObject> objects;
  final int worldWidth;
  final int worldHeight;
  final Robots? selected;
  final SpriteCache sprites;

  Offset _toCanvas(Size size, int x, int y) {
    return Offset(x / worldWidth * size.width, y / worldHeight * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // fundo + grade
    final bg = Paint()..color = AppTheme.background;
    canvas.drawRect(Offset.zero & size, bg);
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    const cells = 12;
    for (var i = 1; i < cells; i++) {
      final dx = size.width / cells * i;
      final dy = size.height / cells * i;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), grid);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), grid);
    }

    for (final obj in objects) {
      if (obj.type() == ScreenObject.destroyed) continue;
      final center = _toCanvas(size, obj.xPos(), obj.yPos());

      if (obj is Robots) {
        _drawRobot(canvas, center, obj, obj == selected);
      } else if (obj is RadarMissile) {
        _drawSprite(canvas, center, sprites.radarMissile, obj.direction(), 14);
      } else if (obj is Missile) {
        _drawSprite(canvas, center, sprites.missile, obj.direction(), 12);
      } else if (obj is Rocket) {
        _drawSprite(canvas, center, sprites.rocket, obj.direction(), 16);
      } else if (obj is Beam) {
        _dot(canvas, center, 2, Colors.white);
      } else if (obj is Mine) {
        _drawSprite(canvas, center, sprites.mine, 0, 14);
      } else if (obj is Chaff) {
        _drawSprite(canvas, center, sprites.chaff, 0, 16, opacity: 0.6);
      } else if (obj is Explosion) {
        final alpha = (1 - obj.cycle / 32).clamp(0.0, 1.0);
        final r = obj.cycle.toDouble().clamp(1.0, 40.0);
        canvas.drawCircle(
          center,
          r,
          Paint()..color = AppTheme.accentWarn.withValues(alpha: alpha * 0.7),
        );
      }
    }
  }

  void _dot(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawCircle(c, r, Paint()..color = color);
  }

  /// Desenha uma imagem pequena (projétil/mina/chaff) centrada em
  /// `center`, rotacionada conforme `direction` (0-1023 "graus de
  /// bot"). Se o sprite ainda não carregou, cai num losango vetorial
  /// simples -- nunca deixa o frame "sumir" por falta de asset.
  void _drawSprite(Canvas canvas, Offset center, ui.Image? image, int direction, double displaySize, {double opacity = 1}) {
    if (image == null) {
      _diamond(canvas, center, displaySize / 2.2, AppTheme.accentDanger.withValues(alpha: opacity));
      return;
    }
    final angle = direction / 512 * math.pi;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromCenter(center: Offset.zero, width: displaySize, height: displaySize * image.height / image.width);
    canvas.drawImageRect(image, src, dst, Paint()..color = Colors.white.withValues(alpha: opacity)..filterQuality = FilterQuality.none);
    canvas.restore();
  }

  void _diamond(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r, c.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  /// Desenha o robô usando a folha de sprites original
  /// (`ship<slot>.png`, 16 quadros pré-rotacionados de 32x32) -- era
  /// `Robots::drawObject` no C++. O quadro é escolhido do mesmo jeito
  /// que o original: `(direction + meioQuadro) / grausPorQuadro`.
  void _drawRobot(Canvas canvas, Offset center, Robots bot, bool isSelected) {
    final image = sprites.ship(bot.number());
    const displaySize = 30.0;

    if (image == null) {
      // Sprite ainda carregando -- placeholder simples pra não
      // piscar um frame vazio.
      canvas.drawCircle(center, 8, Paint()..color = _teamColor(bot.team()));
    } else {
      const piccols = 16;
      const degreesPerPic = 1024 ~/ piccols;
      final frame = (((bot.direction() + degreesPerPic ~/ 2) ~/ degreesPerPic) % piccols);
      final frameW = image.width / piccols;
      final src = Rect.fromLTWH(frame * frameW, 0, frameW, image.height.toDouble());
      final dst = Rect.fromCenter(center: center, width: displaySize, height: displaySize * image.height / frameW);
      canvas.drawImageRect(image, src, dst, Paint()..filterQuality = FilterQuality.none);
    }

    if (isSelected) {
      canvas.drawCircle(center, 18, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    }

    // barra de armadura acima do robô
    const barW = 24.0, barH = 3.0;
    final armorRatio = (bot.armor() / math.max(1, bot.size() * 20)).clamp(0.0, 1.0);
    final barTop = center.translate(-barW / 2, -24);
    canvas.drawRect(barTop & const Size(barW, barH), Paint()..color = Colors.white24);
    canvas.drawRect(
      barTop & Size(barW * armorRatio, barH),
      Paint()..color = armorRatio > 0.3 ? AppTheme.accent : AppTheme.accentDanger,
    );
  }

  Color _teamColor(int team) {
    const colors = [AppTheme.accent, AppTheme.accentInfo, AppTheme.accentWarn, AppTheme.accentDanger];
    return colors[team % colors.length];
  }

  @override
  bool shouldRepaint(covariant ArenaPainter oldDelegate) => true;
}
