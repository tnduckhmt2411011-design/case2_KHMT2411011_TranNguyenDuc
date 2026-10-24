import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'in_progress':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        label = 'Đang thực hiện';
        break;
      case 'completed':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = 'Đã hoàn thành';
        break;
      case 'todo':
      default:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade900;
        label = 'Chưa thực hiện';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
