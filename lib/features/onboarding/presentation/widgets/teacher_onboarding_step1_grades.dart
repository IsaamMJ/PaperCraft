import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../admin/domain/entities/admin_setup_grade.dart';
import '../../../admin/presentation/bloc/admin_setup_bloc.dart';
import '../../../admin/presentation/bloc/admin_setup_event.dart';

/// Step 1: School Info (Read-only) + Select Teaching Grades
/// For teachers joining an existing school
class TeacherOnboardingStep1Grades extends StatelessWidget {
  final List<AdminSetupGrade> selectedGrades;
  final List<AdminSetupGrade> availableGrades;
  final String? schoolName;
  final String? schoolAddress;
  final VoidCallback? onRefresh;

  const TeacherOnboardingStep1Grades({
    Key? key,
    required this.selectedGrades,
    required this.availableGrades,
    this.schoolName,
    this.schoolAddress,
    this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Available grades are the ones created by admin for this school
    final gradeNumbers = availableGrades.map((g) => g.gradeNumber).toList()..sort();

    // Debug logging

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // School Information Section (Read-only)
        if (schoolName != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // School Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.school, color: AppColors.primary, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your School',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                schoolName ?? '',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (schoolAddress != null && schoolAddress!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.location_on,
                                      color: AppColors.textSecondary,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        schoolAddress!,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),

        // Teaching Grades Section
        Text(
          'Select Your Teaching Grades',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Which grades will you be teaching this academic year?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),

        // Grade Selection Grid
        if (gradeNumbers.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              border: Border.all(color: AppColors.error.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No Grades Available',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'The school admin has not yet created any grades. '
                            'Please ask your school administrator to set up grades first.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onRefresh != null) ...[
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          )
        else
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: gradeNumbers.map((grade) {
              final isSelected = selectedGrades.any((g) => g.gradeNumber == grade);

              return GestureDetector(
                onTap: () {
                  final gradeObject = availableGrades.firstWhere(
                    (g) => g.gradeNumber == grade,
                  );
                  if (isSelected) {
                    context.read<AdminSetupBloc>().add(
                      RemoveGradeEvent(gradeNumber: grade),
                    );
                  } else {
                    context.read<AdminSetupBloc>().add(
                      AddGradeEvent(
                        gradeNumber: grade,
                        gradeId: gradeObject.gradeId,
                      ),
                    );
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : null,
                    color: isSelected ? null : Colors.grey[100],
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ]
                        : null,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$grade',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (isSelected)
                          const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 14,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

        // Selected Grades Summary
        if (selectedGrades.isNotEmpty) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${selectedGrades.length} grade${selectedGrades.length > 1 ? 's' : ''} selected',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
