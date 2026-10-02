import 'package:flutter/material.dart';

import '../assembler/assembler.dart';
import '../persistence/local_bot_storage.dart';
import 'app_theme.dart';
import 'battle_setup_screen.dart';
import 'bot_editor_screen.dart';
import 'models/bot_draft.dart';
import 'settings_screen.dart';

/// Tela inicial: lista de bots (cards, como uma lista de "decks" num
/// app de cartas ou "perfis" num jogo de corrida), FAB pra criar um
/// novo, e um botão pra ir pra tela de batalha. Sem equivalente 1:1
/// no C++ (lá voce abria o `CreateBot` ou o `BattleArea` direto por
/// menus de janela).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<BotDraft> _bots = [];
  LocalBotStorage? _storage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final storage = await LocalBotStorage.open();
    var bots = await storage.loadAll();
    if (bots.isEmpty) {
      // Primeira vez abrindo o app: cria um bot de exemplo pra não
      // abrir vazio, e já salva ele.
      final demo = BotDraft(
        name: 'Exemplo',
        devices: [
          for (var i = 0; i < 32; i++)
            if (i == 0)
              const DeviceSlot(type: 1, level: 2) // CPU
            else if (i == 2)
              const DeviceSlot(type: 2, level: 2) // Engine
            else if (i == 4)
              const DeviceSlot(type: 4, level: 2) // Plasma
            else if (i == 5)
              const DeviceSlot(type: 5, level: 2) // Armor
            else
              const DeviceSlot(),
        ],
        sourceCode: sampleBotSource(),
      );
      if (demo.assemble()) {
        await storage.save(demo);
      }
      bots = [demo];
    }
    if (!mounted) return;
    setState(() {
      _storage = storage;
      _bots = bots;
      _loading = false;
    });
  }

  Future<void> _createBot() async {
    final draft = BotDraft(name: 'Novo bot', sourceCode: sampleBotSource());
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BotEditorScreen(draft: draft)),
    );
    if (saved == true) {
      if (draft.isAssembled) await _storage?.save(draft);
      setState(() => _bots.add(draft));
    }
  }

  Future<void> _editBot(BotDraft bot) async {
    final previousName = bot.name;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BotEditorScreen(draft: bot)),
    );
    if (saved == true && bot.isAssembled) {
      await _storage?.save(bot, previousName: previousName);
    }
    setState(() {});
  }

  Future<void> _deleteBot(BotDraft bot) async {
    await _storage?.delete(bot.name);
    setState(() => _bots.remove(bot));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Droid Battles'),
        actions: [
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Nova batalha',
            icon: const Icon(Icons.sports_esports),
            onPressed: _bots.where((b) => b.isAssembled).length < 2
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BattleSetupScreen(
                          bots: _bots.where((b) => b.isAssembled).toList(),
                        ),
                      ),
                    ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bots.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bots.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final bot = _bots[i];
                    return Dismissible(
                      key: ValueKey(bot),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppTheme.accentDanger.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete, color: AppTheme.accentDanger),
                      ),
                      onDismissed: (_) => _deleteBot(bot),
                      child: _BotCard(bot: bot, onTap: () => _editBot(bot)),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createBot,
        icon: const Icon(Icons.add),
        label: const Text('Novo bot'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.precision_manufacturing, size: 56, color: AppTheme.textDim),
            const SizedBox(height: 12),
            Text(
              'Nenhum bot ainda.\nToque em "Novo bot" pra criar o primeiro.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textDim),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotCard extends StatelessWidget {
  const _BotCard({required this.bot, required this.onTap});

  final BotDraft bot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.surfaceAlt,
                child: const Icon(Icons.android, color: AppTheme.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bot.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '${bot.deviceCount} devices · RAM ${bot.ramIndex}',
                      style: const TextStyle(color: AppTheme.textDim, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(
                bot.isAssembled ? Icons.check_circle : Icons.error_outline,
                color: bot.isAssembled ? AppTheme.accent : AppTheme.accentWarn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
