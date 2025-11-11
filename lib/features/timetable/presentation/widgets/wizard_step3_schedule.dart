import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/exam_timetable_wizard_bloc.dart';
import '../bloc/exam_timetable_wizard_event.dart';
import '../bloc/exam_timetable_wizard_state.dart';

/// Step 3 Widget: Assign Subjects to Exam Dates
///
/// Displays all subjects and allows user to assign each subject
/// to an exam date. Dates are constrained to the calendar range.
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
          if (state is! WizardStep3State) {
            return const SizedBox.shrink();
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step header
                  Text(
                    'Step 3: Assign Subjects to Dates',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a date for each subject within the exam period',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),

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
                          '${state.selectedCalendar.plannedStartDate.toLocal().toString().split(' ')[0]} - ${state.selectedCalendar.plannedEndDate.toLocal().toString().split(' ')[0]}',
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
                          final entry = state.getEntryForSubject(subject.id);
                          final isAssigned = entry != null;

                          return SubjectAssignmentCard(
                            subject: subject,
                            entry: entry,
                            isAssigned: isAssigned,
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

/// Individual subject assignment card
class SubjectAssignmentCard extends StatelessWidget {
  final dynamic subject;
  final dynamic entry;
  final bool isAssigned;
  final DateTime minDate;
  final DateTime maxDate;
  final Function(DateTime) onDateSelected;
  final VoidCallback onRemove;

  const SubjectAssignmentCard({
    required this.subject,
    required this.entry,
    required this.isAssigned,
    required this.minDate,
    required this.maxDate,
    required this.onDateSelected,
    required this.onRemove,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isAssigned ? Colors.green.shade50 : Colors.white,
        border: Border.all(
          color: isAssigned ? Colors.green.shade200 : Colors.grey.shade200,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.name ?? 'Subject',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  if (isAssigned)
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          entry.examDate
                              .toLocal()
                              .toString()
                              .split(' ')[0],
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  if (!isAssigned)
                    Text(
                      'Not assigned',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isAssigned)
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _showDatePicker(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            if (isAssigned)
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Colors.red),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            if (!isAssigned)
              ElevatedButton(
                onPressed: () => _showDatePicker(context),
                child: const Text('Select'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: minDate,
      firstDate: minDate,
      lastDate: maxDate,
    );

    if (picked != null) {
      onDateSelected(picked);
    }
  }
}
