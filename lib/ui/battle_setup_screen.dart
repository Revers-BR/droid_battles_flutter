import 'package:flutter/material.dart';

import '../battle/battle_config.dart';
import 'app_theme.dart';
import 'battle_screen.dart';
import 'models/bot_draft.dart';

/// Tela de "Nova Batalha" -- referência: tela de criar partida de
/// jogos mobile de estratégia/luta (escolher lutadores num grid de
/// seleção, depois opções num segmented control). Substitui os seis
/// diálogos separados do original
/// (`startsbatt`/`startdeathbatt`/`startsurvbatt`/`startcup`/
/// `starttournament`/`kothtournament`), que eram só isso: escolher
/// bots e configurar `BattleConfig`.
class BattleSetupScreen extends StatefulWidget {
  const BattleSetupScreen({super.key, required this.bots});

  final List<BotDraft> bots;

  @override
  State<BattleSetupScreen> createState() => _BattleSetupScreenState();
}

class _BattleSetupScreenState extends State<BattleSetupScreen> {
  final Set<int> _selected = {};
  int _mode = FightMode.normal;
  int _numFights = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova batalha')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Escolha de 2 a 8 bots', style: TextStyle(color: AppTheme.textDim)),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.6,
              ),
              itemCount: widget.bots.length,
              itemBuilder: (context, i) {
                final selected = _selected.contains(i);
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() {
                    if (selected) {
                      _selected.remove(i);
                    } else if (_selected.length < 8) {
                      _selected.add(i);
                    }
                  }),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.accent.withValues(alpha: 0.16) : AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: selected ? AppTheme.accent : Colors.white10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(Icons.android, color: selected ? AppTheme.accent : Colors.white38),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(widget.bots[i].name, overflow: TextOverflow.ellipsis),
                        ),
                        if (selected) const Icon(Icons.check_circle, color: AppTheme.accent, size: 18),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Modo', style: TextStyle(color: AppTheme.textDim)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: FightMode.normal, label: Text('Normal'), icon: Icon(Icons.flag)),
                ButtonSegment(value: FightMode.survival, label: Text('Survival'), icon: Icon(Icons.favorite)),
                ButtonSegment(value: FightMode.deathmatch, label: Text('Deathmatch'), icon: Icon(Icons.whatshot)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('Rounds/pontos', style: TextStyle(color: AppTheme.textDim)),
                Expanded(
                  child: Slider(
                    value: _numFights.toDouble(),
                    min: 1,
                    max: 20,
                    divisions: 19,
                    label: '$_numFights',
                    onChanged: (v) => setState(() => _numFights = v.round()),
                  ),
                ),
                SizedBox(width: 24, child: Text('$_numFights')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _selected.length < 2
                    ? null
                    : () {
                        final chosen = _selected.map((i) => widget.bots[i]).toList();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BattleScreen(
                              bots: chosen,
                              config: BattleConfig(
                                names: [for (final b in chosen) b.name],
                                mode: _mode,
                                numFights: _numFights,
                                maxPoints: _numFights,
                              ),
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.sports_esports),
                label: Text('Lutar (${_selected.length} bots)'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
