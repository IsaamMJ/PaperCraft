import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/exam_timetable_wizard_bloc.dart';
import '../bloc/exam_timetable_wizard_event.dart';
import '../bloc/exam_timetable_wizard_state.dart';
import '../widgets/wizard_step1_calendar.dart';
import '../widgets/wizard_step2_schedule_subjects.dart';
import '../widgets/wizard_step3_assign_teachers.dart';

/// Main Exam Timetable Wizard Page
///
/// Orchestrates the 3-step wizard flow:
/// 1. Select exam calendar (grades are automatically loaded from calendar)
/// 2. Schedule subjects (assign dates per subject per grade)
/// 3. Assign teachers & create papers (validate and generate)
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
            // Update step based on state
            if (state is WizardStep1State) {
              _goToStep(0);
            } else if (state is WizardStep2State) {
              _goToStep(1);
            } else if (state is WizardStep3State) {
              // New: Navigate to step 3 when Step3State is emitted
              _goToStep(2);
            } else if (state is WizardCompletedState) {
              _showSuccessDialog(context, state);
            } else if (state is WizardValidationErrorState) {
              // New: Show validation error message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: state.errors.map((error) => Text('• $error')).toList(),
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
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
                    WizardStep1Calendar(), // Step 1: Select Exam Calendar
                    WizardStep2ScheduleSubjects(), // Step 2: Schedule Subjects with per-grade scheduling
                    WizardStep3AssignTeachers(), // Step 3: Assign Teachers & Create Papers
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
          // Step indicator (3 steps)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStepBubble(0, 'Select Exam'),
              _buildStepConnector(0),
              _buildStepBubble(1, 'Schedule'),
              _buildStepConnector(1),
              _buildStepBubble(2, 'Assign & Create'),
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
                    onPressed: state is! WizardStep2State ||
                        !(state as WizardStep2State).isLoading
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
        // Trigger calendar selection event
        context.read<ExamTimetableWizardBloc>().add(
          SelectExamCalendarEvent(calendar: state.selectedCalendar!),
        );
      }
          : null;
    } else if (state is WizardStep2State) {
      // At step 2, check if we're at the final step (step index 2)
      if (_currentStep == 2) {
        // Final step - submit
        return !state.isLoading
            ? () {
          context
              .read<ExamTimetableWizardBloc>()
              .add(const SubmitWizardEvent());
        }
            : null;
      } else {
        // Step 1 (transitioning to step 2) - go to next step
        return !state.isLoading
            ? () {
          context
              .read<ExamTimetableWizardBloc>()
              .add(const GoToNextStepEvent());
        }
            : null;
      }
    } else if (state is WizardStep3State) {
      // Step 3 - submit (allow proceeding even if some subjects have no teacher assigned)
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
    if ((state is WizardStep2State && state.isLoading) || (state is WizardStep3State && state.isLoading)) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    // Step 2 and 3 (final steps) show "Create Timetable"
    if (_currentStep == 2 || state is WizardStep3State) {
      return const Text('Create Timetable');
    }

    // Steps 0 and 1 show "Next"
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