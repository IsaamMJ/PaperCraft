// features/question_papers/pages/widgets/question_input/section_progress_widget.dart
import 'package:flutter/material.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../../catalog/domain/entities/paper_section_entity.dart';

import '../../../../../core/presentation/constants/ui_constants.dart';
import '../../../../paper_workflow/domain/entities/question_entity.dart';


class SectionProgressWidget extends StatelessWidget {
  final int currentSection;
  final List<PaperSectionEntity> sections;
  final Map<String, List<Question>> allQuestions;

  const SectionProgressWidget({
    super.key,
    required this.currentSection,
    required this.sections,
    required this.allQuestions,
  });

  @override
  Widget build(BuildContext context) {
    final section = sections[currentSection];
    final questions = allQuestions[section.name] ?? [];
    final mandatoryCount = questions.where((q) => !q.isOptional).length;

    // For match_following, show pairs completed instead of question count
    String progressText;
    double progress;

    if (section.type == 'match_following') {
      // For matching: 1 question with N pairs
      // section.questions = number of pairs needed
      // We have 1 question when complete
      final pairsCompleted = mandatoryCount > 0 ? section.questions : 0;
      progressText = '$pairsCompleted/${section.questions} pairs';
      progress = mandatoryCount > 0 ? 1.0 : 0.0;
    } else {
      // For other types: show question count
      progressText = '$mandatoryCount/${section.questions} questions';
      progress = (mandatoryCount / section.questions).clamp(0.0, 1.0);
    }

    return Container(
      padding: const EdgeInsets.all(UIConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.primary05,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Section ${currentSection + 1} of ${sections.length}',
                style: TextStyle(
                  fontSize: UIConstants.fontSizeMedium,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
              Text(
                progressText,
                style: TextStyle(
                  fontSize: UIConstants.fontSizeMedium,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: UIConstants.spacing8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation(
              progress >= 1.0 ? AppColors.success : AppColors.primary,
            ),
            minHeight: 6,
          ),
          if (sections.length > 1) ...[
            SizedBox(height: UIConstants.spacing16),
            _buildSectionOverview(),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionOverview() {
    return Row(
      children: sections.asMap().entries.map((entry) {
        final index = entry.key;
        final section = entry.value;
        final questions = allQuestions[section.name] ?? [];
        final mandatoryCount = questions.where((q) => !q.isOptional).length;

        // For matching questions: only need 1 question with N pairs
        // For other types: need section.questions number of questions
        final isCompleted = section.type == 'match_following'
            ? mandatoryCount >= 1
            : mandatoryCount >= section.questions;
        final isCurrent = index == currentSection;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < sections.length - 1 ? 8 : 0),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: isCurrent
                  ? AppColors.primary10
                  : isCompleted
                  ? AppColors.success10
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
            ),
            child: Column(
              children: [
                Icon(
                  isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 16,
                  color: isCompleted ? AppColors.success : AppColors.textTertiary,
                ),
                SizedBox(height: UIConstants.spacing4),
                Text(
                  section.name,
                  style: TextStyle(
                    fontSize: 10,
                    color: isCurrent ? AppColors.primary : AppColors.textTertiary,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}