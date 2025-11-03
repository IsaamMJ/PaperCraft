import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/admin_setup_state.dart' as domain;
import '../bloc/admin_setup_bloc.dart';
import '../bloc/admin_setup_event.dart';
import '../bloc/admin_setup_state.dart';
import '../widgets/admin_setup_step1_grades.dart';
import '../widgets/admin_setup_step2_sections.dart';
import '../widgets/admin_setup_step3_subjects.dart';
import '../widgets/admin_setup_step4_review.dart';

/// Main page for admin setup wizard
class AdminSetupWizardPage extends StatefulWidget {
  final String tenantId;

  const AdminSetupWizardPage({
    Key? key,
    required this.tenantId,
  }) : super(key: key);

  @override
  State<AdminSetupWizardPage> createState() => _AdminSetupWizardPageState();
}

class _AdminSetupWizardPageState extends State<AdminSetupWizardPage> {
  late AdminSetupBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<AdminSetupBloc>();
    _bloc.add(InitializeAdminSetupEvent(tenantId: widget.tenantId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('School Setup Wizard'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blue,
      ),
      body: BlocConsumer<AdminSetupBloc, AdminSetupUIState>(
        listener: (context, state) {
          if (state is AdminSetupSaved) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Setup completed successfully!')),
            );
            // Navigate to admin dashboard
            Navigator.of(context).pushReplacementNamed('/admin/dashboard');
          } else if (state is AdminSetupError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage)),
            );
          } else if (state is StepValidationFailed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage)),
            );
          }
        },
        builder: (context, state) {
          if (state is AdminSetupInitial || state is LoadingGrades) {
            return const Center(child: CircularProgressIndicator());
          }

          // Get current setup state from BLoC
          final setupState = _bloc.setupState;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Progress indicator
                _buildProgressIndicator(setupState.currentStep),

                // Step content
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _buildStepContent(setupState),
                ),

                // Navigation buttons
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _buildNavigationButtons(context, setupState),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Build progress indicator showing current step
  Widget _buildProgressIndicator(int currentStep) {
    final steps = ['Grades', 'Sections', 'Subjects', 'Review'];
    const totalSteps = 4;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step counter
          Text(
            'Step $currentStep of $totalSteps',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: currentStep / totalSteps,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 16),

          // Step labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              totalSteps,
              (index) => _buildStepLabel(steps[index], index + 1, currentStep),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a single step label in the progress indicator
  Widget _buildStepLabel(String label, int stepNumber, int currentStep) {
    final isCompleted = stepNumber < currentStep;
    final isCurrent = stepNumber == currentStep;

    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted || isCurrent ? Colors.blue : Colors.grey[300],
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    '$stepNumber',
                    style: TextStyle(
                      color: isCompleted || isCurrent ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  /// Build the content for the current step
  Widget _buildStepContent(domain.AdminSetupState setupState) {
    switch (setupState.currentStep) {
      case 1:
        return AdminSetupStep1Grades(
          selectedGrades: setupState.selectedGrades,
        );
      case 2:
        return AdminSetupStep2Sections(
          selectedGrades: setupState.selectedGrades,
          sectionsPerGrade: setupState.sectionsPerGrade,
        );
      case 3:
        return AdminSetupStep3Subjects(
          selectedGrades: setupState.selectedGrades,
          subjectsPerGrade: setupState.subjectsPerGrade,
        );
      case 4:
        return AdminSetupStep4Review(
          setupState: setupState,
        );
      default:
        return const Center(child: Text('Unknown step'));
    }
  }

  /// Build navigation buttons (Next, Previous, Save)
  Widget _buildNavigationButtons(
    BuildContext context,
    domain.AdminSetupState setupState,
  ) {
    final isFirstStep = setupState.currentStep == 1;
    final isLastStep = setupState.currentStep == 4;

    return Row(
      children: [
        // Previous button
        if (!isFirstStep)
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                context.read<AdminSetupBloc>().add(const PreviousStepEvent());
              },
              child: const Text('Previous'),
            ),
          ),

        if (!isFirstStep) const SizedBox(width: 16),

        // Next or Complete button
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              if (isLastStep) {
                context.read<AdminSetupBloc>().add(const SaveAdminSetupEvent());
              } else {
                context.read<AdminSetupBloc>().add(const NextStepEvent());
              }
            },
            child: Text(isLastStep ? 'Complete Setup' : 'Next'),
          ),
        ),
      ],
    );
  }
}
