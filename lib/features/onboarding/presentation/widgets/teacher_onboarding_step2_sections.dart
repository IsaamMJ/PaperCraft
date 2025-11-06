import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../admin/domain/entities/admin_setup_grade.dart';
import '../../../admin/domain/entities/admin_setup_section.dart';
import '../../../admin/presentation/bloc/admin_setup_bloc.dart';
import '../../../admin/presentation/bloc/admin_setup_event.dart';

/// Step 2: Select Your Teaching Sections
/// For teachers to specify which sections they teach in each grade
class TeacherOnboardingStep2Sections extends StatelessWidget {
  final List<AdminSetupGrade> selectedGrades;
  final Map<int, List<AdminSetupSection>> availableSectionsPerGrade;
  final Map<int, List<String>> sectionsPerGrade;

  const TeacherOnboardingStep2Sections({
    Key? key,
    required this.selectedGrades,
    required this.availableSectionsPerGrade,
    required this.sectionsPerGrade,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Your Teaching Sections',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Which sections will you be handling in each grade?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),

        // Sections per grade (read-only selection from available sections)
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: selectedGrades.length,
          separatorBuilder: (context, index) => const SizedBox(height: 20),
          itemBuilder: (context, index) {
            final grade = selectedGrades[index];
            final availableSections = availableSectionsPerGrade[grade.gradeNumber] ?? [];
            final selectedSections = sectionsPerGrade[grade.gradeNumber] ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grade ${grade.gradeNumber}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                if (availableSections.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No sections available for this grade',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableSections.map((section) {
                      final isSelected = selectedSections.contains(section.sectionName);

                      return FilterChip(
                        label: Text(section.sectionName),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            context.read<AdminSetupBloc>().add(
                              AddSectionEvent(
                                gradeNumber: grade.gradeNumber,
                                sectionName: section.sectionName,
                              ),
                            );
                          } else {
                            context.read<AdminSetupBloc>().add(
                              RemoveSectionEvent(
                                gradeNumber: grade.gradeNumber,
                                sectionName: section.sectionName,
                              ),
                            );
                          }
                        },
                        backgroundColor: Colors.transparent,
                        selectedColor: AppColors.primary.withOpacity(0.2),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
              ],
            );
          },
        ),

        const SizedBox(height: 16),
        Text(
          'Select the sections you will be teaching. Only sections created by your school are available.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
