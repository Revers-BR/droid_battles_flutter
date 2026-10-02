import '../core/device.dart';

// Porte de src/confstruct.h e src/confstruct.cpp (droidbattles
// original) -- a configuracao ativa do jogo: quais devices estao
// habilitados, custo/nivel maximo de cada um, limite de RAM etc.
//
// `load`/`save` usam o MESMO formato de texto do `current.cfg`
// original (um INI do Qt `QSettings`, grupos separados por `\`).
//
// O jogo original tambem vinha com 4 presets prontos em `misc/`
// (light/medium/heavy/ultralight.cfg) -- essses usam um formato de
// texto mais antigo (`MAXDEVICES:`/`DEVICE:`, escrito por
// `textmodefilemanip.cpp`), diferente do INI que `confstruct.cpp`
// carrega de verdade. Em vez de portar os dois formatos, extraí os
// VALORES desses 4 arquivos direto (`kBuiltInPresets` abaixo) -- sao
// os mesmos 4 perfis do jogo original, prontos pra usar/duplicar.
class ConfStruct {
  ConfStruct({
    this.maxDev = 12,
    this.maxCost = 3300,
    this.maxRam = 1,
    List<int>? ramCost,
    List<bool>? enabled,
    List<List<int>>? cost,
    List<List<int>>? values,
  })  : ramCost = ramCost ?? List<int>.from(_defaultRamCost),
        enabled = enabled ?? List.filled(20, true),
        cost = cost ?? _clone(kBuiltInPresets['light']!.cost),
        values = values ?? _clone(kBuiltInPresets['light']!.values);

  static const List<int> _defaultRamCost = [100, 150, 225, 350, 500, 750, 1200, 1800, 3000];

  static List<List<int>> _clone(List<List<int>> src) => [for (final row in src) List<int>.from(row)];

  int maxDev;
  int maxCost;

  /// Indice (0-8) no maior tamanho de RAM permitido -- ver
  /// `Ram.sizeOptions` em vm/ram.dart.
  int maxRam;

  /// Custo de cada tamanho de RAM (indice 0-8).
  final List<int> ramCost;

  /// Se o device (indice 0-19, id de `Device.deviceName`) pode ser usado.
  final List<bool> enabled;

  /// `cost[nivel][deviceId]`.
  final List<List<int>> cost;

  /// `values[nivel][deviceId]` -- o "levelvalue" passado pro construtor do device.
  final List<List<int>> values;

  /// Cópia independente (editar a cópia não afeta o original) --
  /// usada ao escolher um preset como ponto de partida editável.
  ConfStruct clone() => ConfStruct(
        maxDev: maxDev,
        maxCost: maxCost,
        maxRam: maxRam,
        ramCost: List<int>.from(ramCost),
        enabled: List<bool>.from(enabled),
        cost: _clone(cost),
        values: _clone(values),
      );

  /// Era `ConfStruct::load` -- recebe o TEXTO do arquivo .cfg (ja lido
  /// do disco/assets por quem chama) e preenche esta instancia.
  /// Chaves ausentes mantem o valor default (mesmo comportamento do
  /// `QSettings::value(key, default)` do original).
  void load(String text) {
    String section = '';
    for (var rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith(';') || line.startsWith('#')) continue;
      if (line.startsWith('[') && line.endsWith(']')) {
        section = line.substring(1, line.length - 1);
        continue;
      }
      final eq = line.indexOf('=');
      if (eq < 0) continue;
      final key = line.substring(0, eq);
      final value = line.substring(eq + 1);

      switch (section) {
        case 'General':
          switch (key) {
            case 'MaxDevices':
              maxDev = int.tryParse(value) ?? maxDev;
              break;
            case 'MaxCost':
              maxCost = int.tryParse(value) ?? maxCost;
              break;
            case 'MaxRam':
              maxRam = int.tryParse(value) ?? maxRam;
              break;
          }
          break;

        case 'RamCosts':
          final i = int.tryParse(key);
          if (i != null && i >= 0 && i < ramCost.length) {
            ramCost[i] = int.tryParse(value) ?? ramCost[i];
          }
          break;

        case 'Devices':
          final parts = key.split('\\');
          if (parts.length == 2 && parts[1] == 'Enabled') {
            final dev = Device.deviceId(parts[0]);
            enabled[dev] = value.trim().toLowerCase() == 'true';
          } else if (parts.length == 3) {
            final dev = Device.deviceId(parts[0]);
            final level = int.tryParse(parts[1]);
            if (level != null && level >= 0 && level < 5) {
              if (parts[2] == 'Cost') {
                cost[level][dev] = int.tryParse(value) ?? cost[level][dev];
              } else if (parts[2] == 'Value') {
                values[level][dev] = int.tryParse(value) ?? values[level][dev];
              }
            }
          }
          break;
      }
    }
  }

  /// Era `ConfStruct::save` -- devolve o texto pronto pra gravar num
  /// arquivo `.cfg`, no mesmo formato de `load`.
  String save() {
    final buf = StringBuffer();
    buf.writeln('[General]');
    buf.writeln('MaxDevices=$maxDev');
    buf.writeln('MaxCost=$maxCost');
    buf.writeln('MaxRam=$maxRam');
    buf.writeln();

    buf.writeln('[Devices]');
    for (var dev = 0; dev < 20; dev++) {
      final name = Device.deviceName(dev);
      for (var level = 0; level < 5; level++) {
        buf.writeln('$name\\$level\\Cost=${cost[level][dev]}');
        buf.writeln('$name\\$level\\Value=${values[level][dev]}');
      }
      buf.writeln('$name\\Enabled=${enabled[dev]}');
    }
    buf.writeln();

    buf.writeln('[RamCosts]');
    for (var i = 0; i < ramCost.length; i++) {
      buf.writeln('$i=${ramCost[i]}');
    }
    return buf.toString();
  }
}

