import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/ui_constants.dart';

/// Step progress indicator widget for multi-step forms
class StepProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String stepTitle;

  const StepProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Step $currentStep of $totalSteps',
                style: TextStyle(
                  fontSize: UIConstants.fontSizeMedium,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Text(
                stepTitle,
                style: TextStyle(
                  fontSize: UIConstants.fontSizeMedium,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: UIConstants.spacing12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: currentStep / totalSteps,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
