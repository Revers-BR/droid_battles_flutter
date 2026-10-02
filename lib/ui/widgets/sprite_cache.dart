import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

// Carrega os sprites originais do jogo (convertidos de
// images/*.png/*.bmp/*.xpm do repositório C++ para PNG com fundo
// transparente -- ver assets/images/). `ArenaPainter` precisa de
// `dart:ui.Image` já decodificadas (CustomPainter.paint é síncrono),
// entao isso carrega tudo UMA vez e guarda em cache; quem for montar
// a tela de batalha deve chamar `SpriteCache.instance.ensureLoaded()`
// e esperar antes de criar o `ArenaPainter`.
class SpriteCache {
  SpriteCache._();
  static final SpriteCache instance = SpriteCache._();

  final Map<String, ui.Image> _images = {};
  Future<void>? _loading;

  /// Os 8 skins de nave (um por slot/posição do bot, 0-7) -- era
  /// `":/images/ship" + mynum + ".png"` no `Robots::Robots` original.
  /// Cada arquivo é uma folha de 16 quadros de 32x32 (um por ângulo
  /// pré-rotacionado).
  ui.Image? ship(int slot) => _images['ship${slot % 8}'];

  ui.Image? get missile => _images['missile'];
  ui.Image? get mine => _images['mine'];
  ui.Image? get rocket => _images['rocket'];
  ui.Image? get chaff => _images['chaff'];
  ui.Image? get radarMissile => _images['radarmissile'];

  bool get isLoaded => _images.length >= 13;

  Future<void> ensureLoaded() {
    return _loading ??= _loadAll();
  }

  Future<void> _loadAll() async {
    const names = [
      'ship0', 'ship1', 'ship2', 'ship3', 'ship4', 'ship5', 'ship6', 'ship7',
      'missile', 'mine', 'rocket', 'chaff', 'radarmissile',
    ];
    for (final name in names) {
      final data = await rootBundle.load('assets/images/$name.png');
      final image = await _decode(data.buffer.asUint8List());
      _images[name] = image;
    }
  }

  Future<ui.Image> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
