import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/exam_calendar_entity.dart';
import '../../domain/entities/exam_timetable_entity.dart';
import '../../domain/entities/exam_timetable_entry_entity.dart';
import '../bloc/exam_timetable_bloc.dart';
import '../bloc/exam_timetable_event.dart';
import '../bloc/exam_timetable_state.dart';
import '../widgets/timetable_wizard_step1_calendar.dart';
import '../widgets/timetable_wizard_step2_info.dart';
import '../widgets/timetable_wizard_step3_grades.dart';
import '../widgets/timetable_wizard_step4_entries.dart';
import '../widgets/timetable_wizard_step5_review.dart';

/// Multi-step wizard for creating exam timetables
///
/// Guides users through a 5-step process:
/// 1. Select exam calendar
/// 2. Enter timetable basic info
/// 3. Select grades and sections
/// 4. Add exam entries
/// 5. Review and submit
///
/// This is typically accessed by admins after setting up exam calendars.
class ExamTimetableCreateWizardPage extends StatefulWidget {
  final String tenantId;
  final String? initialCalendarId;

  const ExamTimetableCreateWizardPage({
    required this.tenantId,
    this.initialCalendarId,
    super.key,
  });

  @override
  State<ExamTimetableCreateWizardPage> createState() =>
      _ExamTimetableCreateWizardPageState();
}

class _ExamTimetableCreateWizardPageState
    extends State<ExamTimetableCreateWizardPage> {
  int _currentStep = 0;

  /// Wizard data holder
  late WizardData _wizardData;

  @override
  void initState() {
    super.initState();
    _wizardData = WizardData(
      tenantId: widget.tenantId,
      initialCalendarId: widget.initialCalendarId,
    );

    // Load exam calendars for step 1
    context.read<ExamTimetableBloc>().add(
          GetExamCalendarsEvent(tenantId: widget.tenantId),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getStepTitle()),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                'Step ${_currentStep + 1}/5',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
      body: BlocListener<ExamTimetableBloc, ExamTimetableState>(
        listener: (context, state) {
          if (state is ExamTimetableCreated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Timetable created successfully'),
                backgroundColor: Colors.green,
              ),
            );
            // Navigate back to timetable list
            Navigator.of(context).pop();
          } else if (state is ExamTimetableError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<ExamTimetableBloc, ExamTimetableState>(
          builder: (context, state) {
            return Column(
              children: [
                // Progress indicator
                _buildProgressIndicator(),
                // Step content
                Expanded(
                  child: _buildStepContent(context, state),
                ),
                // Navigation buttons
                _buildNavigationButtons(context, state),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Build progress indicator
  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
              final isCompleted = index < _currentStep;
              final isCurrent = index == _currentStep;

              return Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted || isCurrent
                          ? Colors.blue
                          : Colors.grey[300],
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check, color: Colors.white)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color:
                                    isCurrent ? Colors.white : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getStepLabel(index),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 5,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  /// Build step content
  Widget _buildStepContent(BuildContext context, ExamTimetableState state) {
    switch (_currentStep) {
      case 0:
        return TimetableWizardStep1Calendar(
          wizardData: _wizardData,
          onCalendarSelected: (calendar) {
            setState(() {
              _wizardData.selectedCalendar = calendar;
            });
          },
          state: state,
        );
      case 1:
        return TimetableWizardStep2Info(
          wizardData: _wizardData,
          onDataChanged: (examName, examType, academicYear) {
            setState(() {
              _wizardData.examName = examName;
              _wizardData.examType = examType;
              _wizardData.academicYear = academicYear;
            });
          },
        );
      case 2:
        return TimetableWizardStep3Grades(
          wizardData: _wizardData,
          onGradesSelected: (grades) {
            setState(() {
              _wizardData.selectedGrades = grades;
            });
          },
        );
      case 3:
        return TimetableWizardStep4Entries(
          wizardData: _wizardData,
          onEntriesChanged: (entries) {
            setState(() {
              _wizardData.entries = entries;
            });
          },
        );
      case 4:
        return TimetableWizardStep5Review(
          wizardData: _wizardData,
        );
      default:
        return const SizedBox();
    }
  }

  /// Build navigation buttons
  Widget _buildNavigationButtons(
    BuildContext context,
    ExamTimetableState state,
  ) {
    final isLoading = state is ExamTimetableLoading;
    final isLastStep = _currentStep == 4;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          ElevatedButton(
            onPressed: isLoading || _currentStep == 0
                ? null
                : () {
                    setState(() {
                      _currentStep--;
                    });
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
            ),
            child: const Text('Back'),
          ),
          // Next/Submit button
          ElevatedButton(
            onPressed: isLoading ? null : _handleNextOrSubmit,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isLastStep ? 'Create Timetable' : 'Next'),
          ),
        ],
      ),
    );
  }

  /// Handle next step or submit
  void _handleNextOrSubmit() {
    // Validate current step
    if (!_validateCurrentStep()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
      });
    } else {
      // Submit the timetable
      _submitTimetable();
    }
  }

  /// Validate current step
  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _wizardData.selectedCalendar != null;
      case 1:
        return _wizardData.examName.isNotEmpty &&
            _wizardData.examType.isNotEmpty &&
            _wizardData.academicYear.isNotEmpty;
      case 2:
        return _wizardData.selectedGrades.isNotEmpty;
      case 3:
        return _wizardData.entries.isNotEmpty;
      case 4:
        return true; // Review step is always valid
      default:
        return true;
    }
  }

  /// Submit timetable creation
  void _submitTimetable() {
    final now = DateTime.now();
    final timetableId = DateTime.now().millisecondsSinceEpoch.toString();

    final timetable = ExamTimetableEntity(
      id: timetableId,
      tenantId: widget.tenantId,
      createdBy: 'current-user-id', // TODO: Get from auth context
      examCalendarId: _wizardData.selectedCalendar?.id,
      examName: _wizardData.examName,
      examType: _wizardData.examType,
      academicYear: _wizardData.academicYear,
      status: 'draft',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    context.read<ExamTimetableBloc>().add(
          CreateExamTimetableEvent(timetable: timetable),
        );

    // Also create all entries
    for (final entry in _wizardData.entries) {
      context.read<ExamTimetableBloc>().add(
            AddExamTimetableEntryEvent(entry: entry),
          );
    }
  }

  /// Get step title
  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Select Exam Calendar';
      case 1:
        return 'Timetable Information';
      case 2:
        return 'Select Grades & Sections';
      case 3:
        return 'Add Exam Entries';
      case 4:
        return 'Review & Submit';
      default:
        return 'Create Timetable';
    }
  }

  /// Get step label for progress indicator
  String _getStepLabel(int index) {
    switch (index) {
      case 0:
        return 'Calendar';
      case 1:
        return 'Info';
      case 2:
        return 'Grades';
      case 3:
        return 'Entries';
      case 4:
        return 'Review';
      default:
        return '';
    }
  }
}

/// Data holder for wizard state
class WizardData {
  final String tenantId;
  final String? initialCalendarId;

  ExamCalendarEntity? selectedCalendar;
  String examName = '';
  String examType = '';
  String academicYear = '';
  List<GradeSelection> selectedGrades = [];
  List<ExamTimetableEntryEntity> entries = [];

  WizardData({
    required this.tenantId,
    this.initialCalendarId,
  });
}

/// Grade selection model
class GradeSelection {
  final String gradeId;
  final String gradeName;
  final List<String> sections;

  GradeSelection({
    required this.gradeId,
    required this.gradeName,
    required this.sections,
  });
}
