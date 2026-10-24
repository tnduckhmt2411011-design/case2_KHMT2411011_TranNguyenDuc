import 'package:flutter/material.dart';

class PriorityBadge extends StatelessWidget {
  final String priority;

  const PriorityBadge({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (priority) {
      case 'high':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        label = 'Cao';
        break;
      case 'low':
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
        label = 'Thấp';
        break;
      case 'medium':
      default:
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        label = 'Trung bình';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.flag,
            size: 12,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
