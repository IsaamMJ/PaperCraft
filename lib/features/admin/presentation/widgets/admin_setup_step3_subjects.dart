import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../domain/entities/admin_setup_grade.dart';
import '../../domain/entities/admin_setup_section.dart';
import '../bloc/admin_setup_bloc.dart';
import '../bloc/admin_setup_event.dart';
import '../bloc/admin_setup_state.dart';

/// Step 3: Select subjects for each grade+section combination
/// KEY CHANGE: Subjects are now assigned PER SECTION, not per grade
class AdminSetupStep3Subjects extends StatefulWidget {
  final List<AdminSetupGrade> selectedGrades;
  final Map<String, List<String>> subjectsPerGradeSection; // Key: "gradeNumber:sectionName"

  const AdminSetupStep3Subjects({
    Key? key,
    required this.selectedGrades,
    required this.subjectsPerGradeSection,
  }) : super(key: key);

  @override
  State<AdminSetupStep3Subjects> createState() => _AdminSetupStep3SubjectsState();
}

class _AdminSetupStep3SubjectsState extends State<AdminSetupStep3Subjects> {
  final Map<int, List<String>> _suggestions = {};
  String? _expandedGradeId; // Track which grade card is expanded

  @override
  void initState() {
    super.initState();
    // Load subject suggestions for each grade
    for (final grade in widget.selectedGrades) {
      _loadSubjectSuggestions(grade.gradeNumber);
    }
  }

  /// Load subject suggestions for a grade
  void _loadSubjectSuggestions(int gradeNumber) {
    context.read<AdminSetupBloc>().add(
          LoadSubjectSuggestionsEvent(gradeNumber: gradeNumber),
        );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Assign Subjects to Sections',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Each section can have different subjects. Select subjects for each grade+section combination.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 24),

          // Grade cards with sections
          ...widget.selectedGrades.map((grade) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildGradeCard(context, grade),
            );
          }),
        ],
      ),
    );
  }

  /// Build an expandable card for a grade with all its sections
  Widget _buildGradeCard(BuildContext context, AdminSetupGrade grade) {
    final gradeIdKey = 'grade_${grade.gradeNumber}';
    final isExpanded = _expandedGradeId == gradeIdKey;

    return Card(
      elevation: 2,
      child: Column(
        children: [
          // Grade header
          GestureDetector(
            onTap: () {
              setState(() {
                _expandedGradeId = isExpanded ? null : gradeIdKey;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Grade ${grade.gradeNumber}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${grade.sections.length} sections',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content - sections and subjects
          if (isExpanded) ...[
            Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (grade.sections.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Text(
                        'No sections configured for this grade.\nPlease add sections in Step 2.',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    ...grade.sections.map((section) {
                      return _buildSectionCard(context, grade, section);
                    }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build a card for a section with its subjects
  Widget _buildSectionCard(
    BuildContext context,
    AdminSetupGrade grade,
    AdminSetupSection section,
  ) {
    final key = '${grade.gradeNumber}:${section.sectionName}';
    final currentSubjects = widget.subjectsPerGradeSection[key] ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[50],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Text(
              'Section ${section.sectionName}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Current subjects as chips
            if (currentSubjects.isNotEmpty) ...[
              Text(
                'Current Subjects',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: currentSubjects.map((subject) {
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
                    deleteIcon: const Icon(Icons.close, size: 16),
                    backgroundColor: AppColors.secondary10,
                    labelStyle: TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'No subjects selected yet',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Available subjects selector
            _buildSubjectSelectorForSection(context, grade, section, currentSubjects),
          ],
        ),
      ),
    );
  }

  /// Build subject selector for a specific section
  Widget _buildSubjectSelectorForSection(
    BuildContext context,
    AdminSetupGrade grade,
    AdminSetupSection section,
    List<String> currentSubjects,
  ) {
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
            'Available Subjects',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          if (_suggestions[grade.gradeNumber] == null)
            const SizedBox(
              height: 32,
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
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.orange[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No subjects available for Grade ${grade.gradeNumber}',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _suggestions[grade.gradeNumber]!.map((suggestion) {
                final isSelected = currentSubjects.contains(suggestion);

                return FilterChip(
                  label: Text(suggestion),
                  selected: isSelected,
                  onSelected: isSelected
                      ? null
                      : (_) {
                          context.read<AdminSetupBloc>().add(
                                AddSubjectToGradeSectionEvent(
                                  gradeNumber: grade.gradeNumber,
                                  section: section.sectionName,
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
                  labelStyle: TextStyle(fontSize: 12),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
