import 'package:flutter/material.dart';

import '../../assembler/assembler.dart';
import '../../core/device.dart';
import '../app_theme.dart';

/// Bottom sheet pra escolher o device de um slot -- referência: a
/// tela de "equipar item" de jogos mobile (grade de ícones + nível
/// num slider). No original (`DevChoice`, Qt) isso era uma lista de
/// texto simples numa janela separada.
class DevicePickerSheet extends StatefulWidget {
  const DevicePickerSheet({super.key, required this.initial});

  final DeviceSlot initial;

  static Future<DeviceSlot?> show(BuildContext context, DeviceSlot initial) {
    return showModalBottomSheet<DeviceSlot>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DevicePickerSheet(initial: initial),
    );
  }

  @override
  State<DevicePickerSheet> createState() => _DevicePickerSheetState();
}

class _DevicePickerSheetState extends State<DevicePickerSheet> {
  late int _type = widget.initial.type;
  late int _level = widget.initial.level;
  late final int _arg1 = widget.initial.arg1;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Escolher device', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, const DeviceSlot()),
                    child: const Text('Esvaziar slot'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemCount: 20,
                itemBuilder: (context, i) {
                  final devType = i + 1; // Device.deviceName é 0-based; tipo do bot é 1-based
                  final selected = _type == devType;
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _type = devType),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.accent.withValues(alpha: 0.18) : AppTheme.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: selected ? AppTheme.accent : Colors.transparent, width: 1.5),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_iconFor(devType), color: selected ? AppTheme.accent : Colors.white70, size: 22),
                          const SizedBox(height: 6),
                          Text(
                            Device.deviceName(devType - 1),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_type != 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text('Nível', style: TextStyle(color: AppTheme.textDim)),
                        Expanded(
                          child: Slider(
                            value: _level.toDouble(),
                            min: 0,
                            max: 4,
                            divisions: 4,
                            label: '$_level',
                            onChanged: (v) => setState(() => _level = v.round()),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FilledButton(
                          onPressed: () => Navigator.pop(
                            context,
                            DeviceSlot(type: _type, level: _level, arg1: _arg1),
                          ),
                          child: const Text('Confirmar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  IconData _iconFor(int devType) {
    const icons = {
      1: Icons.memory,
      2: Icons.local_fire_department,
      3: Icons.explore,
      4: Icons.bolt,
      5: Icons.shield,
      6: Icons.radar,
      7: Icons.local_gas_station,
      8: Icons.grain,
      9: Icons.adjust,
      10: Icons.sensors,
      11: Icons.timer,
      12: Icons.security,
      13: Icons.build,
      14: Icons.podcasts,
      15: Icons.ac_unit,
      16: Icons.visibility_off,
      17: Icons.circle,
      18: Icons.gps_fixed,
      19: Icons.flash_on,
      20: Icons.rocket_launch,
    };
    return icons[devType] ?? Icons.extension;
  }
}
