import 'package:flutter/material.dart';

import '../core/device.dart';
import 'app_theme.dart';
import 'debug_screen.dart';
import 'models/bot_draft.dart';
import 'widgets/device_picker_sheet.dart';

/// Tela de criação/edição de bot -- referência: editores de código
/// mobile (Pythonista, Dcoder) pra aba de código, e telas de
/// "equipamento" de RPG mobile pra aba de devices, com abas embaixo
/// em vez de várias janelas separadas como no `CreateBot` original.
class BotEditorScreen extends StatefulWidget {
  const BotEditorScreen({super.key, required this.draft});

  final BotDraft draft;

  @override
  State<BotEditorScreen> createState() => _BotEditorScreenState();
}

class _BotEditorScreenState extends State<BotEditorScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  late final TextEditingController _nameCtrl = TextEditingController(text: widget.draft.name);
  late final TextEditingController _codeCtrl = TextEditingController(text: widget.draft.sourceCode);
  String? _statusMessage;
  bool _statusIsError = false;

  void _assemble() {
    widget.draft.name = _nameCtrl.text.trim().isEmpty ? 'Sem nome' : _nameCtrl.text.trim();
    widget.draft.sourceCode = _codeCtrl.text;
    final ok = widget.draft.assemble();
    setState(() {
      _statusIsError = !ok;
      _statusMessage = ok
          ? 'Montado com sucesso (${widget.draft.botFileBytes!.length} bytes).'
          : widget.draft.lastError.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Nome do bot',
          ),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'CÓDIGO', icon: Icon(Icons.code)),
            Tab(text: 'DEVICES', icon: Icon(Icons.settings_input_component)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Salvar',
            icon: const Icon(Icons.check),
            onPressed: () {
              widget.draft.name = _nameCtrl.text.trim().isEmpty ? 'Sem nome' : _nameCtrl.text.trim();
              widget.draft.sourceCode = _codeCtrl.text;
              widget.draft.assemble();
              Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _CodeTab(
            controller: _codeCtrl,
            onAssemble: _assemble,
            status: _statusMessage,
            isError: _statusIsError,
            onDebug: widget.draft.isAssembled
                ? () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => DebugScreen(bot: widget.draft)),
                    )
                : null,
          ),
          _DevicesTab(draft: widget.draft, onChanged: () => setState(() {})),
        ],
      ),
    );
  }
}

class _CodeTab extends StatelessWidget {
  const _CodeTab({
    required this.controller,
    required this.onAssemble,
    this.status,
    required this.isError,
    this.onDebug,
  });

  final TextEditingController controller;
  final VoidCallback onAssemble;
  final String? status;
  final bool isError;
  final VoidCallback? onDebug;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              inputFormatters: const [],
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4),
              decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
            ),
          ),
        ),
        if (status != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isError ? AppTheme.accentDanger : AppTheme.accent).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isError ? AppTheme.accentDanger : AppTheme.accent),
            ),
            child: Text(
              status!,
              style: TextStyle(color: isError ? AppTheme.accentDanger : AppTheme.accent, fontSize: 12),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAssemble,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Montar'),
                ),
              ),
              if (onDebug != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDebug,
                    icon: const Icon(Icons.bug_report),
                    label: const Text('Depurar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DevicesTab extends StatelessWidget {
  const _DevicesTab({required this.draft, required this.onChanged});

  final BotDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('Tamanho da RAM', style: TextStyle(color: AppTheme.textDim)),
              const Spacer(),
              DropdownButton<int>(
                value: draft.ramIndex,
                dropdownColor: AppTheme.surfaceAlt,
                items: [
                  for (var i = 0; i < 9; i++) DropdownMenuItem(value: i, child: Text('Nível $i')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    draft.ramIndex = v;
                    onChanged();
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemCount: 32,
            itemBuilder: (context, i) {
              final slot = draft.devices[i];
              final empty = slot.type == 0;
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  final result = await DevicePickerSheet.show(context, slot);
                  if (result != null) {
                    draft.devices[i] = result;
                    onChanged();
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: empty ? AppTheme.surface : AppTheme.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: empty ? Colors.white10 : AppTheme.accent),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(empty ? Icons.add : Icons.check, color: empty ? Colors.white24 : AppTheme.accent),
                      const SizedBox(height: 4),
                      Text(
                        empty ? 'slot $i' : Device.deviceName(slot.type - 1),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10),
                      ),
                      if (!empty)
                        Text('nv ${slot.level}', style: const TextStyle(fontSize: 9, color: AppTheme.textDim)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
