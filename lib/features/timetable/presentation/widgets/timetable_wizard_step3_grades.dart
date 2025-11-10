import 'package:flutter/material.dart';

import '../pages/exam_timetable_create_wizard_page.dart';

/// Step 3: Select Grades and Sections
///
/// Allows users to select which grades and sections the timetable will cover.
/// Shows available grades with their sections and allows multi-select.
class TimetableWizardStep3Grades extends StatefulWidget {
  final WizardData wizardData;
  final Function(List<GradeSelection>) onGradesSelected;

  const TimetableWizardStep3Grades({
    required this.wizardData,
    required this.onGradesSelected,
    super.key,
  });

  @override
  State<TimetableWizardStep3Grades> createState() =>
      _TimetableWizardStep3GradesState();
}

class _TimetableWizardStep3GradesState extends State<TimetableWizardStep3Grades> {
  /// Mock data - In a real app, this would come from a repository/use case
  late List<GradeData> _grades;

  @override
  void initState() {
    super.initState();
    _initializeGrades();
  }

  /// Initialize mock grade data
  /// In production, this would fetch from the API
  void _initializeGrades() {
    _grades = [
      GradeData(
        id: 'grade-1',
        number: 1,
        sections: ['A', 'B', 'C'],
        selectedSections: widget.wizardData.selectedGrades
                .firstWhere(
                  (g) => g.gradeId == 'grade-1',
                  orElse: () =>
                      GradeSelection(gradeId: '', gradeName: '', sections: []),
                )
                .sections
            .cast<String>()
            .toList(),
      ),
      GradeData(
        id: 'grade-2',
        number: 2,
        sections: ['A', 'B', 'C'],
        selectedSections: widget.wizardData.selectedGrades
                .firstWhere(
                  (g) => g.gradeId == 'grade-2',
                  orElse: () =>
                      GradeSelection(gradeId: '', gradeName: '', sections: []),
                )
                .sections
            .cast<String>()
            .toList(),
      ),
      GradeData(
        id: 'grade-3',
        number: 3,
        sections: ['A', 'B'],
        selectedSections: widget.wizardData.selectedGrades
                .firstWhere(
                  (g) => g.gradeId == 'grade-3',
                  orElse: () =>
                      GradeSelection(gradeId: '', gradeName: '', sections: []),
                )
                .sections
            .cast<String>()
            .toList(),
      ),
      GradeData(
        id: 'grade-4',
        number: 4,
        sections: ['A', 'B'],
        selectedSections: widget.wizardData.selectedGrades
                .firstWhere(
                  (g) => g.gradeId == 'grade-4',
                  orElse: () =>
                      GradeSelection(gradeId: '', gradeName: '', sections: []),
                )
                .sections
            .cast<String>()
            .toList(),
      ),
      GradeData(
        id: 'grade-5',
        number: 5,
        sections: ['A', 'B', 'C'],
        selectedSections: widget.wizardData.selectedGrades
                .firstWhere(
                  (g) => g.gradeId == 'grade-5',
                  orElse: () =>
                      GradeSelection(gradeId: '', gradeName: '', sections: []),
                )
                .sections
            .cast<String>()
            .toList(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Text(
              'Select grades and sections for this timetable',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),

            // Grades list
            ..._grades.map((grade) => _buildGradeCard(context, grade)),

            const SizedBox(height: 16),

            // Summary
            if (_getSelectedCount() > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Selected: ${_getSelectedCount()} grade-section combination(s)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.green[800],
                            ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build grade card with section selection
  Widget _buildGradeCard(BuildContext context, GradeData grade) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grade header
            Text(
              'Grade ${grade.number}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            // Section checkboxes
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: grade.sections
                  .map((section) => _buildSectionCheckbox(context, grade, section))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Build section checkbox
  Widget _buildSectionCheckbox(
    BuildContext context,
    GradeData grade,
    String section,
  ) {
    final isSelected = grade.selectedSections.contains(section);

    return FilterChip(
      label: Text('Section $section'),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            grade.selectedSections.add(section);
          } else {
            grade.selectedSections.remove(section);
          }
          _notifyChanges();
        });
      },
      backgroundColor: Colors.white,
      selectedColor: Colors.blue[100],
      checkmarkColor: Colors.blue,
      side: BorderSide(
        color: isSelected ? Colors.blue : Colors.grey[300]!,
      ),
    );
  }

  /// Get total selected count
  int _getSelectedCount() {
    int count = 0;
    for (final grade in _grades) {
      count += grade.selectedSections.length;
    }
    return count;
  }

  /// Notify parent of changes
  void _notifyChanges() {
    final selections = <GradeSelection>[];
    for (final grade in _grades) {
      if (grade.selectedSections.isNotEmpty) {
        selections.add(
          GradeSelection(
            gradeId: grade.id,
            gradeName: 'Grade ${grade.number}',
            sections: grade.selectedSections,
          ),
        );
      }
    }
    widget.onGradesSelected(selections);
  }
}

/// Grade data model for UI
class GradeData {
  final String id;
  final int number;
  final List<String> sections;
  final List<String> selectedSections;

  GradeData({
    required this.id,
    required this.number,
    required this.sections,
    required this.selectedSections,
  });
}