/// Os 4 presets que vinham prontos em `misc/*.cfg` no repositório
/// original (valores extraídos de lá, não inventados). `light` é
/// idêntico ao `current.cfg` que vem junto do jogo (é o preset
/// padrão). Nomes de exibição ficam por conta da tela (ver
/// settings_screen.dart).
final Map<String, ConfStruct> kBuiltInPresets = {
  'ultralight': ConfStruct(
    maxDev: 7,
    maxCost: 2000,
    maxRam: 0,
    ramCost: [100, 150, 225, 350, 500, 750, 1200, 1800, 3000],
    enabled: List.filled(20, true),
    cost: [
      [150, 100, 100, 150, 100, 100, 50, 40, 60, 100, 100, 80, 100, 100, 100, 200, 70, 150, 110, 100],
      [200, 130, 200, 300, 200, 150, 70, 50, 70, 100, 100, 160, 140, 100, 200, 350, 90, 190, 120, 140],
      [2000, 160, 250, 2000, 300, 200, 90, 60, 80, 100, 100, 240, 200, 100, 350, 550, 110, 230, 130, 180],
      [2000, 190, 300, 2000, 400, 250, 110, 70, 90, 100, 100, 320, 300, 100, 510, 800, 130, 270, 140, 220],
      [2000, 250, 350, 2000, 500, 300, 150, 80, 100, 100, 100, 400, 420, 100, 800, 1500, 150, 310, 150, 260],
    ],
    values: [
      [3, 70, 2, 3, 50, 20000, 5000, 10, 8, 0, 0, 10, 30, 0, 1, 1, 10, 300, 35, 150],
      [4, 85, 3, 4, 100, 25000, 8000, 15, 10, 0, 0, 19, 27, 0, 2, 2, 15, 275, 30, 130],
      [5, 100, 4, 5, 150, 30000, 11000, 20, 12, 0, 0, 27, 24, 0, 3, 3, 20, 250, 25, 110],
      [6, 115, 5, 6, 200, 35000, 14000, 25, 14, 0, 0, 34, 21, 0, 4, 4, 25, 225, 20, 90],
      [7, 130, 6, 7, 250, 40000, 17000, 30, 16, 0, 0, 40, 18, 0, 5, 5, 30, 200, 15, 80],
    ],
  ),
  'light': ConfStruct(
    maxDev: 12,
    maxCost: 3300,
    maxRam: 1,
    ramCost: [100, 150, 225, 350, 500, 750, 1200, 1800, 3000],
    enabled: List.filled(20, true),
    cost: [
      [150, 100, 100, 150, 100, 100, 50, 40, 60, 150, 100, 80, 100, 100, 100, 200, 90, 150, 110, 100],
      [200, 130, 200, 300, 200, 150, 70, 50, 70, 150, 100, 160, 140, 100, 200, 350, 130, 190, 120, 140],
      [250, 160, 250, 400, 300, 200, 90, 60, 80, 150, 100, 240, 200, 100, 350, 550, 170, 230, 130, 180],
      [300, 190, 300, 3500, 400, 250, 110, 70, 90, 150, 100, 320, 300, 100, 510, 800, 210, 270, 140, 220],
      [400, 250, 350, 3500, 500, 300, 150, 80, 100, 150, 100, 400, 420, 100, 800, 1500, 250, 310, 150, 260],
    ],
    values: [
      [3, 70, 2, 3, 50, 20000, 5000, 10, 8, 0, 0, 10, 30, 0, 1, 1, 10, 300, 35, 150],
      [4, 85, 3, 4, 100, 25000, 8000, 15, 10, 0, 0, 19, 27, 0, 2, 2, 15, 275, 30, 130],
      [5, 100, 4, 5, 150, 30000, 11000, 20, 12, 0, 0, 27, 24, 0, 3, 3, 20, 250, 25, 110],
      [6, 115, 5, 6, 200, 35000, 14000, 25, 14, 0, 0, 34, 21, 0, 4, 4, 25, 225, 20, 90],
      [7, 130, 6, 7, 250, 40000, 17000, 30, 16, 0, 0, 40, 18, 0, 5, 5, 30, 200, 15, 80],
    ],
  ),
  'medium': ConfStruct(
    maxDev: 21,
    maxCost: 4500,
    maxRam: 3,
    ramCost: [100, 150, 225, 350, 500, 750, 1200, 1800, 3000],
    enabled: List.filled(20, true),
    cost: [
      [150, 100, 100, 150, 100, 100, 50, 40, 180, 200, 150, 110, 100, 100, 100, 200, 90, 150, 110, 100],
      [200, 150, 200, 300, 200, 150, 70, 50, 190, 200, 150, 220, 140, 100, 200, 350, 130, 190, 120, 140],
      [250, 200, 250, 450, 300, 200, 90, 60, 200, 200, 150, 330, 200, 100, 350, 550, 170, 230, 130, 180],
      [300, 250, 300, 600, 400, 250, 110, 70, 220, 200, 150, 440, 300, 100, 510, 800, 210, 270, 140, 220],
      [4500, 300, 350, 4500, 500, 300, 150, 80, 240, 200, 150, 550, 420, 100, 800, 1500, 250, 310, 150, 260],
    ],
    values: [
      [3, 70, 2, 3, 50, 20000, 5000, 10, 8, 0, 0, 10, 30, 0, 1, 1, 10, 300, 35, 150],
      [4, 85, 3, 4, 100, 25000, 8000, 15, 10, 0, 0, 19, 27, 0, 2, 2, 15, 275, 30, 130],
      [5, 100, 4, 5, 150, 30000, 11000, 20, 12, 0, 0, 27, 24, 0, 3, 3, 20, 250, 25, 110],
      [6, 115, 5, 6, 200, 35000, 14000, 25, 14, 0, 0, 34, 21, 0, 4, 4, 25, 225, 20, 90],
      [7, 130, 6, 7, 250, 40000, 17000, 30, 16, 0, 0, 40, 18, 0, 5, 5, 30, 200, 15, 80],
    ],
  ),
  'heavy': ConfStruct(
    maxDev: 32,
    maxCost: 6000,
    maxRam: 6,
    ramCost: [100, 150, 225, 350, 500, 750, 1200, 1800, 3000],
    enabled: List.filled(20, true),
    cost: [
      [150, 100, 100, 150, 100, 100, 50, 40, 200, 250, 190, 110, 100, 180, 100, 200, 90, 150, 110, 100],
      [200, 150, 200, 300, 200, 150, 70, 50, 220, 250, 190, 220, 140, 180, 200, 350, 130, 190, 120, 140],
      [250, 200, 250, 450, 300, 200, 90, 60, 240, 250, 190, 330, 200, 180, 350, 550, 170, 230, 130, 180],
      [300, 250, 300, 600, 400, 250, 110, 70, 260, 250, 190, 440, 300, 180, 510, 800, 210, 270, 140, 220],
      [400, 300, 350, 800, 500, 300, 150, 80, 290, 250, 190, 550, 420, 180, 800, 1500, 250, 310, 150, 260],
    ],
    values: [
      [3, 70, 2, 3, 50, 20000, 5000, 10, 8, 0, 0, 10, 30, 0, 1, 1, 10, 300, 35, 150],
      [4, 85, 3, 4, 100, 25000, 8000, 15, 10, 0, 0, 19, 27, 0, 2, 2, 15, 275, 30, 130],
      [5, 100, 4, 5, 150, 30000, 11000, 20, 12, 0, 0, 27, 24, 0, 3, 3, 20, 250, 25, 110],
      [6, 115, 5, 6, 200, 35000, 14000, 25, 14, 0, 0, 34, 21, 0, 4, 4, 25, 225, 20, 90],
      [7, 130, 6, 7, 250, 40000, 17000, 30, 16, 0, 0, 40, 18, 0, 5, 5, 30, 200, 15, 80],
    ],
  ),
};
