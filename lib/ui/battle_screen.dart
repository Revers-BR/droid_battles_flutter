
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../battle/battle_area.dart';
import '../battle/battle_config.dart';
import '../battle/default_factories.dart';
import '../core/bot_info.dart';
import '../core/robots.dart';
import '../persistence/file_bot_file_access.dart';
import '../persistence/local_bot_storage.dart';
import 'app_theme.dart';
import 'models/bot_draft.dart';
import 'widgets/arena_painter.dart';
import 'widgets/sprite_cache.dart';
import 'widgets/stat_bar.dart';

/// Tela de batalha -- referência: HUD de jogos mobile de ação (mapa
/// em tela cheia + cartões de status dos "personagens" deslizando
/// embaixo/ao lado + barra de controles no rodapé com play/pause e
/// velocidade). Substitui a `QDialog` do `BattleArea` original: aqui
/// quem "bate o relógio" da simulação é um `Ticker` do Flutter
/// chamando `execRound()`, não mais um `QTimer`.
class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key, required this.bots, required this.config});

  final List<BotDraft> bots;
  final BattleConfig config;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> with SingleTickerProviderStateMixin {
  BattleArea? _area;
  Ticker? _ticker;
  final Map<int, BotInfo> _botInfos = {};
  final Map<int, Object> _trackedObjects = {};
  Robots? _selected;
  bool _running = true;
  int _speed = 1; // 1x ou 4x ("modo rápido" do original)
  String? _resultMessage;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    await SpriteCache.instance.ensureLoaded();

    // Liga READFILE/WRITEFILE (instruções 0x93/0x94) nos arquivos
    // ".dat" de cada bot, guardados na mesma pasta da biblioteca de
    // bots -- ver persistence/local_bot_storage.dart e
    // vm/cpu.dart (readFile/writeFile).
    final storage = await LocalBotStorage.open();
    final fileAccess = FileBotFileAccess(storage.directory);
    final activeProfile = await storage.activeConfigProfileName();
    final config = await storage.loadConfigProfile(activeProfile);

    final area = BattleArea(widget.config);
    final botFiles = {for (final b in widget.bots) b.name: b.botFileBytes!};
    installDefaultFactories(area, botFiles: botFiles, ui: true, fileAccess: fileAccess, config: config);

    if (!mounted) return;
    setState(() {
      _area = area;
      _refreshBotInfos();
      _ticker = createTicker(_onTick)..start();
    });
  }

  void _refreshBotInfos() {
    final area = _area;
    if (area == null) return;
    for (var i = 0; i < 8; i++) {
      final obj = area.objects[i];
      if (obj is Robots && !identical(_trackedObjects[i], obj)) {
        _trackedObjects[i] = obj;
        _botInfos[i] = BotInfo(widget.config.names.length > i ? widget.config.names[i] : 'Bot $i', obj);
      }
    }
  }

  Duration _accum = Duration.zero;
  void _onTick(Duration elapsed) {
    final area = _area;
    if (area == null || !_running || _resultMessage != null) return;
    // ~50 rounds/s no original; multiplicamos por `_speed` (modo rápido).
    _accum += const Duration(milliseconds: 16);
    final stepMs = (1000 / 50 / _speed).round().clamp(1, 1000);
    var steps = 0;
    while (_accum.inMilliseconds >= stepMs && steps < 200) {
      final result = area.execRound();
      _accum -= Duration(milliseconds: stepMs);
      steps++;
      if (result == 3) {
        _resultMessage = area.lastResultMessage ?? 'Fim de batalha';
        break;
      }
    }
    _refreshBotInfos();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final area = _area;
    if (area == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: GestureDetector(
                onTapUp: (details) {
                  // Seleciona o robô mais próximo do toque (achado por
                  // proximidade em coordenadas de tela).
                  Robots? closest;
                  var bestDist = double.infinity;
                  final box = context.findRenderObject() as RenderBox?;
                  final size = box?.size ?? const Size(1, 1);
                  for (final entry in _botInfos.entries) {
                    final obj = _trackedObjects[entry.key];
                    if (obj is! Robots) continue;
                    final dx = obj.xPos() / area.xSize * size.width - details.localPosition.dx;
                    final dy = obj.yPos() / area.ySize * size.height - details.localPosition.dy;
                    final d = dx * dx + dy * dy;
                    if (d < bestDist) {
                      bestDist = d;
                      closest = obj;
                    }
                  }
                  setState(() => _selected = closest);
                },
                child: CustomPaint(
                  painter: ArenaPainter(
                    objects: area.objects,
                    worldWidth: area.xSize,
                    worldHeight: area.ySize,
                    selected: _selected,
                    sprites: SpriteCache.instance,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _TopBar(onExit: () => Navigator.of(context).maybePop()),
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: _BotList(botInfos: _botInfos, selected: _selected),
                    ),
                  ),
                ),
                _BottomControls(
                  running: _running,
                  speed: _speed,
                  onPlayPause: () => setState(() => _running = !_running),
                  onSpeed: () => setState(() => _speed = _speed == 1 ? 4 : 1),
                ),
              ],
            ),
          ),
          if (_resultMessage != null)
            _ResultOverlay(
              message: _resultMessage!,
              onClose: () => Navigator.of(context).maybePop(),
            ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onExit});
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.close), onPressed: onExit),
          const Spacer(),
        ],
      ),
    );
  }
}

class _BotList extends StatelessWidget {
  const _BotList({required this.botInfos, required this.selected});
  final Map<int, BotInfo> botInfos;
  final Object? selected;

  @override
  Widget build(BuildContext context) {
    final entries = botInfos.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 210),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in entries) _BotCardMini(info: e.value),
        ],
      ),
    );
  }
}

class _BotCardMini extends StatelessWidget {
  const _BotCardMini({required this.info});
  final BotInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: info.isValid ? Colors.white10 : AppTheme.accentDanger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.displayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: info.isValid ? Colors.white : AppTheme.textDim,
              decoration: info.isValid ? null : TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(height: 4),
          StatBar(label: 'ARM', value: info.currentArmor, max: info.maxArmor, color: AppTheme.accent, icon: Icons.shield),
          const SizedBox(height: 2),
          StatBar(label: 'FUEL', value: info.currentFuel, max: info.maxFuel, color: AppTheme.accentInfo, icon: Icons.local_gas_station),
          const SizedBox(height: 2),
          StatBar(label: 'HEAT', value: info.currentHeat, max: 900, color: AppTheme.accentWarn, icon: Icons.local_fire_department),
        ],
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.running,
    required this.speed,
    required this.onPlayPause,
    required this.onSpeed,
  });

  final bool running;
  final int speed;
  final VoidCallback onPlayPause;
  final VoidCallback onSpeed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(running ? Icons.pause_circle : Icons.play_circle, size: 34, color: AppTheme.accent),
            onPressed: onPlayPause,
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onSpeed,
            child: Text('${speed}x'),
          ),
        ],
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({required this.message, required this.onClose});
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(18)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, color: AppTheme.accentWarn, size: 40),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(onPressed: onClose, child: const Text('Fechar')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
