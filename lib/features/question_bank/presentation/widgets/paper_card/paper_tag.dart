import 'package:flutter/material.dart';
import '../../../../../core/presentation/constants/ui_constants.dart';

/// A small colored tag/chip used to display paper metadata like subject or exam type
class PaperTag extends StatelessWidget {
  final String text;
  final Color color;

  const PaperTag({
    super.key,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
