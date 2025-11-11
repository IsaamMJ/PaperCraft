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
import '../widgets/timetable_wizard_step4_schedule.dart';

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
        print('[ExamTimetableCreateWizard] Building Step 1 with callback');
        return TimetableWizardStep1Calendar(
          wizardData: _wizardData,
          onCalendarSelected: (calendar) {
            print('[ExamTimetableCreateWizard] CALLBACK INVOKED! Calendar selected: ${calendar.examName}');
            print('[ExamTimetableCreateWizard] Calendar object: id=${calendar.id}, examName=${calendar.examName}, examType=${calendar.examType}');
            try {
              final userStateService = GetIt.instance<UserStateService>();
              print('[ExamTimetableCreateWizard] Retrieved UserStateService successfully from GetIt');
              setState(() {
                print('[ExamTimetableCreateWizard] Inside setState - Before assignment: selectedCalendar=${_wizardData.selectedCalendar?.examName ?? 'null'}');
                _wizardData.selectedCalendar = calendar;
                print('[ExamTimetableCreateWizard] Inside setState - After assignment: selectedCalendar=${_wizardData.selectedCalendar?.examName ?? 'null'}');
                // Auto-populate from calendar and UserStateService
                _wizardData.examName = calendar.examName;
                print('[ExamTimetableCreateWizard] Raw calendar examType: "${calendar.examType}"');
                print('[ExamTimetableCreateWizard] Raw calendar examName: "${calendar.examName}"');
                _wizardData.examType = _normalizeExamType(calendar.examType, calendar.examName);
                print('[ExamTimetableCreateWizard] After normalization examType: "${_wizardData.examType}"');
                print('[ExamTimetableCreateWizard] Normalized value length: ${_wizardData.examType.length}, is empty: ${_wizardData.examType.isEmpty}');
                _wizardData.academicYear = userStateService.currentAcademicYear ?? '';
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
        return TimetableWizardStep4Schedule(
          wizardData: _wizardData,
          onEntriesGenerated: (entries) {
            print('[ExamTimetableCreateWizard] Entries generated: ${entries.length} entries');
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
    final validationMessage = _getValidationMessage();
    if (!_validateCurrentStep()) {
      print('[ExamTimetableCreateWizard] Validation failed for step $_currentStep');
      print('[ExamTimetableCreateWizard] Validation message: $validationMessage');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationMessage),
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
      // Generate schedules and submit the timetable
      print('[ExamTimetableCreateWizard] Submitting timetable with schedules...');
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

  /// Get detailed validation message for current step
  String _getValidationMessage() {
    switch (_currentStep) {
      case 0:
        if (_wizardData.selectedCalendar == null) {
          return 'Please select an exam calendar';
        }
        return 'Please fill all required fields';
      case 1:
        if (_wizardData.selectedGrades.isEmpty) {
          return 'Please select at least one grade and section';
        }
        return 'Please fill all required fields';
      case 2:
        if (_wizardData.entries.isEmpty) {
          return 'Please schedule subjects for all exam dates';
        }
        return 'Please fill all required fields';
      default:
        return 'Please fill all required fields';
    }
  }

  /// Submit timetable creation
  void _submitTimetable() {
    print('[ExamTimetableCreateWizard] _submitTimetable: Building timetable entity');
    final now = DateTime.now();

    // Generate a UUID for timetable ID
    final timetableId = _generateUUID();

    // Get current user ID from UserStateService
    final userStateService = GetIt.instance<UserStateService>();
    final currentUserId = userStateService.currentUserId ?? 'unknown-user';

    // Defensive: ensure examType is never empty at submission time
    // If somehow the callback didn't run or normalization failed, do it now
    String finalExamType = _wizardData.examType;
    if (finalExamType.isEmpty && _wizardData.selectedCalendar != null) {
      print('[ExamTimetableCreateWizard] WARNING: examType is empty at submission, normalizing from calendar now');
      finalExamType = _normalizeExamType(_wizardData.selectedCalendar!.examType, _wizardData.selectedCalendar!.examName);
      print('[ExamTimetableCreateWizard] Normalized examType (defensive): "$finalExamType"');
    } else if (finalExamType.isEmpty) {
      print('[ExamTimetableCreateWizard] CRITICAL: examType is empty and no calendar selected, defaulting to "monthly"');
      finalExamType = 'monthly';
    }

    print('[ExamTimetableCreateWizard] Timetable ID: $timetableId');
    print('[ExamTimetableCreateWizard] Exam Name: ${_wizardData.examName}');
    print('[ExamTimetableCreateWizard] Exam Type (Final): $finalExamType');
    print('[ExamTimetableCreateWizard] Academic Year: ${_wizardData.academicYear}');
    print('[ExamTimetableCreateWizard] Selected Calendar: ${_wizardData.selectedCalendar?.id}');
    print('[ExamTimetableCreateWizard] Selected Grades: ${_wizardData.selectedGrades.length}');
    print('[ExamTimetableCreateWizard] Entries: ${_wizardData.entries.length}');
    print('[ExamTimetableCreateWizard] Created By: $currentUserId');

    final timetable = ExamTimetableEntity(
      id: timetableId,
      tenantId: widget.tenantId,
      createdBy: currentUserId,
      examCalendarId: _wizardData.selectedCalendar?.id,
      examName: _wizardData.examName,
      examType: finalExamType,
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

    // Note: Entries are created via a separate flow after timetable is created
    // The wizard generates entry data for validation/preview purposes,
    // but actual entry creation happens in a dedicated entries management page
    print('[ExamTimetableCreateWizard] Timetable created. Entries (${_wizardData.entries.length}) can be added separately from the timetable detail page.');
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

  /// Generate a UUID v4 string
  String _generateUUID() {
    // Simple UUID v4 generation using crypto random
    final random = DateTime.now().millisecondsSinceEpoch;
    final rng = <int>[];
    final values = <String>[];

    // Generate 16 random bytes
    for (var i = 0; i < 16; i++) {
      rng.add((random * (i + 1)) % 256);
    }

    // RFC 4122 v4 UUID format
    values.add(_toHex(rng[0]));
    values.add(_toHex(rng[1]));
    values.add(_toHex(rng[2]));
    values.add(_toHex(rng[3]));
    values.add('-');
    values.add(_toHex(rng[4]));
    values.add(_toHex(rng[5]));
    values.add('-');
    values.add(_toHex((rng[6] & 0x0f) | 0x40)); // version 4
    values.add(_toHex(rng[7]));
    values.add('-');
    values.add(_toHex((rng[8] & 0x3f) | 0x80)); // variant 1
    values.add(_toHex(rng[9]));
    values.add('-');
    values.add(_toHex(rng[10]));
    values.add(_toHex(rng[11]));
    values.add(_toHex(rng[12]));
    values.add(_toHex(rng[13]));
    values.add(_toHex(rng[14]));
    values.add(_toHex(rng[15]));

    return values.join();
  }

  /// Convert byte to hex string
  String _toHex(int value) {
    return value.toRadixString(16).padLeft(2, '0');
  }

  /// Normalize and validate exam type
  /// Converts various formats to database enum values: 'monthlyTest', 'halfYearlyTest', 'quarterlyTest', 'finalExam', 'dailyTest'
  /// Handles mismatched data from database by mapping common variations
  /// Also extracts type from exam name if rawExamType is invalid
  String _normalizeExamType(String rawExamType, String examName) {
    final validTypes = ['monthlyTest', 'halfYearlyTest', 'quarterlyTest', 'finalExam', 'dailyTest'];
    final normalized = rawExamType.toLowerCase().trim();

    // If already valid (camelCase check), return as-is
    if (validTypes.contains(rawExamType)) {
      return rawExamType;
    }

    // Map common variations to database enum values (camelCase)
    final typeMapping = {
      'monthly': 'monthlyTest',
      'monthly test': 'monthlyTest',
      'monthly tests': 'monthlyTest',
      'monthlytests': 'monthlyTest',
      'monthlytest': 'monthlyTest',
      'monthlyexam': 'monthlyTest',
      'monthly exam': 'monthlyTest',
      'mid_term': 'halfYearlyTest',
      'mid term': 'halfYearlyTest',
      'midterm': 'halfYearlyTest',
      'mid-term': 'halfYearlyTest',
      'mid year': 'halfYearlyTest',
      'mid_year': 'halfYearlyTest',
      'midyear': 'halfYearlyTest',
      'half yearly': 'halfYearlyTest',
      'half-yearly': 'halfYearlyTest',
      'half_yearly': 'halfYearlyTest',
      'halfyearly': 'halfYearlyTest',
      'halfyearlytest': 'halfYearlyTest',
      'quarterly': 'quarterlyTest',
      'quarterly test': 'quarterlyTest',
      'quarterly exam': 'quarterlyTest',
      'quarterlytest': 'quarterlyTest',
      'quarter': 'quarterlyTest',
      'quarter test': 'quarterlyTest',
      'final': 'finalExam',
      'final exam': 'finalExam',
      'finalexam': 'finalExam',
      'final_exam': 'finalExam',
      'finalsemester': 'finalExam',
      'final semester': 'finalExam',
      'unit': 'dailyTest',
      'unit test': 'dailyTest',
      'unit tests': 'dailyTest',
      'unit-test': 'dailyTest',
      'unit_test': 'dailyTest',
      'unittest': 'dailyTest',
      'unittests': 'dailyTest',
      'unitest': 'dailyTest',
      'daily': 'dailyTest',
      'daily test': 'dailyTest',
      'dailytest': 'dailyTest',
      'daily_test': 'dailyTest',
      // Handle calendar month names as monthly tests
      'november': 'monthlyTest',
      'december': 'monthlyTest',
      'october': 'monthlyTest',
      'september': 'monthlyTest',
      'january': 'monthlyTest',
      'february': 'monthlyTest',
      'march': 'monthlyTest',
      'april': 'monthlyTest',
      'may': 'monthlyTest',
      'june': 'monthlyTest',
      'july': 'monthlyTest',
      'august': 'monthlyTest',
    };

    // First try direct mapping
    if (typeMapping.containsKey(normalized)) {
      final mapped = typeMapping[normalized]!;
      print('[ExamTimetableCreateWizard] Normalized exam type: "$rawExamType" -> "$mapped"');
      return mapped;
    }

    // If not found in mapping, try to extract from exam name
    final examNameLower = examName.toLowerCase();

    // Check for keywords in exam name
    if (examNameLower.contains('monthly')) {
      print('[ExamTimetableCreateWizard] Extracted exam type from name: "$examName" -> "monthlyTest"');
      return 'monthlyTest';
    }
    if (examNameLower.contains('mid term') || examNameLower.contains('midterm') || examNameLower.contains('mid-term') || examNameLower.contains('half yearly') || examNameLower.contains('halfyearly')) {
      print('[ExamTimetableCreateWizard] Extracted exam type from name: "$examName" -> "halfYearlyTest"');
      return 'halfYearlyTest';
    }
    if (examNameLower.contains('quarterly') || examNameLower.contains('quarter')) {
      print('[ExamTimetableCreateWizard] Extracted exam type from name: "$examName" -> "quarterlyTest"');
      return 'quarterlyTest';
    }
    if (examNameLower.contains('final')) {
      print('[ExamTimetableCreateWizard] Extracted exam type from name: "$examName" -> "finalExam"');
      return 'finalExam';
    }
    if (examNameLower.contains('unit test') || examNameLower.contains('unit-test') || examNameLower.contains('unittest') || examNameLower.contains('daily')) {
      print('[ExamTimetableCreateWizard] Extracted exam type from name: "$examName" -> "dailyTest"');
      return 'dailyTest';
    }

    // Default to 'monthlyTest' if cannot determine (safer default than throwing error)
    print('[ExamTimetableCreateWizard] WARNING: Could not determine exam type from "$rawExamType" or "$examName", defaulting to "monthlyTest"');
    return 'monthlyTest';
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
