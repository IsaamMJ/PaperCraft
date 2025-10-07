import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/ui_constants.dart';

/// Info box widget for displaying informational messages
class InfoBox extends StatelessWidget {
  final String message;
  final IconData? icon;
  final Color? color;

  const InfoBox({
    super.key,
    required this.message,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final boxColor = color ?? AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: boxColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
      ),
      child: Row(
        children: [
          Icon(
            icon ?? Icons.info_outline,
            color: boxColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: boxColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
