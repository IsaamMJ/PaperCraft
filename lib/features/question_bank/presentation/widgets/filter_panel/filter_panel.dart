import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../../../core/presentation/constants/ui_constants.dart';
import '../../../../catalog/presentation/bloc/subject_bloc.dart';
import '../../../../catalog/presentation/bloc/grade_bloc.dart';
import '../../../../catalog/domain/entities/subject_entity.dart';

/// Filter panel for question bank with grade and subject filters
class FilterPanel extends StatelessWidget {
  final int? selectedGradeLevel;
  final String? selectedSubjectId;
  final List<int> availableGradeLevels;
  final List<SubjectEntity> availableSubjects;
  final ValueChanged<int?> onGradeChanged;
  final ValueChanged<String?> onSubjectChanged;
  final VoidCallback onClearFilters;
  final bool hasActiveFilters;

  const FilterPanel({
    super.key,
    required this.selectedGradeLevel,
    required this.selectedSubjectId,
    required this.availableGradeLevels,
    required this.availableSubjects,
    required this.onGradeChanged,
    required this.onSubjectChanged,
    required this.onClearFilters,
    required this.hasActiveFilters,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildGradeFilter(context),
          const SizedBox(width: 8),
          _buildSubjectFilter(context),
          if (hasActiveFilters) ...[
            const SizedBox(width: 8),
            _buildClearButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildGradeFilter(BuildContext context) {
    return BlocConsumer<GradeBloc, GradeState>(
      listener: (context, state) {
        if (state is GradeLevelsLoaded) {
          if (selectedGradeLevel != null &&
              !state.gradeLevels.contains(selectedGradeLevel)) {
            onGradeChanged(null);
          }
        }
      },
      builder: (context, state) {
        if (state is GradeLoading) return _buildLoadingChip('Grade');
        if (state is GradeError) {
          return _buildErrorChip(
            'Grade',
            () => context.read<GradeBloc>().add(const LoadGradeLevels()),
          );
        }

        return _buildFilterChip<int>(
          label: 'Grade',
          value: selectedGradeLevel,
          options: availableGradeLevels
              .map((level) => DropdownMenuItem(
                    value: level,
                    child: Text(
                      'Grade $level',
                      style: const TextStyle(fontSize: UIConstants.fontSizeMedium),
                    ),
                  ))
              .toList(),
          onChanged: onGradeChanged,
        );
      },
    );
  }

  Widget _buildSubjectFilter(BuildContext context) {
    return BlocConsumer<SubjectBloc, SubjectState>(
      listener: (context, state) {
        if (state is SubjectsLoaded) {
          if (selectedSubjectId != null &&
              !state.subjects.any((s) => s.id == selectedSubjectId)) {
            onSubjectChanged(null);
          }
        }
      },
      builder: (context, state) {
        if (state is SubjectLoading) return _buildLoadingChip('Subject');
        if (state is SubjectError) {
          return _buildErrorChip(
            'Subject',
            () => context.read<SubjectBloc>().add(const LoadSubjects()),
          );
        }

        return _buildFilterChip<String>(
          label: 'Subject',
          value: selectedSubjectId,
          options: availableSubjects
              .map((subject) => DropdownMenuItem(
                    value: subject.id,
                    child: Text(
                      subject.name,
                      style: const TextStyle(fontSize: UIConstants.fontSizeMedium),
                    ),
                  ))
              .toList(),
          onChanged: onSubjectChanged,
        );
      },
    );
  }

  Widget _buildFilterChip<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> options,
    required ValueChanged<T?> onChanged,
  }) {
    final isSelected = value != null;
    T? validatedValue = value;
    if (value != null && !options.any((item) => item.value == value)) {
      validatedValue = null;
    }

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.background,
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: validatedValue,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: UIConstants.fontSizeSmall,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          selectedItemBuilder: (context) => options.map((item) {
            final text = (item.child as Text).data!;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                text.length > 10 ? '${text.substring(0, 10)}...' : text,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: UIConstants.fontSizeSmall,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
          items: [
            DropdownMenuItem<T>(
              value: null,
              child: Text(
                'All ${label}s',
                style: const TextStyle(fontSize: UIConstants.fontSizeMedium),
              ),
            ),
            ...options,
          ],
          onChanged: onChanged,
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 18),
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        ),
      ),
    );
  }

  Widget _buildLoadingChip(String label) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: UIConstants.fontSizeSmall,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorChip(String label, VoidCallback onRetry) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onRetry,
          borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 14, color: AppColors.error),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: UIConstants.fontSizeSmall,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClearButton() {
    return GestureDetector(
      onTap: onClearFilters,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.clear_rounded, size: 14, color: AppColors.error),
            const SizedBox(width: 4),
            Text(
              'Clear',
              style: TextStyle(
                color: AppColors.error,
                fontSize: UIConstants.fontSizeSmall,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
