import 'package:flutter/material.dart';

import '../battle/battle_config.dart';
import '../battle/default_factories.dart';
import '../battle/text_mode_battle_area.dart';
import '../core/robots.dart';
import '../persistence/file_bot_file_access.dart';
import '../persistence/local_bot_storage.dart';
import '../vm/debug_contents.dart';
import 'app_theme.dart';
import 'models/bot_draft.dart';

/// Depurador passo-a-passo -- referência: debugger embutido de apps
/// tipo Pythonista/repl.it (registradores num painel fixo, código com
/// a linha atual destacada, botão "Step" grande no rodapé). No C++
/// original era uma `QDialog` separada (`DebugWindow`) com uma tabela
/// de labels pros registradores; aqui é uma tela cheia.
///
/// Roda o bot SOZINHO (sem oponentes) numa arena headless, só pra
/// poder avançar `RobCpu.singleStepMode` instrução por instrução --
/// mesma ideia do "quick battle" de depuração do original.
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key, required this.bot});

  final BotDraft bot;

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  TextModeBattleArea? _area;
  Robots? _robot;
  DebugContents? _debug;
  int? _currentLine;
  bool _dead = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    final storage = await LocalBotStorage.open();
    final fileAccess = FileBotFileAccess(storage.directory);

    final area = TextModeBattleArea(
      BattleConfig(names: [widget.bot.name], maxRounds: 1 << 30),
    );
    installDefaultFactories(
      area,
      botFiles: {widget.bot.name: widget.bot.botFileBytes!},
      ui: false,
      fileAccess: fileAccess,
    );
    final robot = area.objects[0];
    if (robot is! Robots) return;
    robot.firstCpu()?.singleStepMode = true;

    if (!mounted) return;
    setState(() {
      _area = area;
      _robot = robot;
      _refresh();
    });
  }

  void _refresh() {
    final robot = _robot;
    if (robot == null) return;
    final cpu = robot.firstCpu();
    _debug = cpu?.debugContents();
    _currentLine = _debug == null ? null : widget.bot.lineForAddress(_debug!.ip);
    _dead = robot.armor() <= 0;
  }

  void _step() {
    _area?.execRound();
    setState(_refresh);
  }

  void _reset() {
    setState(() {
      _area = null;
      _robot = null;
      _debug = null;
    });
    _setup();
  }

  @override
  Widget build(BuildContext context) {
    final debug = _debug;
    return Scaffold(
      appBar: AppBar(title: Text('Depurar: ${widget.bot.name}')),
      body: debug == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_dead)
                  Container(
                    width: double.infinity,
                    color: AppTheme.accentDanger.withValues(alpha: 0.15),
                    padding: const EdgeInsets.all(10),
                    child: const Text('O bot foi destruído.', style: TextStyle(color: AppTheme.accentDanger)),
                  ),
                Expanded(
                  flex: 3,
                  child: _SourceView(source: widget.bot.sourceCode, currentLine: _currentLine),
                ),
                Expanded(
                  flex: 2,
                  child: _RegistersView(debug: debug),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.replay),
                  label: const Text('Reiniciar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _dead ? null : _step,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Step'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceView extends StatelessWidget {
  const _SourceView({required this.source, required this.currentLine});

  final String source;
  final int? currentLine;

  @override
  Widget build(BuildContext context) {
    final lines = source.split('\n');
    return Container(
      color: AppTheme.surfaceAlt,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: lines.length,
        itemBuilder: (context, i) {
          final isCurrent = i == currentLine;
          return Container(
            color: isCurrent ? AppTheme.accent.withValues(alpha: 0.18) : null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text('${i + 1}', style: const TextStyle(color: AppTheme.textDim, fontSize: 11)),
                ),
                if (isCurrent) const Icon(Icons.play_arrow, size: 12, color: AppTheme.accent),
                Expanded(
                  child: Text(
                    lines[i],
                    style: TextStyle(
                      fontSize: 12,
                      color: isCurrent ? AppTheme.accent : Colors.white70,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RegistersView extends StatelessWidget {
  const _RegistersView({required this.debug});

  final DebugContents debug;

  String _hex(int v) => '0x${v.toRadixString(16).padLeft(4, '0')}';
  String _bytes(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join(' ');

  @override
  Widget build(BuildContext context) {
    final regs = {
      'AX': debug.ax, 'BX': debug.bx, 'CX': debug.cx, 'DX': debug.dx,
      'SP': debug.sp, 'BP': debug.bp, 'SI': debug.si, 'DI': debug.di,
      'IP': debug.ip, 'FLAGS': debug.flags,
    };
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final e in regs.entries)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppTheme.surfaceAlt, borderRadius: BorderRadius.circular(8)),
                  child: Text('${e.key} ${_hex(e.value)}', style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('memória perto de IP: ${_bytes(debug.ipContents)}', style: const TextStyle(fontSize: 11, color: AppTheme.textDim)),
          Text('memória perto de SP: ${_bytes(debug.spContents)}', style: const TextStyle(fontSize: 11, color: AppTheme.textDim)),
          Text('memória perto de SI: ${_bytes(debug.siContents)}', style: const TextStyle(fontSize: 11, color: AppTheme.textDim)),
          Text('memória perto de DI: ${_bytes(debug.diContents)}', style: const TextStyle(fontSize: 11, color: AppTheme.textDim)),
        ],
      ),
    );
  }
}
