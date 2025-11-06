import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../admin/domain/entities/admin_setup_grade.dart';
import '../../../admin/domain/entities/admin_setup_section.dart';
import '../../../admin/domain/entities/admin_setup_state.dart' as domain;
import '../../../admin/presentation/bloc/admin_setup_bloc.dart';
import '../../../admin/presentation/bloc/admin_setup_event.dart';

/// Step 3: Select Your Teaching Subjects (Per Section)
/// For teachers to specify which subjects they teach in each grade+section combination
class TeacherOnboardingStep3Subjects extends StatelessWidget {
  final List<AdminSetupGrade> selectedGrades;
  final Map<int, List<AdminSetupSection>> availableSectionsPerGrade;
  final Map<int, List<String>> availableSubjectsPerGrade;
  final Map<int, Map<String, List<String>>> availableSubjectsPerGradePerSection;
  final domain.AdminSetupState setupState;

  const TeacherOnboardingStep3Subjects({
    Key? key,
    required this.selectedGrades,
    required this.availableSectionsPerGrade,
    required this.availableSubjectsPerGrade,
    required this.availableSubjectsPerGradePerSection,
    required this.setupState,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Your Teaching Subjects',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select the subjects you\'ll be teaching in each section',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),

        // Subjects per grade+section (hierarchical view)
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: selectedGrades.length,
          separatorBuilder: (context, index) => const SizedBox(height: 24),
          itemBuilder: (context, gradeIndex) {
            final grade = selectedGrades[gradeIndex];
            // Get only the sections that were selected in Step 2
            final selectedSectionNames = setupState.sectionsPerGrade[grade.gradeNumber] ?? [];
            final allAvailableSections = availableSectionsPerGrade[grade.gradeNumber] ?? [];
            // Filter to only show selected sections
            final sections = allAvailableSections
                .where((section) => selectedSectionNames.contains(section.sectionName))
                .toList();
            final availableSubjects = availableSubjectsPerGrade[grade.gradeNumber] ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grade header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.layers, color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Grade ${grade.gradeNumber}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${sections.length} sections',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Sections within this grade
                if (sections.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No sections available for this grade',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else if (availableSubjects.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No subjects available for this grade',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sections.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, sectionIndex) {
                      final section = sections[sectionIndex];
                      final selectedSubjects = setupState.getSubjectsForGradeSection(
                        grade.gradeNumber,
                        section.sectionName,
                      );
                      // Get only subjects offered in this specific section
                      final subjectsOfferedInSection = availableSubjectsPerGradePerSection[grade.gradeNumber]?[section.sectionName] ?? [];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section header
                          Row(
                            children: [
                              const SizedBox(width: 16),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    section.sectionName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Section ${section.sectionName}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              if (selectedSubjects.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                    horizontal: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${selectedSubjects.length} selected',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Subject checkboxes for this section
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: subjectsOfferedInSection.map((subject) {
                                final isSelected = selectedSubjects.contains(subject);

                                return GestureDetector(
                                  onTap: () {
                                    if (isSelected) {
                                      context.read<AdminSetupBloc>().add(
                                        RemoveSubjectFromGradeSectionEvent(
                                          gradeNumber: grade.gradeNumber,
                                          section: section.sectionName,
                                          subjectName: subject,
                                        ),
                                      );
                                    } else {
                                      context.read<AdminSetupBloc>().add(
                                        AddSubjectToGradeSectionEvent(
                                          gradeNumber: grade.gradeNumber,
                                          section: section.sectionName,
                                          subjectName: subject,
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary.withOpacity(0.15)
                                          : Colors.grey[100],
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : Colors.grey[300]!,
                                        width: isSelected ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value: isSelected,
                                          onChanged: (value) {
                                            if (isSelected) {
                                              context.read<AdminSetupBloc>().add(
                                                RemoveSubjectFromGradeSectionEvent(
                                                  gradeNumber: grade.gradeNumber,
                                                  section: section.sectionName,
                                                  subjectName: subject,
                                                ),
                                              );
                                            } else {
                                              context.read<AdminSetupBloc>().add(
                                                AddSubjectToGradeSectionEvent(
                                                  gradeNumber: grade.gradeNumber,
                                                  section: section.sectionName,
                                                  subjectName: subject,
                                                ),
                                              );
                                            }
                                          },
                                          activeColor: AppColors.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          subject,
                                          style: TextStyle(
                                            color: isSelected
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            );
          },
        ),

        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Select subjects for each section. Different sections can have different subjects.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
