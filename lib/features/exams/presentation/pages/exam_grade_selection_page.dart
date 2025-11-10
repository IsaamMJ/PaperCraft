import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/exam_calendar_bloc.dart';
import '../bloc/exam_calendar_event.dart';
import '../bloc/exam_calendar_state.dart';
import '../../domain/entities/exam_calendar.dart';
import '../../../catalog/presentation/bloc/grade_bloc.dart' as grade_bloc;
import '../../../catalog/domain/entities/grade_entity.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';

/// Simple page to select which grades participate in an exam calendar
class ExamGradeSelectionPage extends StatefulWidget {
  final String tenantId;

  const ExamGradeSelectionPage({
    required this.tenantId,
    super.key,
  });

  @override
  State<ExamGradeSelectionPage> createState() => _ExamGradeSelectionPageState();
}

class _ExamGradeSelectionPageState extends State<ExamGradeSelectionPage> {
  ExamCalendar? selectedCalendar;
  Set<String> selectedGradeIds = {};
  List<GradeEntity> allGrades = [];

  @override
  void initState() {
    super.initState();
    print('[ExamGradeSelection] Loading exam calendars and grades');

    // Load calendars
    context.read<ExamCalendarBloc>().add(
      LoadExamCalendarsEvent(
        tenantId: widget.tenantId,
        academicYear: '',
      ),
    );

    // Load grades
    context.read<grade_bloc.GradeBloc>().add(const grade_bloc.LoadGrades());
  }

  void _selectGrade(String gradeId) {
    setState(() {
      if (selectedGradeIds.contains(gradeId)) {
        selectedGradeIds.remove(gradeId);
        print('[ExamGradeSelection] Deselected grade: $gradeId');
      } else {
        selectedGradeIds.add(gradeId);
        print('[ExamGradeSelection] Selected grade: $gradeId');
      }
    });
  }

  void _saveSelection() {
    if (selectedCalendar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an exam calendar')),
      );
      return;
    }

    if (selectedGradeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one grade')),
      );
      return;
    }

    print('[ExamGradeSelection] Saving: Calendar=${selectedCalendar!.examName}, Grades=$selectedGradeIds');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${selectedGradeIds.length} grade(s) assigned to ${selectedCalendar!.examName}'),
        backgroundColor: Colors.green,
      ),
    );

    // TODO: Save to database
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Assign Grades to Exam'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: BlocBuilder<grade_bloc.GradeBloc, grade_bloc.GradeState>(
        builder: (context, state) {
          if (state is grade_bloc.GradesLoaded) {
            allGrades = state.grades;
            print('[ExamGradeSelection] Loaded ${state.grades.length} grades');
          }

          return Column(
          children: [
            // Step 1: Select Calendar
            Padding(
              padding: EdgeInsets.all(UIConstants.paddingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step 1: Select Exam Calendar',
                    style: TextStyle(
                      fontSize: UIConstants.fontSizeLarge,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: UIConstants.spacing12),
                  BlocBuilder<ExamCalendarBloc, ExamCalendarState>(
                    builder: (context, state) {
                      if (state is ExamCalendarLoading) {
                        return const CircularProgressIndicator();
                      }

                      if (state is ExamCalendarLoaded) {
                        return DropdownButton<ExamCalendar>(
                          isExpanded: true,
                          hint: const Text('Select exam calendar'),
                          value: selectedCalendar,
                          onChanged: (calendar) {
                            setState(() {
                              selectedCalendar = calendar;
                              selectedGradeIds.clear();
                            });
                            print('[ExamGradeSelection] Selected calendar: ${calendar?.examName}');
                          },
                          items: state.calendars
                              .map((cal) => DropdownMenuItem(
                                value: cal,
                                child: Text(cal.examName),
                              ))
                              .toList(),
                        );
                      }

                      if (state is ExamCalendarEmpty) {
                        return Container(
                          padding: EdgeInsets.all(UIConstants.paddingMedium),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            border: Border.all(color: Colors.orange),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('No exam calendars found. Create one first.'),
                        );
                      }

                      return const Text('Error loading calendars');
                    },
                  ),
                ],
              ),
            ),

            // Step 2: Select Grades
            if (selectedCalendar != null)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(UIConstants.paddingLarge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step 2: Select Grades',
                        style: TextStyle(
                          fontSize: UIConstants.fontSizeLarge,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: UIConstants.spacing12),
                      if (allGrades.isEmpty)
                        const Center(child: Text('No grades found'))
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: allGrades.length,
                            itemBuilder: (context, index) {
                              final grade = allGrades[index];
                              final isSelected = selectedGradeIds.contains(grade.id);

                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (_) => _selectGrade(grade.id),
                                title: Text(
                                  'Grade ${grade.gradeNumber}',
                                  style: TextStyle(
                                    fontSize: UIConstants.fontSizeMedium,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                                activeColor: AppColors.primary,
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.all(UIConstants.paddingLarge),
        child: ElevatedButton(
          onPressed: selectedCalendar == null || selectedGradeIds.isEmpty ? null : _saveSelection,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: UIConstants.paddingMedium),
            backgroundColor: selectedCalendar == null || selectedGradeIds.isEmpty
                ? Colors.grey
                : AppColors.primary,
          ),
          child: Text(
            'Save Selection (${selectedGradeIds.length} grade${selectedGradeIds.length == 1 ? '' : 's'})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
