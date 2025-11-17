import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/exam_timetable_wizard_bloc.dart';
import '../bloc/exam_timetable_wizard_event.dart';
import '../bloc/exam_timetable_wizard_state.dart';

/// Step 2 Widget: Select Grades for Exam
///
/// Displays all available grades and allows user to select
/// which grades will participate in the selected exam.
class WizardStep2Grades extends StatefulWidget {
  const WizardStep2Grades({Key? key}) : super(key: key);

  @override
  State<WizardStep2Grades> createState() => _WizardStep2GradesState();
}

class _WizardStep2GradesState extends State<WizardStep2Grades> {
  final Set<String> _selectedGradeIds = {};

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExamTimetableWizardBloc, ExamTimetableWizardState>(
      builder: (context, state) {

        if (state is! WizardStep2State) {
          return const SizedBox.shrink();
        }


        // Initialize selected grades from state
        if (_selectedGradeIds.isEmpty &&
            state.selectedGradeIds.isNotEmpty) {
          _selectedGradeIds.addAll(state.selectedGradeIds);
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step header
                Text(
                  'Step 2: Select Grades',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select which grades will participate in ${state.selectedCalendar.examName}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

                // Calendar summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${state.selectedCalendar.examName} (${state.selectedCalendar.plannedStartDate.toLocal().toString().split(' ')[0]} - ${state.selectedCalendar.plannedEndDate.toLocal().toString().split(' ')[0]})',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
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
                          'Error loading grades',
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

                // Grades list
                if (state.availableGrades.isNotEmpty && !state.isLoading)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Grades',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...state.availableGrades.map((grade) {
                        final isSelected = _selectedGradeIds.contains(grade.id);

                        return CheckboxListTile(
                          key: ValueKey(grade.id),
                          title: Text(grade.displayName),
                          subtitle: Text('ID: ${grade.id.substring(0, 8)}'),
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedGradeIds.add(grade.id);
                              } else {
                                _selectedGradeIds.remove(grade.id);
                              }

                              // Notify BLoC of the updated selection
                              context.read<ExamTimetableWizardBloc>().add(
                                    UpdateUserGradeSelectionEvent(
                                      selectedGradeSectionIds: List.from(_selectedGradeIds),
                                    ),
                                  );
                            });
                          },
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          tileColor: isSelected
                              ? Colors.blue.shade50
                              : Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.blue.shade200
                                  : Colors.transparent,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),

                const SizedBox(height: 24),

                // Selection summary
                if (_selectedGradeIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.green.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${_selectedGradeIds.length} grade${_selectedGradeIds.length > 1 ? 's' : ''} selected',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
