import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/exam_timetable_wizard_bloc.dart';
import '../bloc/exam_timetable_wizard_event.dart';
import '../bloc/exam_timetable_wizard_state.dart';

/// Step 2 Widget: Schedule Subjects with Per-Grade Date/Time Assignment
///
/// Shows subjects available for SELECTED GRADES.
/// For each subject, allows assigning different dates/times per grade.
///
/// Example: Drawing can be scheduled on June 1 for Grades 1-3, June 2 for Grades 4-5
class WizardStep2ScheduleSubjects extends StatefulWidget {
  const WizardStep2ScheduleSubjects({Key? key}) : super(key: key);

  @override
  State<WizardStep2ScheduleSubjects> createState() =>
      _WizardStep2ScheduleSubjectsState();
}

class _WizardStep2ScheduleSubjectsState extends State<WizardStep2ScheduleSubjects> {
  // Tracks which subjects are expanded
  final Map<String, bool> _expandedSubjects = {};

  // Default time for all subjects
  TimeOfDay _defaultStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _defaultEndTime = const TimeOfDay(hour: 11, minute: 0);

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExamTimetableWizardBloc, ExamTimetableWizardState>(
      listener: (context, state) {
        if (state is WizardValidationErrorState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errors.join(', ')),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: BlocBuilder<ExamTimetableWizardBloc, ExamTimetableWizardState>(
        builder: (context, state) {
          if (state is! WizardStep2State) {
            return const SizedBox.shrink();
          }

          // DEBUG PRINTS FOR STEP 2

          // Count entries per grade
          final entriesPerGrade = <String, int>{};
          for (final entry in state.entries) {
            entriesPerGrade.update(entry.gradeId, (v) => v + 1, ifAbsent: () => 1);
          }
          for (final gradeId in state.selectedGradeIds) {
            final count = entriesPerGrade[gradeId] ?? 0;
            final gradeName = 'Grade ${state.gradeIdToNumberMap[gradeId] ?? '?'}';
          }

          // List all entries
          for (final entry in state.entries) {
            final gradeName = 'Grade ${state.gradeIdToNumberMap[entry.gradeId] ?? '?'}';
            final subject = state.subjects.where((s) => s.id == entry.subjectId).firstOrNull;
            final subjectName = subject?.name ?? 'Unknown';
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step header
                  Text(
                    'Step 2: Schedule Subjects',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Assign exam dates and times to each subject for each grade',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),

                  // Selected grades info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      border: Border.all(color: Colors.purple.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected Grades',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Colors.purple.shade700,
                                  fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: state.selectedGradeIds
                              .map((gradeId) {
                                // Get grade number from mapping, fallback to index
                                final gradeNumber = state.gradeIdToNumberMap[gradeId] ??
                                    (state.selectedGradeIds.indexOf(gradeId) + 1);
                                return Chip(
                                  label: Text('Grade $gradeNumber'),
                                  backgroundColor: Colors.purple.shade100,
                                  labelStyle: TextStyle(
                                      color: Colors.purple.shade700,
                                      fontWeight: FontWeight.w500),
                                );
                              })
                              .toList()
                              .take(5)
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Calendar range info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exam Period',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.blue.shade700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${state.selectedCalendar.plannedStartDate.toLocal().toString().split(' ')[0]} to ${state.selectedCalendar.plannedEndDate.toLocal().toString().split(' ')[0]}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Default Time Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Default Exam Time',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Start Time',
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: _defaultStartTime,
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _defaultStartTime = picked;
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.orange.shade300),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _defaultStartTime.format(context),
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'End Time',
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: _defaultEndTime,
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _defaultEndTime = picked;
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.orange.shade300),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _defaultEndTime.format(context),
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Loading state
                  if (state.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),

                  // Error state
                  if (state.error != null && !state.isLoading)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Error loading subjects',
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.error ?? 'Unknown error',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ],
                      ),
                    ),

                  // Subjects list with per-grade scheduling
                  if (state.subjects.isNotEmpty && !state.isLoading)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Subjects',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: state.allSubjectsAssigned()
                                    ? Colors.green.shade100
                                    : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${state.entries.length}/${state.subjects.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: state.allSubjectsAssigned()
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...state.subjects.map((subject) {
                          final gradesWithSubject =
                              state.subjectToGradesMap[subject.id] ?? [];

                          // Initialize expansion state
                          _expandedSubjects.putIfAbsent(
                              subject.id, () => false);

                          return SubjectScheduleCard(
                            subject: subject,
                            gradesWithSubject: gradesWithSubject,
                            gradeIdToNumberMap: state.gradeIdToNumberMap,
                            isExpanded:
                                _expandedSubjects[subject.id] ?? false,
                            onExpandChanged: (expanded) {
                              setState(() {
                                _expandedSubjects[subject.id] = expanded;
                              });
                            },
                            minDate:
                                state.selectedCalendar.plannedStartDate,
                            maxDate: state.selectedCalendar.plannedEndDate,
                            onGradeDateSelected:
                                (gradeId, date, _, __) {
                              // Use default times for all subjects
                              context
                                  .read<ExamTimetableWizardBloc>()
                                  .add(AssignSubjectDateEvent(
                                    subjectId: subject.id,
                                    gradeId: gradeId,
                                    examDate: date,
                                    startTime: _defaultStartTime,
                                    endTime: _defaultEndTime,
                                  ));
                            },
                            onRemove: () {
                              context
                                  .read<ExamTimetableWizardBloc>()
                                  .add(RemoveSubjectAssignmentEvent(
                                    subjectId: subject.id,
                                  ));
                            },
                          );
                        }),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // Progress indicator
                  if (!state.allSubjectsAssigned())
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Remaining subjects to assign:',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          ...state.getUnassignedSubjects().map((subject) =>
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  '• ${subject.name}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              )),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Subject schedule card with expandable per-grade scheduling
/// Shows which grades have this subject and allows individual date/time assignment per grade
class SubjectScheduleCard extends StatefulWidget {
  final dynamic subject;
  final List<String> gradesWithSubject;
  final Map<String, int> gradeIdToNumberMap;
  final bool isExpanded;
  final Function(bool) onExpandChanged;
  final DateTime minDate;
  final DateTime maxDate;
  final Function(String, DateTime, TimeOfDay, TimeOfDay) onGradeDateSelected;
  final VoidCallback onRemove;

  const SubjectScheduleCard({
    required this.subject,
    required this.gradesWithSubject,
    required this.gradeIdToNumberMap,
    required this.isExpanded,
    required this.onExpandChanged,
    required this.minDate,
    required this.maxDate,
    required this.onGradeDateSelected,
    required this.onRemove,
    Key? key,
  }) : super(key: key);

  @override
  State<SubjectScheduleCard> createState() => _SubjectScheduleCardState();
}

class _SubjectScheduleCardState extends State<SubjectScheduleCard> {
  // Track dates for each grade (times are handled at parent level)
  final Map<String, DateTime?> _gradeDates = {};

  // For bulk apply feature
  DateTime? _bulkApplyDate;

  /// Get all available dates from minDate to maxDate, excluding Sundays
  List<DateTime> _getAvailableDates() {
    final dates = <DateTime>[];
    var current = widget.minDate;

    while (current.isBefore(widget.maxDate) || current.isAtSameMomentAs(widget.maxDate)) {
      // 0 = Monday, 6 = Sunday (exclude Sunday)
      if (current.weekday != DateTime.sunday) {
        dates.add(current);
      }
      current = current.add(const Duration(days: 1));
    }

    return dates;
  }

  @override
  Widget build(BuildContext context) {
    final isAssigned =
        widget.gradesWithSubject.every((gradeId) => _gradeDates[gradeId] != null);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isAssigned ? Colors.green.shade50 : Colors.white,
        border: Border.all(
          color: isAssigned ? Colors.green.shade300 : Colors.grey.shade300,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with subject name and expand button
            InkWell(
              onTap: () {
                widget.onExpandChanged(!widget.isExpanded);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.subject.name ?? 'Subject',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.gradesWithSubject.length} grade(s)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isAssigned)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '✓ Complete',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Available grades preview (always shown)
            Text(
              'Grades:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: widget.gradesWithSubject
                  .map((gradeId) {
                    final gradeNumber = widget.gradeIdToNumberMap[gradeId] ??
                        (widget.gradesWithSubject.indexOf(gradeId) + 1);
                    final hasDate = _gradeDates[gradeId] != null;
                    return Chip(
                      label: Text('Grade $gradeNumber'),
                      backgroundColor: hasDate
                          ? Colors.green.shade100
                          : Colors.blue.shade100,
                      labelStyle: TextStyle(
                        color: hasDate
                            ? Colors.green.shade700
                            : Colors.blue.shade700,
                        fontSize: 11,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                    );
                  })
                  .toList(),
            ),
            const SizedBox(height: 12),

            // Expanded content: Per-grade date/time pickers
            if (widget.isExpanded)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 12),

                  // Bulk Apply Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      border: Border.all(color: Colors.purple.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Apply same date to all grades',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.purple.shade800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Date chips for bulk apply
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _getAvailableDates().map((date) {
                            final isSelected = _bulkApplyDate != null &&
                                _bulkApplyDate!.year == date.year &&
                                _bulkApplyDate!.month == date.month &&
                                _bulkApplyDate!.day == date.day;

                            return FilterChip(
                              label: Text(
                                '${date.day}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _bulkApplyDate = selected ? date : null;
                                });
                              },
                              backgroundColor: Colors.purple.shade100,
                              selectedColor: Colors.purple.shade300,
                              checkmarkColor:
                                  isSelected ? Colors.purple.shade800 : null,
                              showCheckmark: true,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        // Apply button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _bulkApplyDate == null
                                ? null
                                : () {
                              // Apply to all grades
                              for (final gradeId in widget.gradesWithSubject) {
                                setState(() {
                                  _gradeDates[gradeId] = _bulkApplyDate;
                                });
                                // Trigger callback for each grade
                                widget.onGradeDateSelected(
                                  gradeId,
                                  _bulkApplyDate!,
                                  const TimeOfDay(hour: 9, minute: 0),
                                  const TimeOfDay(hour: 11, minute: 0),
                                );
                              }
                              // Reset bulk selection
                              setState(() {
                                _bulkApplyDate = null;
                              });
                            },
                            icon: const Icon(Icons.done_all, size: 16),
                            label: const Text('Apply to All Grades'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Or set individually:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...widget.gradesWithSubject.map((gradeId) {
                    final gradeNumber = widget.gradeIdToNumberMap[gradeId] ??
                        (widget.gradesWithSubject.indexOf(gradeId) + 1);
                    final selectedDate = _gradeDates[gradeId];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border:
                            Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Grade $gradeNumber',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Date chips (excluding Sundays)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _getAvailableDates().map((date) {
                              final isSelected = selectedDate != null &&
                                  selectedDate.year == date.year &&
                                  selectedDate.month == date.month &&
                                  selectedDate.day == date.day;

                              return FilterChip(
                                label: Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _gradeDates[gradeId] = date;
                                  });
                                  // Auto-trigger date selection
                                  widget.onGradeDateSelected(
                                    gradeId,
                                    date,
                                    const TimeOfDay(hour: 9, minute: 0),
                                    const TimeOfDay(hour: 11, minute: 0),
                                  );
                                },
                                backgroundColor: Colors.blue.shade50,
                                selectedColor: Colors.green.shade200,
                                checkmarkColor:
                                    isSelected ? Colors.green.shade700 : null,
                                showCheckmark: true,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Selected: ${selectedDate != null ? selectedDate.toString().split(' ')[0] : 'None'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  // Clear button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: widget.onRemove,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Clear All Assignments'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
