import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/exam_timetable_wizard_bloc.dart';
import '../bloc/exam_timetable_wizard_event.dart';
import '../bloc/exam_timetable_wizard_state.dart';

/// Step 3 Widget: Assign Subjects to Exam Dates (Subject-First Approach)
///
/// Shows subjects available for SELECTED GRADES only.
/// For each subject, displays which grades have it.
/// User assigns ONE date per subject that applies to all grades having that subject.
class WizardStep3Schedule extends StatefulWidget {
  const WizardStep3Schedule({Key? key}) : super(key: key);

  @override
  State<WizardStep3Schedule> createState() => _WizardStep3ScheduleState();
}

class _WizardStep3ScheduleState extends State<WizardStep3Schedule> {
  @override
  Widget build(BuildContext context) {
    return BlocListener<ExamTimetableWizardBloc, ExamTimetableWizardState>(
      listener: (context, state) {
        print('[Step3Schedule] BlocListener: state type = ${state.runtimeType}');
        if (state is WizardValidationErrorState) {
          print('[Step3Schedule] Validation error: ${state.errors}');
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
          print('[Step3Schedule] BlocBuilder: state type = ${state.runtimeType}');
          if (state is! WizardStep3State) {
            print('[Step3Schedule] Not WizardStep3State, returning SizedBox.shrink()');
            return const SizedBox.shrink();
          }

          print('[Step3Schedule] ========== STEP 3 STATE DEBUG ==========');
          print('[Step3Schedule] selectedGradeIds: ${state.selectedGradeIds.length}');
          print('[Step3Schedule] subjects available: ${state.subjects.length}');
          print('[Step3Schedule] entries assigned: ${state.entries.length}');
          print('[Step3Schedule] gradeSectionMapping keys: ${state.gradeSectionMapping.keys.length}');
          print('[Step3Schedule] sectionDetailsMap keys: ${state.sectionDetailsMap.keys.length}');
          print('[Step3Schedule] isLoading: ${state.isLoading}');
          print('[Step3Schedule] error: ${state.error}');
          print('[Step3Schedule] calendar: ${state.selectedCalendar.examName}');
          print('[Step3Schedule] ========================================');

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step header
                  Text(
                    'Step 3: Schedule Subjects',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Assign exam dates to subjects for selected grades',
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
                                // Get grade name from gradeSectionMapping
                                final gradeName = state.gradeSectionMapping
                                    .entries
                                    .where((e) => e.value
                                        .any((sectionId) {
                                          final details = state
                                              .sectionDetailsMap[sectionId];
                                          return details?['gradeId'] == gradeId;
                                        }))
                                    .isNotEmpty
                                    ? 'Grade ${state.selectedGradeIds.indexOf(gradeId) + 1}'
                                    : 'Grade';
                                return Chip(
                                  label: Text(gradeName),
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

                  // Subjects list
                  if (state.subjects.isNotEmpty && !state.isLoading)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
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
                          print('[Step3Schedule] Processing subject: ${subject.name} (ID: ${subject.id})');
                          final entry = state.getEntryForSubject(subject.id);
                          final isAssigned = entry != null;
                          print('[Step3Schedule]   → isAssigned: $isAssigned');
                          if (isAssigned) {
                            print('[Step3Schedule]   → assigned date: ${entry.examDate}');
                          }

                          // Find which grades have this subject using the subject-to-grades mapping
                          final gradesWithSubject = state.subjectToGradesMap[subject.id] ?? [];
                          print('[Step3Schedule]   → available in ${gradesWithSubject.length} grades: ${gradesWithSubject.join(', ')}');

                          return SubjectAssignmentCard(
                            subject: subject,
                            entry: entry,
                            isAssigned: isAssigned,
                            gradesWithSubject: gradesWithSubject,
                            gradeIdToNumberMap: state.gradeIdToNumberMap,
                            minDate:
                                state.selectedCalendar.plannedStartDate,
                            maxDate: state.selectedCalendar.plannedEndDate,
                            onDateSelected: (date) {
                              context
                                  .read<ExamTimetableWizardBloc>()
                                  .add(AssignSubjectDateEvent(
                                    subjectId: subject.id,
                                    examDate: date,
                                    startTime:
                                        const TimeOfDay(hour: 9, minute: 0),
                                    endTime:
                                        const TimeOfDay(hour: 11, minute: 0),
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

/// Individual subject assignment card (Subject-First approach)
/// Shows which grades have this subject and allows date assignment
class SubjectAssignmentCard extends StatelessWidget {
  final dynamic subject;
  final dynamic entry;
  final bool isAssigned;
  final List<String> gradesWithSubject;
  final Map<String, int> gradeIdToNumberMap;
  final DateTime minDate;
  final DateTime maxDate;
  final Function(DateTime) onDateSelected;
  final VoidCallback onRemove;

  const SubjectAssignmentCard({
    required this.subject,
    required this.entry,
    required this.isAssigned,
    required this.gradesWithSubject,
    required this.gradeIdToNumberMap,
    required this.minDate,
    required this.maxDate,
    required this.onDateSelected,
    required this.onRemove,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('[SubjectCard] Building card for: ${subject.name} (${gradesWithSubject.length} grades)');

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
            // Subject name and status row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    subject.name ?? 'Subject',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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
                      '✓ Assigned',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Available grades
            Text(
              'Available in:',
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
              children: gradesWithSubject
                  .map((gradeId) {
                    // Get the grade number from the mapping, fallback to index if not found
                    final gradeNumber = gradeIdToNumberMap[gradeId] ?? (gradesWithSubject.indexOf(gradeId) + 1);
                    return Chip(
                      label: Text('Grade $gradeNumber'),
                      backgroundColor: Colors.blue.shade100,
                      labelStyle: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 11,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    );
                  })
                  .toList(),
            ),
            const SizedBox(height: 12),

            // Date/time info and actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isAssigned)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scheduled for:',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.examDate.toLocal().toString().split(' ')[0],
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!isAssigned)
                  Expanded(
                    child: Text(
                      'Select a date to schedule this subject',
                      style: TextStyle(
                        color: Colors.orange.shade600,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                // Action buttons
                if (isAssigned)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, size: 18, color: Colors.blue.shade700),
                        onPressed: () {
                          print('[SubjectCard] [UI] Edit button clicked for ${subject.name}');
                          _showDatePicker(context);
                        },
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        tooltip: 'Change date',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.red),
                        onPressed: () {
                          print('[SubjectCard] [UI] Remove button clicked for ${subject.name}');
                          onRemove();
                        },
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        tooltip: 'Remove',
                      ),
                    ],
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () {
                      print('[SubjectCard] [UI] Select Date button clicked for ${subject.name}');
                      _showDatePicker(context);
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Select Date'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDatePicker(BuildContext context) async {
    print('[SubjectCard] Opening date picker for ${subject.name}');
    print('[SubjectCard]   → min date: $minDate, max date: $maxDate');

    final picked = await showDatePicker(
      context: context,
      initialDate: minDate,
      firstDate: minDate,
      lastDate: maxDate,
    );

    if (picked != null) {
      print('[SubjectCard] Date selected: $picked for subject ${subject.name}');
      print('[SubjectCard]   → will create entries for ${gradesWithSubject.length} grades');
      onDateSelected(picked);
    } else {
      print('[SubjectCard] Date picker cancelled for ${subject.name}');
    }
  }
}
