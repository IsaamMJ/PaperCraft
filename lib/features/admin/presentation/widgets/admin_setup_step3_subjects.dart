import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../domain/entities/admin_setup_grade.dart';
import '../bloc/admin_setup_bloc.dart';
import '../bloc/admin_setup_event.dart';
import '../bloc/admin_setup_state.dart';

/// Step 3: Select subjects for each grade
class AdminSetupStep3Subjects extends StatefulWidget {
  final List<AdminSetupGrade> selectedGrades;
  final Map<int, List<String>> subjectsPerGrade;

  const AdminSetupStep3Subjects({
    Key? key,
    required this.selectedGrades,
    required this.subjectsPerGrade,
  }) : super(key: key);

  @override
  State<AdminSetupStep3Subjects> createState() => _AdminSetupStep3SubjectsState();
}

class _AdminSetupStep3SubjectsState extends State<AdminSetupStep3Subjects> {
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, List<String>> _suggestions = {};

  @override
  void initState() {
    super.initState();
    // Initialize text controllers and load suggestions for each grade
    for (final grade in widget.selectedGrades) {
      _controllers[grade.gradeNumber] = TextEditingController();
      _loadSubjectSuggestions(grade.gradeNumber);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Load subject suggestions for a grade
  void _loadSubjectSuggestions(int gradeNumber) {
    context.read<AdminSetupBloc>().add(
          LoadSubjectSuggestionsEvent(gradeNumber: gradeNumber),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'Select Subjects for Each Grade',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add subjects taught in each grade. You can use suggested subjects or add custom ones.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 24),

        // Grade subjects
        ...widget.selectedGrades.map((grade) {
          final subjects = widget.subjectsPerGrade[grade.gradeNumber] ?? [];

          return Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: _buildGradeSubjectsCard(context, grade, subjects),
          );
        }),
      ],
    );
  }

  /// Build a card for a single grade's subjects
  Widget _buildGradeSubjectsCard(
    BuildContext context,
    AdminSetupGrade grade,
    List<String> subjects,
  ) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grade title
            Text(
              'Grade ${grade.gradeNumber}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Existing subjects as chips
            if (subjects.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                children: subjects.map((subject) {
                  return InputChip(
                    label: Text(subject),
                    onDeleted: () {
                      context.read<AdminSetupBloc>().add(
                            RemoveSubjectEvent(
                              gradeNumber: grade.gradeNumber,
                              subjectName: subject,
                            ),
                          );
                    },
                    deleteIcon: const Icon(Icons.close, size: 18),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Available subjects from catalog
            const SizedBox(height: 12),
            _buildSubjectSelector(context, grade),
          ],
        ),
      ),
    );
  }

  /// Add a subject to a grade
  void _addSubject(BuildContext context, int gradeNumber, String subjectName) {
    if (subjectName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a subject name')),
      );
      return;
    }

    context.read<AdminSetupBloc>().add(
          AddSubjectEvent(
            gradeNumber: gradeNumber,
            subjectName: subjectName,
          ),
        );

    _controllers[gradeNumber]!.clear();
  }

  /// Build subject selector - only allows catalog subjects
  Widget _buildSubjectSelector(BuildContext context, AdminSetupGrade grade) {
    return BlocListener<AdminSetupBloc, AdminSetupUIState>(
      listener: (context, state) {
        if (state is SubjectSuggestionsLoaded &&
            state.gradeNumber == grade.gradeNumber) {
          setState(() {
            _suggestions[grade.gradeNumber] = state.suggestions;
          });
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select from Available Subjects',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          if (_suggestions[grade.gradeNumber] == null)
            const SizedBox(
              height: 40,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_suggestions[grade.gradeNumber]!.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.orange[700], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No subjects available for Grade ${grade.gradeNumber}',
                      style: TextStyle(color: Colors.orange[700]),
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestions[grade.gradeNumber]!.map((suggestion) {
                final isSelected = (widget.subjectsPerGrade[grade.gradeNumber] ?? [])
                    .contains(suggestion);

                return FilterChip(
                  label: Text(suggestion),
                  selected: isSelected,
                  onSelected: isSelected
                      ? null
                      : (_) {
                          context.read<AdminSetupBloc>().add(
                                AddSubjectEvent(
                                  gradeNumber: grade.gradeNumber,
                                  subjectName: suggestion,
                                ),
                              );
                        },
                  backgroundColor: isSelected
                      ? AppColors.primary.withOpacity(0.2)
                      : Colors.grey[100],
                  selectedColor: AppColors.primary.withOpacity(0.3),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
          Text(
            'Note: You can only select subjects from the school catalog.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }
}
