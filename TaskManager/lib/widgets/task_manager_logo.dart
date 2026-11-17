import 'package:flutter/material.dart';

/// Displays the Task Manager logo image with rounded corners and an icon fallback.
class TaskManagerLogo extends StatelessWidget {
  final String assetPath;
  final double size;

  const TaskManagerLogo({
    super.key,
    this.assetPath = 'assets/images/logo.png',
    this.size = 96.0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.task_alt,
              size: size * 0.55,
              color: Colors.blue,
            ),
          );
        },
      ),
    );
  }
}
