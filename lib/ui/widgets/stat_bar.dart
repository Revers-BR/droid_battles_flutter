import 'package:flutter/material.dart';

/// Barra de status estilo HUD de jogo mobile (vida/mana/etc.) --
/// usada pra armadura, combustível e calor. Sem equivalente no C++
/// (lá era um `QProgressBar` cinza padrão do Qt).
class StatBar extends StatelessWidget {
  const StatBar({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    this.icon,
  });

  final String label;
  final int value;
  final int max;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
        ],
        SizedBox(
          width: 46,
          child: Text(label, style: TextStyle(fontSize: 11, color: color)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}
