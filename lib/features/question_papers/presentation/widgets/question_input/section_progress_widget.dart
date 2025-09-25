// features/question_papers/presentation/widgets/question_input/section_progress_widget.dart
import 'package:flutter/material.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../domain/entities/exam_type_entity.dart';
import '../../../domain/entities/question_entity.dart';

class SectionProgressWidget extends StatelessWidget {
  final int currentSection;
  final List<ExamSectionEntity> sections;
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
    final progress = (mandatoryCount / section.questions).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Section ${currentSection + 1} of ${sections.length}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '$mandatoryCount/${section.questions} questions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation(
              progress >= 1.0 ? AppColors.success : AppColors.primary,
            ),
            minHeight: 6,
          ),
          if (sections.length > 1) ...[
            const SizedBox(height: 16),
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
        final isCompleted = mandatoryCount >= section.questions;
        final isCurrent = index == currentSection;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < sections.length - 1 ? 8 : 0),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: isCurrent
                  ? AppColors.primary.withOpacity(0.1)
                  : isCompleted
                  ? AppColors.success.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Icon(
                  isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 16,
                  color: isCompleted ? AppColors.success : AppColors.textTertiary,
                ),
                const SizedBox(height: 4),
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