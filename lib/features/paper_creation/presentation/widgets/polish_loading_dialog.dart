import 'package:flutter/material.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';

/// Loading dialog shown during AI polishing with progress
/// This is now a stateful widget with a ValueNotifier to avoid rebuilding the entire dialog
/// [isPerSection] - If true, displays progress as sections instead of individual questions
class PolishLoadingDialog extends StatefulWidget {
  final int totalQuestions;
  final ValueNotifier<int> processedQuestionsNotifier;
  final bool isPerSection;

  const PolishLoadingDialog({
    super.key,
    required this.totalQuestions,
    required this.processedQuestionsNotifier,
    this.isPerSection = false,
  });

  @override
  State<PolishLoadingDialog> createState() => _PolishLoadingDialogState();
}

class _PolishLoadingDialogState extends State<PolishLoadingDialog> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.processedQuestionsNotifier,
      builder: (context, processedQuestions, child) {
        final progress = widget.totalQuestions > 0 ? processedQuestions / widget.totalQuestions : 0.0;

    return WillPopScope(
      onWillPop: () async => false, // Prevent dismissal
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary10,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_fix_high,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                '✨ Polishing Questions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Progress text
              Text(
                'Fixing grammar, spelling & punctuation...',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              const SizedBox(height: 12),

              // Counter
              Text(
                widget.isPerSection
                    ? '$processedQuestions of ${widget.totalQuestions} sections'
                    : '$processedQuestions of ${widget.totalQuestions} questions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),

              // Estimated time
              if (processedQuestions < widget.totalQuestions)
                Text(
                  widget.isPerSection
                      ? 'Polishing section ${processedQuestions + 1} of ${widget.totalQuestions}...'
                      : 'This may take a few seconds...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
        ),
      ),
        );
      },
    );
  }
}
