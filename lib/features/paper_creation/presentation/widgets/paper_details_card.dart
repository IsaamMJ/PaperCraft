import 'package:flutter/material.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../catalog/domain/entities/exam_type.dart';
import '../../../catalog/domain/entities/grade_entity.dart';

/// Compact inline paper details display - shows essential info only
class PaperDetailsDisplay extends StatelessWidget {
  final GradeEntity? selectedGrade;
  final List<String> selectedSections;
  final String? selectedSubject;
  final ExamType? selectedExamType;

  const PaperDetailsDisplay({
    super.key,
    required this.selectedGrade,
    required this.selectedSections,
    required this.selectedSubject,
    required this.selectedExamType,
  });

  @override
  Widget build(BuildContext context) {
    final details = <String>[];

    if (selectedGrade != null) {
      details.add('Grade ${selectedGrade!.gradeNumber}');
    }
    if (selectedSections.isNotEmpty) {
      details.add(selectedSections.join(','));
    }
    if (selectedSubject != null) {
      details.add(selectedSubject!);
    }
    if (selectedExamType != null) {
      details.add(selectedExamType!.displayName);
    }

    if (details.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary10,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(color: AppColors.primary20),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outlined, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              details.join(' • '),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
