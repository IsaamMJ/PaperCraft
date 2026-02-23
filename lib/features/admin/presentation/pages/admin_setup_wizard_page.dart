import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../domain/entities/admin_setup_state.dart' as domain;
import '../bloc/admin_setup_bloc.dart';
import '../bloc/admin_setup_event.dart';
import '../bloc/admin_setup_state.dart';
import '../widgets/admin_setup_step1_grades.dart';
import '../widgets/admin_setup_step2_sections.dart';
import '../widgets/admin_setup_step3_subjects.dart';
import '../widgets/admin_setup_step4_review.dart';
import '../widgets/admin_setup_loading_modal.dart';
import '../widgets/admin_setup_success_modal.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_event.dart';

/// Main page for admin setup wizard — modernized with teacher-onboarding-style UI
class AdminSetupWizardPage extends StatefulWidget {
  final String tenantId;

  const AdminSetupWizardPage({
    super.key,
    required this.tenantId,
  });

  @override
  State<AdminSetupWizardPage> createState() => _AdminSetupWizardPageState();
}

class _AdminSetupWizardPageState extends State<AdminSetupWizardPage>
    with TickerProviderStateMixin {
  late AdminSetupBloc _bloc;
  late String _tenantId;
  int _previousStep = 1;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _contentController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _tenantId = widget.tenantId;
    _bloc = context.read<AdminSetupBloc>();
    _bloc.add(InitializeAdminSetupEvent(tenantId: _tenantId));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _contentController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _animateStepTransition() {
    _contentController.reset();
    _contentController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary10,
                    AppColors.background,
                    AppColors.background,
                  ],
                  stops: [0.0, 0.40, 1.0],
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: BlocConsumer<AdminSetupBloc, AdminSetupUIState>(
                listenWhen: (previous, current) {
                  return current is AdminSetupSaved ||
                      current is AdminSetupError ||
                      current is StepValidationFailed;
                },
                listener: (context, state) {
                  if (state is AdminSetupSaved) {
                    context.read<AuthBloc>().add(const AuthCheckStatus());
                    Future.delayed(const Duration(milliseconds: 1200), () {
                      if (context.mounted) {
                        context.go(AppRoutes.home);
                      }
                    });
                  } else if (state is AdminSetupError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.errorMessage),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  } else if (state is StepValidationFailed) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.errorMessage),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                },
                buildWhen: (previous, current) {
                  // Only rebuild on setup-relevant states, skip transient
                  // suggestion loading states that would destroy Step 3
                  return current is AdminSetupUpdated ||
                      current is AdminSetupInitial ||
                      current is LoadingGrades ||
                      current is GradesLoaded ||
                      current is SavingAdminSetup ||
                      current is AdminSetupSaved ||
                      current is AdminSetupError;
                },
                builder: (context, state) {
                  if (state is AdminSetupInitial || state is LoadingGrades) {
                    return _buildLoadingState();
                  }

                  // Show saving overlay
                  if (state is SavingAdminSetup) {
                    return const AdminSetupLoadingModal(
                      message: 'Completing setup...',
                    );
                  }

                  // Show success
                  if (state is AdminSetupSaved) {
                    return const AdminSetupSuccessModal();
                  }

                  final setupState = _bloc.setupState;

                  // Trigger animation when step changes
                  if (setupState.currentStep != _previousStep) {
                    _previousStep = setupState.currentStep;
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _animateStepTransition(),
                    );
                  }

                  return Column(
                    children: [
                      // Progress stepper
                      _buildProgressStepper(setupState.currentStep),

                      const SizedBox(height: 4),

                      // Step content with animated transitions
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 340),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.04, 0),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOut,
                                )),
                                child: child,
                              ),
                            );
                          },
                          child: _buildStepContent(
                            setupState,
                            key: ValueKey<int>(setupState.currentStep),
                          ),
                        ),
                      ),

                      // Navigation buttons
                      _buildNavigationButtons(context, setupState),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Setting up your school...',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStepper(int currentStep) {
    final steps = [
      (icon: Icons.school_rounded, label: 'Grades'),
      (icon: Icons.grid_view_rounded, label: 'Sections'),
      (icon: Icons.menu_book_rounded, label: 'Subjects'),
      (icon: Icons.check_circle_rounded, label: 'Review'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            _StepCircle(
              icon: steps[i].icon,
              label: steps[i].label,
              stepNumber: i + 1,
              currentStep: currentStep,
              pulseAnimation: _pulseAnimation,
            ),
            if (i < steps.length - 1)
              Expanded(
                child: _StepConnector(isCompleted: currentStep > i + 1),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepContent(domain.AdminSetupState setupState, {Key? key}) {
    switch (setupState.currentStep) {
      case 1:
        return KeyedSubtree(
          key: key,
          child: AdminSetupStep1Grades(
            selectedGrades: setupState.selectedGrades,
            schoolName: setupState.schoolName,
            schoolAddress: setupState.schoolAddress,
          ),
        );
      case 2:
        return KeyedSubtree(
          key: key,
          child: AdminSetupStep2Sections(
            selectedGrades: setupState.selectedGrades,
            sectionsPerGrade: setupState.sectionsPerGrade,
          ),
        );
      case 3:
        return KeyedSubtree(
          key: key,
          child: AdminSetupStep3Subjects(
            selectedGrades: setupState.selectedGrades,
            sectionsPerGrade: setupState.sectionsPerGrade,
            subjectsPerGradeSection: setupState.subjectsPerGradeSection,
            subjectSuggestions: _bloc.subjectSuggestions,
          ),
        );
      case 4:
        return KeyedSubtree(
          key: key,
          child: AdminSetupStep4Review(
            setupState: setupState,
          ),
        );
      default:
        return KeyedSubtree(
          key: key,
          child: const Center(child: Text('Unknown step')),
        );
    }
  }

  Widget _buildNavigationButtons(
    BuildContext context,
    domain.AdminSetupState setupState,
  ) {
    final isFirstStep = setupState.currentStep == 1;
    final isLastStep = setupState.currentStep == 4;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          // Previous button — outlined pill
          if (!isFirstStep) ...[
            Expanded(
              child: _PillOutlinedButton(
                label: 'Previous',
                icon: Icons.arrow_back_rounded,
                onPressed: () {
                  context
                      .read<AdminSetupBloc>()
                      .add(const PreviousStepEvent());
                },
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Next / Complete button — gradient pill
          Expanded(
            flex: isFirstStep ? 1 : 2,
            child: _PillGradientButton(
              label: isLastStep ? 'Complete Setup' : 'Continue',
              icon: isLastStep
                  ? Icons.check_circle_rounded
                  : Icons.arrow_forward_rounded,
              onPressed: () {
                if (isLastStep) {
                  context
                      .read<AdminSetupBloc>()
                      .add(const SaveAdminSetupEvent());
                } else {
                  context
                      .read<AdminSetupBloc>()
                      .add(const NextStepEvent());
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Step progress sub-widgets
// =============================================================================

class _StepCircle extends StatelessWidget {
  final IconData icon;
  final String label;
  final int stepNumber;
  final int currentStep;
  final Animation<double> pulseAnimation;

  const _StepCircle({
    required this.icon,
    required this.label,
    required this.stepNumber,
    required this.currentStep,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = stepNumber < currentStep;
    final isCurrent = stepNumber == currentStep;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: pulseAnimation,
          builder: (context, child) => Transform.scale(
            scale: isCurrent ? pulseAnimation.value : 1.0,
            child: child,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isCompleted || isCurrent
                  ? AppColors.primaryGradient
                  : null,
              color: isCompleted || isCurrent
                  ? null
                  : AppColors.backgroundSecondary,
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.36),
                        blurRadius: 14,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : isCompleted
                      ? [
                          BoxShadow(
                            color:
                                AppColors.primary.withValues(alpha: 0.18),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
              border: isCompleted || isCurrent
                  ? null
                  : Border.all(
                      color: AppColors.border,
                      width: 1.5,
                    ),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 20,
                    )
                  : Icon(
                      icon,
                      color:
                          isCurrent ? Colors.white : AppColors.textTertiary,
                      size: 20,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: isCurrent
                ? AppColors.primary
                : isCompleted
                    ? AppColors.textSecondary
                    : AppColors.textTertiary,
            letterSpacing: -0.1,
          ),
          child: Text(label),
        ),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  final bool isCompleted;

  const _StepConnector({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        height: 2,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          gradient: isCompleted ? AppColors.primaryGradient : null,
          color: isCompleted ? null : AppColors.border,
        ),
      ),
    );
  }
}

// =============================================================================
// Reusable pill button components
// =============================================================================

class _PillGradientButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _PillGradientButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  State<_PillGradientButton> createState() => _PillGradientButtonState();
}

class _PillGradientButtonState extends State<_PillGradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 180),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null;

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => _scaleCtrl.reverse(),
      onTapUp: isDisabled
          ? null
          : (_) {
              _scaleCtrl.forward();
              widget.onPressed?.call();
            },
      onTapCancel: isDisabled ? null : () => _scaleCtrl.forward(),
      child: AnimatedBuilder(
        animation: _scaleCtrl,
        builder: (context, child) =>
            Transform.scale(scale: _scaleCtrl.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          decoration: BoxDecoration(
            gradient: isDisabled ? null : AppColors.primaryGradient,
            color: isDisabled ? AppColors.border : null,
            borderRadius: BorderRadius.circular(26),
            boxShadow: isDisabled
                ? null
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.30),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: isDisabled
                              ? AppColors.textTertiary
                              : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        widget.icon,
                        color: isDisabled
                            ? AppColors.textTertiary
                            : Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _PillOutlinedButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _PillOutlinedButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_PillOutlinedButton> createState() => _PillOutlinedButtonState();
}

class _PillOutlinedButtonState extends State<_PillOutlinedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 180),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null;

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => _scaleCtrl.reverse(),
      onTapUp: isDisabled
          ? null
          : (_) {
              _scaleCtrl.forward();
              widget.onPressed?.call();
            },
      onTapCancel: isDisabled ? null : () => _scaleCtrl.forward(),
      child: AnimatedBuilder(
        animation: _scaleCtrl,
        builder: (context, child) =>
            Transform.scale(scale: _scaleCtrl.value, child: child),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isDisabled ? AppColors.border : AppColors.primary,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  color: isDisabled
                      ? AppColors.textTertiary
                      : AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: isDisabled
                        ? AppColors.textTertiary
                        : AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
