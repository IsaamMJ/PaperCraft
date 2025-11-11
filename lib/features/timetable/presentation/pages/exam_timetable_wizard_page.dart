import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/exam_timetable_wizard_bloc.dart';
import '../bloc/exam_timetable_wizard_event.dart';
import '../bloc/exam_timetable_wizard_state.dart';
import '../widgets/wizard_step1_calendar.dart';
import '../widgets/wizard_step2_grades.dart';
import '../widgets/wizard_step3_schedule.dart';

/// Main Exam Timetable Wizard Page
///
/// Orchestrates the 3-step wizard flow:
/// 1. Select exam calendar
/// 2. Select participating grades
/// 3. Assign subjects to exam dates
class ExamTimetableWizardPage extends StatefulWidget {
  final String tenantId;
  final String userId;
  final String academicYear;

  const ExamTimetableWizardPage({
    required this.tenantId,
    required this.userId,
    required this.academicYear,
    Key? key,
  }) : super(key: key);

  @override
  State<ExamTimetableWizardPage> createState() =>
      _ExamTimetableWizardPageState();
}

class _ExamTimetableWizardPageState extends State<ExamTimetableWizardPage> {
  late PageController _pageController;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Initialize wizard
    context.read<ExamTimetableWizardBloc>().add(
          InitializeWizardEvent(
            tenantId: widget.tenantId,
            userId: widget.userId,
            academicYear: widget.academicYear,
          ),
        );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() {
      _currentStep = step;
    });
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goBack() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentStep > 0) {
          _goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Exam Timetable'),
          elevation: 0,
          leading: _currentStep > 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _goBack,
                )
              : null,
        ),
        body: BlocListener<ExamTimetableWizardBloc, ExamTimetableWizardState>(
          listener: (context, state) {
            print('[WizardPage] BlocListener: state type = ${state.runtimeType}');
            // Update step based on state
            if (state is WizardStep1State) {
              print('[WizardPage] Navigating to Step 0 (Calendar)');
              _goToStep(0);
            } else if (state is WizardStep2State) {
              print('[WizardPage] Navigating to Step 1 (Grades), availableGrades count: ${state.availableGrades.length}');
              _goToStep(1);
            } else if (state is WizardStep3State) {
              print('[WizardPage] Navigating to Step 2 (Schedule)');
              _goToStep(2);
            } else if (state is WizardCompletedState) {
              _showSuccessDialog(context, state);
            } else if (state is WizardErrorState) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                  action: SnackBarAction(
                    label: 'Retry',
                    onPressed: () {
                      context.read<ExamTimetableWizardBloc>().add(
                            InitializeWizardEvent(
                              tenantId: widget.tenantId,
                              userId: widget.userId,
                              academicYear: widget.academicYear,
                            ),
                          );
                    },
                  ),
                ),
              );
            }
          },
          child: Column(
            children: [
              // Progress indicator
              _buildProgressIndicator(),

              // Content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    WizardStep1Calendar(),
                    WizardStep2Grades(),
                    WizardStep3Schedule(),
                  ],
                ),
              ),

              // Buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build progress indicator
  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStepBubble(0, 'Calendar'),
              _buildStepConnector(0),
              _buildStepBubble(1, 'Grades'),
              _buildStepConnector(1),
              _buildStepBubble(2, 'Schedule'),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 3,
              minHeight: 4,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(Colors.blue.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBubble(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrent
                  ? Colors.blue
                  : isActive
                      ? Colors.blue.shade200
                      : Colors.grey.shade200,
            ),
            child: Center(
              child: isActive
                  ? Icon(
                      isCurrent ? Icons.circle : Icons.check,
                      color: isCurrent ? Colors.white : Colors.blue.shade700,
                      size: 20,
                    )
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent ? Colors.blue : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int step) {
    final isActive = _currentStep > step;

    return Expanded(
      child: Container(
        height: 2,
        color: isActive ? Colors.blue : Colors.grey.shade200,
      ),
    );
  }

  /// Build action buttons
  Widget _buildActionButtons() {
    return BlocBuilder<ExamTimetableWizardBloc, ExamTimetableWizardState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              // Back button
              if (_currentStep > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: state is! WizardStep3State ||
                            !(state as WizardStep3State).isLoading
                        ? _goBack
                        : null,
                    child: const Text('Back'),
                  ),
                )
              else
                const Expanded(child: SizedBox()),

              const SizedBox(width: 12),

              // Next/Submit button
              Expanded(
                child: ElevatedButton(
                  onPressed: _getNextButtonAction(context, state),
                  child: _getNextButtonLabel(state),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  VoidCallback? _getNextButtonAction(
    BuildContext context,
    ExamTimetableWizardState state,
  ) {
    if (state is WizardStep1State) {
      return state.selectedCalendar != null && !state.isLoading
          ? () {
              // Already handled by BLoC listener
            }
          : null;
    } else if (state is WizardStep2State) {
      print('[WizardPage] Step2 button check - selectedGradeIds: ${state.selectedGradeIds.length}, isLoading: ${state.isLoading}');
      return state.selectedGradeIds.isNotEmpty && !state.isLoading
          ? () {
              print('[WizardPage] Next button clicked on Step 2 with ${state.selectedGradeIds.length} grade sections');
              context.read<ExamTimetableWizardBloc>().add(
                    SelectGradesEvent(
                      examCalendarId: state.selectedCalendar.id,
                      gradeSectionIds: List.from(state.selectedGradeIds),
                    ),
                  );
            }
          : null;
    } else if (state is WizardStep3State) {
      return !state.isLoading
          ? () {
              context
                  .read<ExamTimetableWizardBloc>()
                  .add(const SubmitWizardEvent());
            }
          : null;
    }
    return null;
  }

  Widget _getNextButtonLabel(ExamTimetableWizardState state) {
    if (state is WizardStep3State && state.isLoading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_currentStep == 2) {
      return const Text('Create Timetable');
    }

    return const Text('Next');
  }

  /// Show success dialog
  void _showSuccessDialog(
    BuildContext context,
    WizardCompletedState state,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        title: const Text('Success!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exam: ${state.examName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Timetable ID: ${state.timetableId.substring(0, 8)}...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, state.timetableId); // Return timetable ID
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
