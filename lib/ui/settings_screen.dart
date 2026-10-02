import 'package:flutter/material.dart';

import '../battle/conf_struct.dart';
import '../core/device.dart';
import '../persistence/local_bot_storage.dart';
import 'app_theme.dart';

/// Tela de configurações -- agora com **perfis**: os 4 presets que o
/// jogo original trazia prontos (`misc/light.cfg`,
/// `medium.cfg`, `heavy.cfg`, `ultralight.cfg`) aparecem pra
/// escolher, e dá pra editar qualquer um (vira uma cópia própria,
/// salva com nome novo) ou criar do zero. Cada device abre numa
/// `ExpansionTile` com o custo/valor dos 5 níveis editáveis --
/// exatamente os campos que existem no `current.cfg` original.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  LocalBotStorage? _storage;
  List<String> _profiles = [];
  String _activeName = 'light';
  ConfStruct? _config;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final storage = await LocalBotStorage.open();
    final profiles = await storage.listConfigProfiles();
    final active = await storage.activeConfigProfileName();
    final config = await storage.loadConfigProfile(active);
    if (!mounted) return;
    setState(() {
      _storage = storage;
      _profiles = profiles;
      _activeName = active;
      _config = config;
      _dirty = false;
    });
  }

  Future<void> _switchProfile(String name) async {
    final storage = _storage;
    if (storage == null) return;
    final config = await storage.loadConfigProfile(name);
    await storage.setActiveConfigProfileName(name);
    if (!mounted) return;
    setState(() {
      _activeName = name;
      _config = config;
      _dirty = false;
    });
  }

  bool get _isBuiltIn => kBuiltInPresets.containsKey(_activeName);

  Future<void> _persist() async {
    final storage = _storage;
    final config = _config;
    if (storage == null || config == null) return;
    // Editar um preset embutido não sobrescreve o original -- salva
    // como um perfil novo ("Light (editado)") pra não perder o
    // preset de fábrica.
    final targetName = _isBuiltIn ? await _promptCopyName() : _activeName;
    if (targetName == null) return;
    await storage.saveConfigProfile(targetName, config);
    await storage.setActiveConfigProfileName(targetName);
    final profiles = await storage.listConfigProfiles();
    if (!mounted) return;
    setState(() {
      _activeName = targetName;
      _profiles = profiles;
      _dirty = false;
    });
  }

  Future<String?> _promptCopyName() async {
    final ctrl = TextEditingController(text: '$_activeName-personalizado');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Salvar como'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nome do perfil')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim().isEmpty ? null : ctrl.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _createBlank() async {
    final storage = _storage;
    if (storage == null) return;
    final name = await _promptNewName();
    if (name == null) return;
    final config = ConfStruct();
    await storage.saveConfigProfile(name, config);
    await storage.setActiveConfigProfileName(name);
    final profiles = await storage.listConfigProfiles();
    if (!mounted) return;
    setState(() {
      _activeName = name;
      _config = config;
      _profiles = profiles;
      _dirty = false;
    });
  }

  Future<String?> _promptNewName() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Novo perfil'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nome')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim().isEmpty ? null : ctrl.text.trim()),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCurrent() async {
    final storage = _storage;
    if (storage == null || _isBuiltIn) return;
    await storage.deleteConfigProfile(_activeName);
    await _switchProfile('light');
    final profiles = await storage.listConfigProfiles();
    if (mounted) setState(() => _profiles = profiles);
  }

  void _touch(VoidCallback change) {
    setState(() {
      change();
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    if (config == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        actions: [
          if (!_isBuiltIn)
            IconButton(
              tooltip: 'Apagar perfil',
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteCurrent,
            ),
          IconButton(
            tooltip: 'Novo perfil em branco',
            icon: const Icon(Icons.add),
            onPressed: _createBlank,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle('Perfil'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in _profiles)
                ChoiceChip(
                  label: Text(_displayName(name)),
                  selected: name == _activeName,
                  onSelected: (_) => _switchProfile(name),
                ),
            ],
          ),
          if (_isBuiltIn)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Este é um preset de fábrica — editar salva uma cópia com nome novo.',
                style: TextStyle(color: AppTheme.textDim, fontSize: 12),
              ),
            ),
          const SizedBox(height: 20),
          _SectionTitle('Limites gerais'),
          _NumberSetting(
            label: 'Custo máximo do bot',
            value: config.maxCost,
            onChanged: (v) => _touch(() => config.maxCost = v),
          ),
          _NumberSetting(
            label: 'Nº máximo de devices',
            value: config.maxDev,
            max: 32,
            onChanged: (v) => _touch(() => config.maxDev = v),
          ),
          _NumberSetting(
            label: 'Nível máximo de RAM',
            value: config.maxRam,
            max: 8,
            onChanged: (v) => _touch(() => config.maxRam = v),
          ),
          const SizedBox(height: 20),
          _SectionTitle('Devices — habilitar e ajustar custo/valor por nível'),
          for (var i = 0; i < 20; i++) _DeviceConfigTile(config: config, deviceIndex: i, onChanged: _touch),
          const SizedBox(height: 90),
        ],
      ),
      bottomNavigationBar: _dirty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _persist,
                    icon: const Icon(Icons.save),
                    label: Text(_isBuiltIn ? 'Salvar como novo perfil' : 'Salvar alterações'),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  String _displayName(String name) {
    const labels = {
      'ultralight': 'Ultralight',
      'light': 'Light',
      'medium': 'Medium',
      'heavy': 'Heavy',
    };
    return labels[name] ?? name;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: const TextStyle(color: AppTheme.textDim, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _NumberSetting extends StatelessWidget {
  const _NumberSetting({required this.label, required this.value, required this.onChanged, this.max = 20000});

  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: value <= 0 ? null : () => onChanged(value - (max > 100 ? 50 : 1)),
            ),
            SizedBox(width: 48, child: Text('$value', textAlign: TextAlign.center)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: value >= max ? null : () => onChanged(value + (max > 100 ? 50 : 1)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Um device: switch de habilitado + uma linha por nível (0-4) com
/// custo e valor editáveis -- os mesmos campos de
/// `<device>\<nível>\Cost` / `Value` do `current.cfg` original.
class _DeviceConfigTile extends StatelessWidget {
  const _DeviceConfigTile({required this.config, required this.deviceIndex, required this.onChanged});

  final ConfStruct config;
  final int deviceIndex;
  final void Function(VoidCallback change) onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(Device.deviceName(deviceIndex)),
        leading: Switch(
          value: config.enabled[deviceIndex],
          activeThumbColor: AppTheme.accent,
          onChanged: (v) => onChanged(() => config.enabled[deviceIndex] = v),
        ),
        children: [
          for (var level = 0; level < 5; level++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 56, child: Text('Nv $level', style: const TextStyle(color: AppTheme.textDim))),
                  Expanded(
                    child: _InlineNumberField(
                      label: 'Custo',
                      value: config.cost[level][deviceIndex],
                      onChanged: (v) => onChanged(() => config.cost[level][deviceIndex] = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _InlineNumberField(
                      label: 'Valor',
                      value: config.values[level][deviceIndex],
                      onChanged: (v) => onChanged(() => config.values[level][deviceIndex] = v),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InlineNumberField extends StatelessWidget {
  const _InlineNumberField({required this.label, required this.value, required this.onChanged});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey('$label-$value'),
      initialValue: '$value',
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      onFieldSubmitted: (text) => onChanged(int.tryParse(text) ?? value),
      onEditingComplete: () {},
    );
  }
}
