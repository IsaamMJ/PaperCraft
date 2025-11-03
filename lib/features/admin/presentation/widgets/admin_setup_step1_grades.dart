import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../domain/entities/admin_setup_grade.dart';
import '../bloc/admin_setup_bloc.dart';
import '../bloc/admin_setup_event.dart';

/// Step 1: Enter School Details and Select Grades
class AdminSetupStep1Grades extends StatefulWidget {
  final List<AdminSetupGrade> selectedGrades;

  const AdminSetupStep1Grades({
    Key? key,
    required this.selectedGrades,
  }) : super(key: key);

  @override
  State<AdminSetupStep1Grades> createState() => _AdminSetupStep1GradesState();
}

class _AdminSetupStep1GradesState extends State<AdminSetupStep1Grades> {
  late TextEditingController _tenantNameController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _tenantNameController = TextEditingController();
    _addressController = TextEditingController();
  }

  @override
  void dispose() {
    _tenantNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // All available grades (1-12)
    const availableGrades = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and description
        Text(
          'School Details',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
        ),
        const SizedBox(height: 24),

        // School name input
        TextField(
          controller: _tenantNameController,
          decoration: InputDecoration(
            labelText: 'School Name',
            hintText: 'Enter your school name',
            prefixIcon: const Icon(Icons.school),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // School address input
        TextField(
          controller: _addressController,
          decoration: InputDecoration(
            labelText: 'School Address',
            hintText: 'Enter school address (city, state)',
            prefixIcon: const Icon(Icons.location_on),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 28),

        // Divider
        Container(
          height: 1,
          color: Colors.grey[300],
        ),
        const SizedBox(height: 28),

        // Title for grades
        Text(
          'Select School Grades',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Which grades does your school teach? Select one or more.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 24),

        // Quick add buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickAddButton(
              context,
              'Primary\n(1-5)',
              [1, 2, 3, 4, 5],
              widget.selectedGrades,
            ),
            _buildQuickAddButton(
              context,
              'Middle\n(6-8)',
              [6, 7, 8],
              widget.selectedGrades,
            ),
            _buildQuickAddButton(
              context,
              'High\n(9-10)',
              [9, 10],
              widget.selectedGrades,
            ),
            _buildQuickAddButton(
              context,
              'Higher\n(11-12)',
              [11, 12],
              widget.selectedGrades,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Divider
        Container(
          height: 1,
          color: Colors.grey[300],
        ),
        const SizedBox(height: 24),

        // Manual selection
        Text(
          'Or select individual grades',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 16),

        // Grade selection grid
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: availableGrades.map((grade) {
            final isSelected = widget.selectedGrades.any((g) => g.gradeNumber == grade);

            return GestureDetector(
              onTap: () {
                if (isSelected) {
                  context.read<AdminSetupBloc>().add(
                        RemoveGradeEvent(gradeNumber: grade),
                      );
                } else {
                  context.read<AdminSetupBloc>().add(
                        AddGradeEvent(gradeNumber: grade),
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
                        Icon(
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

        // Selected grades summary
        if (widget.selectedGrades.isNotEmpty) ...[
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
                    '${widget.selectedGrades.length} grade${widget.selectedGrades.length > 1 ? 's' : ''} selected',
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

  /// Build quick add button for grade range
  static Widget _buildQuickAddButton(
    BuildContext context,
    String label,
    List<int> grades,
    List<AdminSetupGrade> selectedGrades,
  ) {
    final allSelected = grades.every((g) => selectedGrades.any((sg) => sg.gradeNumber == g));

    return Material(
      child: InkWell(
        onTap: () {
          for (var grade in grades) {
            final isSelected = selectedGrades.any((g) => g.gradeNumber == grade);
            if (!isSelected) {
              context.read<AdminSetupBloc>().add(AddGradeEvent(gradeNumber: grade));
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: allSelected
                ? AppColors.primary.withOpacity(0.15)
                : Colors.grey[100],
            border: Border.all(
              color: allSelected ? AppColors.primary : Colors.grey[300]!,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: allSelected ? AppColors.primary : AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}
