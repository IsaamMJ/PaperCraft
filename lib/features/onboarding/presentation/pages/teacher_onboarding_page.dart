import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../admin/domain/entities/admin_setup_state.dart' as domain;
import '../../../admin/presentation/bloc/admin_setup_bloc.dart';
import '../../../admin/presentation/bloc/admin_setup_event.dart';
import '../../../admin/presentation/bloc/admin_setup_state.dart';
import '../../../admin/presentation/widgets/admin_setup_step1_grades.dart';
import '../../../admin/presentation/widgets/admin_setup_step2_sections.dart';
import '../../../admin/presentation/widgets/admin_setup_step3_subjects.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_event.dart';

/// Teacher onboarding page (3-step wizard)
/// For school teachers: grades → sections → subjects
class TeacherOnboardingPage extends StatefulWidget {
  final String tenantId;

  const TeacherOnboardingPage({
    super.key,
    required this.tenantId,
  });

  @override
  State<TeacherOnboardingPage> createState() => _TeacherOnboardingPageState();
}

class _TeacherOnboardingPageState extends State<TeacherOnboardingPage> {
  late AdminSetupBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<AdminSetupBloc>();
    _bloc.add(InitializeAdminSetupEvent(tenantId: widget.tenantId));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: BlocListener<AdminSetupBloc, AdminSetupUIState>(
            listener: (context, state) {
              if (state is AdminSetupSaved) {
                // Teacher onboarding complete - navigate to home
                context.read<AuthBloc>().add(AuthCheckStatus());
                context.go(AppRoutes.home);
              }

              if (state is AdminSetupError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${state.errorMessage}'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }

              if (state is StepValidationFailed) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${state.errorMessage}'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: BlocBuilder<AdminSetupBloc, AdminSetupUIState>(
              builder: (context, state) {
                if (state is AdminSetupInitial || state is LoadingGrades) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Get current setup state from BLoC
                final setupState = _bloc.setupState;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Text(
                        'Set Up Your Teaching Profile',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Configure the grades and subjects you\'ll be teaching',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 24),

                      // Progress indicator
                      _buildProgressIndicator(setupState.currentStep),
                      const SizedBox(height: 24),

                      // Step content
                      _buildStepContent(setupState),
                      const SizedBox(height: 24),

                      // Navigation buttons
                      _buildNavigationButtons(context, setupState),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Build progress indicator showing current step
  Widget _buildProgressIndicator(int currentStep) {
    final steps = ['Grades', 'Sections', 'Subjects'];
    const totalSteps = 3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (int i = 0; i < totalSteps; i++)
            Expanded(
              child: _buildStepLabel(steps[i], i + 1, currentStep),
            ),
        ],
      ),
    );
  }

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
            color: isCompleted || isCurrent ? AppColors.primary : Colors.grey[300],
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
    final isLastStep = setupState.currentStep == 3;

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

        // Next/Complete button
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              if (isLastStep) {
                // Save setup
                context.read<AdminSetupBloc>().add(const SaveAdminSetupEvent());
              } else {
                // Go to next step
                context.read<AdminSetupBloc>().add(const NextStepEvent());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: Text(isLastStep ? 'Complete' : 'Next'),
          ),
        ),
      ],
    );
  }
}
