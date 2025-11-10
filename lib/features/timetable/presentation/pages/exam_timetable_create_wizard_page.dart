import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:papercraft/features/authentication/domain/services/user_state_service.dart';
import '../../domain/entities/exam_calendar_entity.dart';
import '../../domain/entities/exam_timetable_entity.dart';
import '../../domain/entities/exam_timetable_entry_entity.dart';
import '../bloc/exam_timetable_bloc.dart';
import '../bloc/exam_timetable_event.dart';
import '../bloc/exam_timetable_state.dart';
import '../widgets/timetable_wizard_step1_calendar.dart';
import '../widgets/timetable_wizard_step3_grades.dart';
import '../widgets/timetable_wizard_step4_entries.dart';

/// Multi-step wizard for creating exam timetables
///
/// Guides users through a 3-step process:
/// 1. Select exam calendar (auto-populates exam name, type, academic year)
/// 2. Select grades and sections
/// 3. Add exam entries and submit
///
/// Academic year is automatically fetched from UserStateService.
/// Exam name and type are auto-populated from the selected calendar.
/// No manual data re-entry needed - everything is auto-derived from calendar.
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
    print('[ExamTimetableCreateWizard] initState: tenantId=${widget.tenantId}');
    _wizardData = WizardData(
      tenantId: widget.tenantId,
      initialCalendarId: widget.initialCalendarId,
    );
    print('[ExamTimetableCreateWizard] Created WizardData object: hash=${_wizardData.hashCode}, selectedCalendar=${_wizardData.selectedCalendar?.examName ?? 'null'}');

    // Load exam calendars for step 1
    print('[ExamTimetableCreateWizard] Loading exam calendars...');
    context.read<ExamTimetableBloc>().add(
          GetExamCalendarsEvent(tenantId: widget.tenantId),
        );
  }

  @override
  Widget build(BuildContext context) {
    print('[ExamTimetableCreateWizard] build() called: _wizardData hash=${_wizardData.hashCode}, selectedCalendar=${_wizardData.selectedCalendar?.examName ?? 'null'}, currentStep=$_currentStep');
    return Scaffold(
      appBar: AppBar(
        title: Text(_getStepTitle()),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                'Step ${_currentStep + 1}/3',
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
            children: List.generate(3, (index) {
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
              value: (_currentStep + 1) / 3,
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
            print('[ExamTimetableCreateWizard] Calendar selected: ${calendar.examName}');
            print('[ExamTimetableCreateWizard] Calendar object: id=${calendar.id}, examName=${calendar.examName}');
            try {
              final userStateService = GetIt.instance<UserStateService>();
              print('[ExamTimetableCreateWizard] Retrieved UserStateService successfully from GetIt');
              setState(() {
                print('[ExamTimetableCreateWizard] Inside setState - Before assignment: selectedCalendar=${_wizardData.selectedCalendar?.examName ?? 'null'}');
                _wizardData.selectedCalendar = calendar;
                print('[ExamTimetableCreateWizard] Inside setState - After assignment: selectedCalendar=${_wizardData.selectedCalendar?.examName ?? 'null'}');
                // Auto-populate from calendar and UserStateService
                _wizardData.examName = calendar.examName;
                _wizardData.examType = calendar.examType;
                _wizardData.academicYear = userStateService.currentAcademicYear;
                print('[ExamTimetableCreateWizard] Inside setState - After auto-populate: examName=${_wizardData.examName}, examType=${_wizardData.examType}, academicYear=${_wizardData.academicYear}, selectedCalendar=${_wizardData.selectedCalendar?.examName ?? 'null'}');
              });
              print('[ExamTimetableCreateWizard] After setState complete: selectedCalendar=${_wizardData.selectedCalendar?.examName ?? 'null'}');
            } catch (e) {
              print('[ExamTimetableCreateWizard] ERROR reading UserStateService: $e');
              print('[ExamTimetableCreateWizard] Stack trace: ${StackTrace.current}');
            }
          },
          state: state,
        );
      case 1:
        return TimetableWizardStep3Grades(
          wizardData: _wizardData,
          onGradesSelected: (grades) {
            print('[ExamTimetableCreateWizard] Grades selected: ${grades.length} grades');
            setState(() {
              _wizardData.selectedGrades = grades;
              print('[ExamTimetableCreateWizard] Updated _wizardData.selectedGrades: ${_wizardData.selectedGrades.length}');
            });
          },
        );
      case 2:
        return TimetableWizardStep4Entries(
          wizardData: _wizardData,
          onEntriesChanged: (entries) {
            print('[ExamTimetableCreateWizard] Entries changed: ${entries.length} entries');
            setState(() {
              _wizardData.entries = entries;
              print('[ExamTimetableCreateWizard] Updated _wizardData.entries: ${_wizardData.entries.length}');
            });
          },
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
    final isLastStep = _currentStep == 2;

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
    print('[ExamTimetableCreateWizard] _handleNextOrSubmit: currentStep=$_currentStep');
    print('[ExamTimetableCreateWizard] Before validation - _wizardData object hash: ${_wizardData.hashCode}');
    print('[ExamTimetableCreateWizard] Before validation - selectedCalendar: ${_wizardData.selectedCalendar?.examName ?? 'null'}');
    print('[ExamTimetableCreateWizard] Before validation - examName: ${_wizardData.examName}');
    print('[ExamTimetableCreateWizard] Before validation - examType: ${_wizardData.examType}');
    print('[ExamTimetableCreateWizard] Before validation - academicYear: ${_wizardData.academicYear}');
    // Validate current step
    if (!_validateCurrentStep()) {
      print('[ExamTimetableCreateWizard] Validation failed for step $_currentStep');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_currentStep < 2) {
      print('[ExamTimetableCreateWizard] Moving to next step: $_currentStep -> ${_currentStep + 1}');
      setState(() {
        _currentStep++;
      });
    } else {
      // Submit the timetable
      print('[ExamTimetableCreateWizard] Submitting timetable...');
      _submitTimetable();
    }
  }

  /// Validate current step
  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        final isValid = _wizardData.selectedCalendar != null;
        print('[ExamTimetableCreateWizard] Step 0 validation: selectedCalendar=${_wizardData.selectedCalendar?.examName ?? 'null'}, isValid=$isValid');
        return isValid;
      case 1:
        final isValid = _wizardData.selectedGrades.isNotEmpty;
        print('[ExamTimetableCreateWizard] Step 1 validation: selectedGrades=${_wizardData.selectedGrades.length}, isValid=$isValid');
        return isValid;
      case 2:
        final isValid = _wizardData.entries.isNotEmpty;
        print('[ExamTimetableCreateWizard] Step 2 validation: entries=${_wizardData.entries.length}, isValid=$isValid');
        return isValid;
      default:
        return true;
    }
  }

  /// Submit timetable creation
  void _submitTimetable() {
    print('[ExamTimetableCreateWizard] _submitTimetable: Building timetable entity');
    final now = DateTime.now();
    final timetableId = DateTime.now().millisecondsSinceEpoch.toString();

    print('[ExamTimetableCreateWizard] Timetable ID: $timetableId');
    print('[ExamTimetableCreateWizard] Exam Name: ${_wizardData.examName}');
    print('[ExamTimetableCreateWizard] Exam Type: ${_wizardData.examType}');
    print('[ExamTimetableCreateWizard] Academic Year: ${_wizardData.academicYear}');
    print('[ExamTimetableCreateWizard] Selected Calendar: ${_wizardData.selectedCalendar?.id}');
    print('[ExamTimetableCreateWizard] Selected Grades: ${_wizardData.selectedGrades.length}');
    print('[ExamTimetableCreateWizard] Entries: ${_wizardData.entries.length}');

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

    print('[ExamTimetableCreateWizard] Creating timetable entity...');
    context.read<ExamTimetableBloc>().add(
          CreateExamTimetableEvent(timetable: timetable),
        );

    // Also create all entries
    print('[ExamTimetableCreateWizard] Adding ${_wizardData.entries.length} entries...');
    for (final entry in _wizardData.entries) {
      print('[ExamTimetableCreateWizard] Adding entry: ${entry.id}');
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
        return 'Select Grades & Sections';
      case 2:
        return 'Add Exam Entries';
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
        return 'Grades';
      case 2:
        return 'Entries';
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
