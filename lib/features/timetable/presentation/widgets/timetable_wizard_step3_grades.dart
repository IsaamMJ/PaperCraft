import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/exam_timetable_bloc.dart';
import '../bloc/exam_timetable_event.dart';
import '../bloc/exam_timetable_state.dart';
import '../pages/exam_timetable_create_wizard_page.dart';

/// Step 3: Select Grades and Sections
///
/// Allows users to select which grades and sections the timetable will cover.
/// Shows available grades with their sections from database (not hardcoded).
/// Supports multi-select of grades/sections.
///
/// Data is fetched from the database respecting school-specific grade structure.
/// This ensures consistency with the school's actual academic organization.
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
  late Map<String, Set<String>> _selectedSectionsByGrade; // gradeId -> set of selected sections

  @override
  void initState() {
    super.initState();
    print('[TimetableWizardStep3Grades] initState');
    _selectedSectionsByGrade = {};
    _loadGradesAndSections();
  }

  /// Load grades and sections from BLoC
  void _loadGradesAndSections() {
    print('[TimetableWizardStep3Grades] Requesting grades and sections from BLoC');
    context.read<ExamTimetableBloc>().add(
          GetTimetableGradesAndSectionsEvent(tenantId: widget.wizardData.tenantId),
        );
  }

  @override
  Widget build(BuildContext context) {
    print('[TimetableWizardStep3Grades] build: tenantId=${widget.wizardData.tenantId}');
    return BlocBuilder<ExamTimetableBloc, ExamTimetableState>(
      builder: (context, state) {
        print('[TimetableWizardStep3Grades] BLoC state: ${state.runtimeType}');

        // Loading state
        if (state is ExamTimetableLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading grades and sections...'),
              ],
            ),
          );
        }

        // Error state
        if (state is ExamTimetableError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading grades and sections',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  state.message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadGradesAndSections,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Success state with grades and sections loaded
        if (state is TimetableGradesAndSectionsLoaded) {
          final gradesData = state.gradesData;
          final grades = gradesData.grades;

          print('[TimetableWizardStep3Grades] Grades loaded: ${grades.length}');

          if (grades.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No grades configured',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please configure grades in school settings first',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            );
          }

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

                  // Grades selection table
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const <DataColumn>[
                        DataColumn(label: Text('Grade')),
                        DataColumn(label: Text('Sections')),
                        DataColumn(label: Text('Selected')),
                        DataColumn(label: Text('Action')),
                      ],
                      rows: grades.map((grade) {
                        final gradeId = grade.gradeId as String;
                        final gradeNumber = grade.gradeNumber as int;
                        final sections = grade.sections as List<String>;
                        final selectedSections =
                            _selectedSectionsByGrade[gradeId]?.toList() ?? [];
                        final isAllSelected =
                            selectedSections.length == sections.length &&
                                sections.isNotEmpty;

                        return DataRow(
                          cells: <DataCell>[
                            DataCell(
                              Text('Grade $gradeNumber',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ),
                            DataCell(
                              Text(
                                sections.join(', '),
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DataCell(
                              Text(
                                selectedSections.isEmpty
                                    ? 'None'
                                    : selectedSections.join(', '),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: selectedSections.isEmpty
                                      ? Colors.grey[600]
                                      : Colors.green,
                                  fontWeight: selectedSections.isEmpty
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Tooltip(
                                    message: isAllSelected
                                        ? 'Deselect all'
                                        : 'Select all',
                                    child: IconButton(
                                      icon: Icon(
                                        isAllSelected
                                            ? Icons.check_box
                                            : Icons.check_box_outline_blank,
                                        color: isAllSelected
                                            ? Colors.green
                                            : Colors.grey,
                                        size: 18,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 32, minHeight: 32),
                                      onPressed: () =>
                                          _toggleGradeSelection(gradeId, sections,
                                              isAllSelected),
                                    ),
                                  ),
                                  Tooltip(
                                    message: 'Manage sections',
                                    child: IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 32, minHeight: 32),
                                      onPressed: () =>
                                          _showSectionSelector(context, gradeId,
                                              gradeNumber, sections),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                      headingRowColor:
                          WidgetStateProperty.all(Colors.blue[50]),
                      dataRowColor: WidgetStateProperty.all(Colors.grey[50]),
                      headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                      dataTextStyle: const TextStyle(fontSize: 11),
                      border: TableBorder(
                        borderRadius: BorderRadius.circular(4),
                        horizontalInside:
                            BorderSide(color: Colors.grey[300]!),
                        verticalInside: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                  ),

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

        // Initial/unknown state
        return const SizedBox();
      },
    );
  }

  /// Toggle selection of all sections for a grade
  void _toggleGradeSelection(
    String gradeId,
    List<String> sections,
    bool isCurrentlyAllSelected,
  ) {
    setState(() {
      _selectedSectionsByGrade.putIfAbsent(gradeId, () => {});
      if (isCurrentlyAllSelected) {
        // Deselect all sections
        _selectedSectionsByGrade[gradeId]!.clear();
      } else {
        // Select all sections
        _selectedSectionsByGrade[gradeId]!.addAll(sections);
      }
      _notifyChanges();
    });
  }

  /// Show section selector dialog
  void _showSectionSelector(
    BuildContext context,
    String gradeId,
    int gradeNumber,
    List<String> sections,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            final selectedSections =
                _selectedSectionsByGrade[gradeId]?.toList() ?? [];

            return AlertDialog(
              title: Text('Select Sections - Grade $gradeNumber'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: sections
                      .map(
                        (section) => CheckboxListTile(
                          title: Text('Section $section'),
                          value: selectedSections.contains(section),
                          onChanged: (checked) {
                            setState(
                              () {
                                if (checked ?? false) {
                                  selectedSections.add(section);
                                } else {
                                  selectedSections.remove(section);
                                }
                              },
                            );
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    this.setState(() {
                      _selectedSectionsByGrade[gradeId] =
                          selectedSections.toSet();
                      _notifyChanges();
                    });
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Get total selected count
  int _getSelectedCount() {
    int count = 0;
    for (final sections in _selectedSectionsByGrade.values) {
      count += sections.length;
    }
    return count;
  }

  /// Notify parent of changes
  void _notifyChanges() {
    final selections = <GradeSelection>[];

    // Get grade information from the loaded data
    // Note: In a full implementation, we'd have access to the full grade data
    // For now, we'll create selections based on what we have
    for (final gradeId in _selectedSectionsByGrade.keys) {
      final sections = _selectedSectionsByGrade[gradeId]?.toList() ?? [];
      if (sections.isNotEmpty) {
        // Extract grade number from gradeId or use as-is
        // In this case, we'll store it and let the parent parse it
        selections.add(
          GradeSelection(
            gradeId: gradeId,
            gradeName: 'Grade', // Will be updated with actual grade number
            sections: sections,
          ),
        );
      }
    }

    print('[TimetableWizardStep3Grades] Notifying parent of ${selections.length} grade selections');
    widget.onGradesSelected(selections);
  }
}
