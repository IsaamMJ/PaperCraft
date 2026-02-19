import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/infrastructure/logging/app_logger.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../admin/domain/entities/admin_setup_state.dart' as domain;
import '../../../admin/domain/entities/admin_setup_grade.dart';
import '../../../admin/domain/entities/admin_setup_section.dart';
import '../../../admin/presentation/bloc/admin_setup_bloc.dart';
import '../../../admin/presentation/bloc/admin_setup_event.dart';
import '../../../admin/presentation/bloc/admin_setup_state.dart';
import '../widgets/onboarding_confirmation_sheet.dart';
import '../widgets/teacher_onboarding_step1_grades.dart';
import '../widgets/teacher_onboarding_step2_sections.dart';
import '../widgets/teacher_onboarding_step3_subjects.dart';
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

class _TeacherOnboardingPageState extends State<TeacherOnboardingPage>
    with TickerProviderStateMixin {
  static const _maxTenantRetries = 5;
  static const _tenantRetryDelay = Duration(milliseconds: 300);

  late AdminSetupBloc _bloc;
  List<AdminSetupGrade> _availableGrades = [];
  Map<int, List<AdminSetupSection>> _availableSectionsPerGrade = {};
  Map<int, List<String>> _availableSubjectsPerGrade = {};
  // Map: gradeNumber -> sectionName -> [subjectNames]
  Map<int, Map<String, List<String>>> _availableSubjectsPerGradePerSection = {};

  bool _isSaving = false;
  bool _isLoadingData = true; // Track local data loading state
  int _previousStep = 1;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _contentController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

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

    AppLogger.info(
      'TeacherOnboardingPage: Initializing',
      category: LogCategory.auth,
      context: {'tenantId': widget.tenantId},
    );

    _bloc = context.read<AdminSetupBloc>();
    _bloc.add(InitializeAdminSetupEvent(tenantId: widget.tenantId));

    AppLogger.info(
      'TeacherOnboardingPage: Starting data load',
      category: LogCategory.auth,
    );
    _loadSchoolInfoAndAvailableData();
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

  /// Load school info and available grades/sections/subjects from database
  Future<void> _loadSchoolInfoAndAvailableData() async {
    try {
      final sl = GetIt.instance;
      final userStateService = sl<UserStateService>();
      final supabase = Supabase.instance.client;

      var currentTenant = userStateService.currentTenant;

      // Tenant might not be loaded yet on first render, retry a few times
      if (currentTenant == null) {
        for (int i = 0; i < _maxTenantRetries; i++) {
          await Future.delayed(_tenantRetryDelay);
          currentTenant = userStateService.currentTenant;
          if (currentTenant != null) break;
        }
      }

      if (currentTenant == null) {
        AppLogger.error(
          'No current tenant found after retries',
          category: LogCategory.auth,
        );
        if (mounted) {
          setState(() => _isLoadingData = false);
        }
        return;
      }

      // Store in final variable for null safety
      final tenant = currentTenant;

      AppLogger.info(
        'Loading teacher onboarding data for tenant',
        category: LogCategory.auth,
        context: {
          'tenantId': tenant.id,
          'tenantName': tenant.name,
        },
      );

      // Update the admin setup bloc with school details
      _bloc.add(UpdateSchoolDetailsEvent(
        schoolName: tenant.name,
        schoolAddress: tenant.address ?? '',
      ));

      // Load available grades for this school
      AppLogger.info(
        'Fetching grades from database',
        category: LogCategory.auth,
      );

      final gradesData = await supabase
          .from('grades')
          .select()
          .eq('tenant_id', tenant.id);

      AppLogger.info(
        'Grades fetched from database',
        category: LogCategory.auth,
        context: {
          'count': (gradesData as List).length,
          'data': gradesData.toString(),
        },
      );

      final availableGrades = (gradesData as List).map((g) {
        AppLogger.debug(
          'Processing grade: $g',
          category: LogCategory.auth,
        );
        return AdminSetupGrade(
          gradeId: g['id'] as String,
          gradeNumber: g['grade_number'] as int,
          sections: [],
        );
      }).toList();

      // Load available sections for each grade
      AppLogger.info(
        'Fetching sections from database',
        category: LogCategory.auth,
      );

      // Fetch distinct sections from grade_section_subject table
      final sectionsRaw = await supabase
          .from('grade_section_subject')
          .select('grade_id, section')
          .eq('tenant_id', tenant.id);

      // Deduplicate: table has multiple rows per (grade_id, section) due to different subjects
      final sectionsMap = <String, Set<String>>{};
      for (var row in (sectionsRaw as List)) {
        final gradeId = row['grade_id'] as String;
        final section = row['section'] as String;
        sectionsMap.putIfAbsent(gradeId, () => {}).add(section);
      }

      // Convert to flat list for processing
      final sectionsData = <Map<String, dynamic>>[];
      sectionsMap.forEach((gradeId, sections) {
        for (var section in sections) {
          sectionsData.add({
            'grade_id': gradeId,
            'section_name': section,
            'tenant_id': tenant.id,
          });
        }
      });

      AppLogger.info(
        'Sections fetched from database',
        category: LogCategory.auth,
        context: {
          'count': (sectionsData as List).length,
          'data': sectionsData.toString(),
        },
      );

      // Build grade_number lookup map from already-fetched grades
      final gradeNumberMap = <String, int>{}; // grade_id -> grade_number
      for (var grade in (gradesData as List)) {
        gradeNumberMap[grade['id'] as String] = grade['grade_number'] as int;
      }

      final sectionsPerGrade = <int, List<AdminSetupSection>>{};
      for (var section in sectionsData as List) {
        try {
          final gradeId = section['grade_id'] as String?;
          final sectionName = section['section_name'] as String;

          // Lookup grade_number from our map (only grades from this tenant)
          if (gradeId != null && gradeNumberMap.containsKey(gradeId)) {
            final gradeNumber = gradeNumberMap[gradeId]!;
            sectionsPerGrade.putIfAbsent(gradeNumber, () => []).add(
              AdminSetupSection(
                sectionName: sectionName,
                subjects: [],
              ),
            );
          }
        } catch (e) {
          AppLogger.debug(
            'Error processing section: $e',
            category: LogCategory.auth,
          );
        }
      }

      // Load available subjects for each grade and section
      AppLogger.info(
        'Fetching subjects per grade/section from database',
        category: LogCategory.auth,
      );

      final gradeSubjectsData = await supabase
          .from('grade_section_subject')
          .select('grade_id, section, subject_id')
          .eq('tenant_id', tenant.id)
          .eq('is_offered', true);

      AppLogger.info(
        'Grade section subjects fetched from database',
        category: LogCategory.auth,
        context: {
          'count': (gradeSubjectsData as List).length,
          'data': gradeSubjectsData.toString(),
        },
      );

      final subjectsPerGrade = <int, List<String>>{};
      final subjectsPerGradePerSection = <int, Map<String, List<String>>>{};

      // Collect all subject_ids we need to lookup
      final subjectIds = <String>{};
      for (var gradeSectionSubject in gradeSubjectsData as List) {
        final subjectId = gradeSectionSubject['subject_id'] as String?;
        if (subjectId != null) {
          subjectIds.add(subjectId);
        }
      }

      // Fetch all subject details in one query
      final subjectMap = <String, String>{}; // subject_id -> subject_name
      if (subjectIds.isNotEmpty) {
        try {
          final subjectsData = await supabase
              .from('subjects')
              .select('id, catalog_subject_id')
              .inFilter('id', subjectIds.toList())
              .eq('tenant_id', tenant.id);

          final catalogSubjectIds = <String>{};
          final catalogMap = <String, String>{};

          for (var subject in subjectsData as List) {
            final subjectId = subject['id'] as String;
            final catalogSubjectId = subject['catalog_subject_id'] as String?;
            if (catalogSubjectId != null) {
              catalogSubjectIds.add(catalogSubjectId);
              catalogMap[catalogSubjectId] = subjectId;
            }
          }

          if (catalogSubjectIds.isNotEmpty) {
            final catalogData = await supabase
                .from('subject_catalog')
                .select('id, subject_name')
                .inFilter('id', catalogSubjectIds.toList());

            for (var catalog in catalogData as List) {
              final catalogId = catalog['id'] as String;
              final subjectName = catalog['subject_name'] as String;
              final subjectId = catalogMap[catalogId];
              if (subjectId != null) {
                subjectMap[subjectId] = subjectName;
              }
            }
          }
        } catch (e) {
          AppLogger.error(
            'Error fetching subjects',
            category: LogCategory.auth,
            error: e,
          );
        }
      }

      // Process the grade_section_subject data
      for (var gradeSectionSubject in gradeSubjectsData as List) {
        try {
          final gradeId = gradeSectionSubject['grade_id'] as String?;
          final sectionName = gradeSectionSubject['section'] as String?;
          final subjectId = gradeSectionSubject['subject_id'] as String?;

          if (gradeId != null && gradeNumberMap.containsKey(gradeId)) {
            final gradeNumber = gradeNumberMap[gradeId]!;
            final subjectName =
                subjectId != null ? subjectMap[subjectId] : null;

            if (subjectName != null) {
              subjectsPerGrade.putIfAbsent(gradeNumber, () => []);
              if (!subjectsPerGrade[gradeNumber]!.contains(subjectName)) {
                subjectsPerGrade[gradeNumber]!.add(subjectName);
              }

              if (sectionName != null) {
                subjectsPerGradePerSection.putIfAbsent(gradeNumber, () => {});
                subjectsPerGradePerSection[gradeNumber]!
                    .putIfAbsent(sectionName, () => []);
                if (!subjectsPerGradePerSection[gradeNumber]![sectionName]!
                    .contains(subjectName)) {
                  subjectsPerGradePerSection[gradeNumber]![sectionName]!
                      .add(subjectName);
                }
              }
            }
          }
        } catch (e) {
          AppLogger.error(
            'Error processing grade section subject mapping',
            category: LogCategory.auth,
            error: e,
            context: {
              'gradeSectionSubject': gradeSectionSubject.toString(),
            },
          );
        }
      }

      AppLogger.info(
        'Processed subjects per grade',
        category: LogCategory.auth,
        context: {
          'gradesWithSubjects': subjectsPerGrade.length,
          'subjectsPerGrade': subjectsPerGrade.toString(),
        },
      );

      AppLogger.info(
        'Storing available data in state',
        category: LogCategory.auth,
        context: {
          'gradesCount': availableGrades.length,
          'sectionsCount': sectionsPerGrade.length,
          'subjectsCount': subjectsPerGrade.length,
        },
      );

      if (mounted) {
        setState(() {
          _availableGrades = availableGrades;
          _availableSectionsPerGrade = sectionsPerGrade;
          _availableSubjectsPerGrade = subjectsPerGrade;
          _availableSubjectsPerGradePerSection = subjectsPerGradePerSection;
          _isLoadingData = false; // Data loaded successfully
        });

        AppLogger.info(
          'State updated with available data',
          category: LogCategory.auth,
          context: {
            'mounted': mounted,
            'gradesInState': _availableGrades.length,
            'sectionsInState': _availableSectionsPerGrade.length,
            'subjectsInState': _availableSubjectsPerGrade.length,
          },
        );
      } else {
        AppLogger.warning(
          'Widget not mounted, cannot update state',
          category: LogCategory.auth,
        );
      }

      AppLogger.info(
        'Loaded teacher onboarding data successfully',
        category: LogCategory.auth,
        context: {
          'grades': availableGrades.length,
          'sections': sectionsPerGrade.length,
          'subjects': subjectsPerGrade.length,
        },
      );
    } catch (e, _) {
      AppLogger.error(
        'Failed to load school onboarding data',
        category: LogCategory.auth,
        error: e,
      );
      // Still set loading to false so UI can show empty state with retry
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  /// Validate that at least 1 subject is selected across all grade-section pairs
  bool _validateBeforeComplete(domain.AdminSetupState setupState) {
    for (final grade in setupState.selectedGrades) {
      final sections = setupState.sectionsPerGrade[grade.gradeNumber] ?? [];
      for (final section in sections) {
        final subjects =
            setupState.getSubjectsForGradeSection(grade.gradeNumber, section);
        if (subjects.isNotEmpty) return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.debug(
      'TeacherOnboardingPage.build() - rendering',
      category: LogCategory.auth,
      context: {
        'availableGradesCount': _availableGrades.length,
        'availableSectionsCount': _availableSectionsPerGrade.length,
        'availableSubjectsCount': _availableSubjectsPerGrade.length,
      },
    );

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
              child: BlocListener<AdminSetupBloc, AdminSetupUIState>(
                listener: (context, state) {
                  AppLogger.debug(
                    'TeacherOnboardingPage: BLoC state changed',
                    category: LogCategory.auth,
                    context: {'state': state.runtimeType.toString()},
                  );

                  if (state is AdminSetupError) {
                    AppLogger.error(
                      'TeacherOnboardingPage: Setup error',
                      category: LogCategory.auth,
                      context: {'error': state.errorMessage},
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${state.errorMessage}'),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }

                  if (state is StepValidationFailed) {
                    AppLogger.warning(
                      'TeacherOnboardingPage: Step validation failed',
                      category: LogCategory.auth,
                      context: {'error': state.errorMessage},
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${state.errorMessage}'),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                },
                // Show loading while local data is being fetched (outside BlocBuilder so setState triggers rebuild)
                child: _isLoadingData
                    ? _buildLoadingState()
                    : BlocBuilder<AdminSetupBloc, AdminSetupUIState>(
                  builder: (context, state) {
                    AppLogger.debug(
                      'TeacherOnboardingPage: BLocBuilder rendering',
                      category: LogCategory.auth,
                      context: {'state': state.runtimeType.toString()},
                    );

                    // Show loading while BLoC is initializing
                    if (state is AdminSetupInitial || state is LoadingGrades) {
                      AppLogger.info(
                        'TeacherOnboardingPage: Loading state',
                        category: LogCategory.auth,
                      );
                      return _buildLoadingState();
                    }

                    final setupState = _bloc.setupState;

                    AppLogger.debug(
                      'TeacherOnboardingPage: Current setup state',
                      category: LogCategory.auth,
                      context: {
                        'currentStep': setupState.currentStep,
                        'selectedGradesCount':
                            setupState.selectedGrades.length,
                        'selectedSectionsCount':
                            setupState.sectionsPerGrade.length,
                        'selectedSubjectsCount':
                            setupState.subjectsPerGrade.length,
                      },
                    );

                    // Trigger animation when step changes
                    if (setupState.currentStep != _previousStep) {
                      _previousStep = setupState.currentStep;
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _animateStepTransition(),
                      );
                    }

                    return Column(
                      children: [
                        // Compact progress stepper
                        _buildProgressStepper(setupState.currentStep),

                        const SizedBox(height: 4),

                        // Step content (each step has its own hero header)
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
            ),

            // Saving overlay
            if (_isSaving) _buildSavingOverlay(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI fragments
  // ---------------------------------------------------------------------------

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
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Setting up your workspace...',
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

  /// Build the content for the current step
  Widget _buildStepContent(domain.AdminSetupState setupState, {Key? key}) {
    AppLogger.debug(
      '_buildStepContent: Building step ${setupState.currentStep}',
      category: LogCategory.auth,
      context: {
        'currentStep': setupState.currentStep,
        'availableGradesCount': _availableGrades.length,
        'availableSectionsCount': _availableSectionsPerGrade.length,
        'availableSubjectsCount': _availableSubjectsPerGrade.length,
      },
    );

    switch (setupState.currentStep) {
      case 1:
        AppLogger.debug(
          '_buildStepContent: Step 1 - Grades',
          category: LogCategory.auth,
          context: {
            'availableGradesCount': _availableGrades.length,
            'selectedGradesCount': setupState.selectedGrades.length,
            'schoolName': setupState.schoolName,
          },
        );
        return KeyedSubtree(
          key: key,
          child: TeacherOnboardingStep1Grades(
            selectedGrades: setupState.selectedGrades,
            availableGrades: _availableGrades,
            schoolName: setupState.schoolName.isNotEmpty
                ? setupState.schoolName
                : null,
            schoolAddress: setupState.schoolAddress.isNotEmpty
                ? setupState.schoolAddress
                : null,
            onRefresh: _loadSchoolInfoAndAvailableData,
          ),
        );

      case 2:
        AppLogger.debug(
          '_buildStepContent: Step 2 - Sections',
          category: LogCategory.auth,
          context: {
            'selectedGradesCount': setupState.selectedGrades.length,
            'availableSectionsPerGradeCount':
                _availableSectionsPerGrade.length,
            'selectedSectionsCount': setupState.sectionsPerGrade.length,
          },
        );
        return KeyedSubtree(
          key: key,
          child: TeacherOnboardingStep2Sections(
            selectedGrades: setupState.selectedGrades,
            availableSectionsPerGrade: _availableSectionsPerGrade,
            sectionsPerGrade: setupState.sectionsPerGrade,
          ),
        );

      case 3:
        AppLogger.debug(
          '_buildStepContent: Step 3 - Subjects',
          category: LogCategory.auth,
          context: {
            'selectedGradesCount': setupState.selectedGrades.length,
            'availableSubjectsPerGradeCount':
                _availableSubjectsPerGrade.length,
            'selectedSubjectsPerSectionCount':
                setupState.subjectsPerGradeSection.length,
          },
        );
        return KeyedSubtree(
          key: key,
          child: TeacherOnboardingStep3Subjects(
            selectedGrades: setupState.selectedGrades,
            availableSectionsPerGrade: _availableSectionsPerGrade,
            availableSubjectsPerGrade: _availableSubjectsPerGrade,
            availableSubjectsPerGradePerSection:
                _availableSubjectsPerGradePerSection,
            setupState: setupState,
          ),
        );

      default:
        AppLogger.warning(
          '_buildStepContent: Unknown step',
          category: LogCategory.auth,
          context: {'currentStep': setupState.currentStep},
        );
        return KeyedSubtree(
          key: key,
          child: const Center(child: Text('Unknown step')),
        );
    }
  }

  /// Pill-shaped navigation buttons with gradient fill / outline variants
  Widget _buildNavigationButtons(
    BuildContext context,
    domain.AdminSetupState setupState,
  ) {
    final isFirstStep = setupState.currentStep == 1;
    final isLastStep = setupState.currentStep == 3;

    AppLogger.debug(
      '_buildNavigationButtons',
      category: LogCategory.auth,
      context: {
        'currentStep': setupState.currentStep,
        'isFirstStep': isFirstStep,
        'isLastStep': isLastStep,
      },
    );

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
                onPressed: _isSaving
                    ? null
                    : () {
                        AppLogger.info(
                          'Previous step clicked',
                          category: LogCategory.auth,
                          context: {'currentStep': setupState.currentStep},
                        );
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
              isLoading: _isSaving && isLastStep,
              onPressed: _isSaving
                  ? null
                  : () async {
                      if (isLastStep) {
                        AppLogger.info(
                          'Complete button clicked - Saving teacher subjects',
                          category: LogCategory.auth,
                          context: {
                            'currentStep': setupState.currentStep,
                            'selectedGradesCount':
                                setupState.selectedGrades.length,
                            'selectedSectionsCount':
                                setupState.sectionsPerGrade.length,
                            'selectedSubjectsPerSectionCount':
                                setupState.subjectsPerGradeSection.length,
                          },
                        );

                        // Validate at least 1 subject selected
                        if (!_validateBeforeComplete(setupState)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Please select at least one subject'
                                      ' to continue.',
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: AppColors.warning,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                          return;
                        }

                        // Show confirmation sheet before saving
                        final confirmed =
                            await OnboardingConfirmationSheet.show(
                          context,
                          selectedGrades: setupState.selectedGrades,
                          sectionsPerGrade: setupState.sectionsPerGrade,
                          subjectsPerGradeSection:
                              setupState.subjectsPerGradeSection,
                          onConfirm: () {},
                          onGoBack: () {},
                          onEditStep: (step) {
                            for (int i = setupState.currentStep;
                                i > step;
                                i--) {
                              _bloc.add(const PreviousStepEvent());
                            }
                          },
                        );

                        if (confirmed == true) {
                          if (context.mounted) {
                            _markTeacherAsOnboarded(context);
                          }
                        }
                      } else {
                        AppLogger.info(
                          'Next step clicked',
                          category: LogCategory.auth,
                          context: {
                            'currentStep': setupState.currentStep,
                            'selectedGradesCount':
                                setupState.selectedGrades.length,
                          },
                        );
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

  Widget _buildSavingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.42),
      child: Center(
        child: Container(
          width: 144,
          height: 144,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              SizedBox(height: 18),
              Text(
                'Saving...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Business logic helpers
  // ---------------------------------------------------------------------------

  /// Calculate academic year based on current date
  /// April 2025 = "2025-2026", March 2025 = "2024-2025"
  String _getAcademicYear() {
    final now = DateTime.now();
    final year = now.month >= 4 ? now.year : now.year - 1;
    return '$year-${year + 1}';
  }

  /// Get the start date for the academic year (April 1st)
  DateTime _getAcademicYearStartDate() {
    final now = DateTime.now();
    final year = now.month >= 4 ? now.year : now.year - 1;
    return DateTime(year, 4, 1);
  }

  /// Get the end date for the academic year (March 31st of next year)
  DateTime _getAcademicYearEndDate() {
    final now = DateTime.now();
    final year = now.month >= 4 ? now.year : now.year - 1;
    return DateTime(year + 1, 3, 31);
  }

  /// Mark the current teacher as onboarded and save teacher_subjects records
  Future<void> _markTeacherAsOnboarded(BuildContext context) async {
    setState(() => _isSaving = true);

    try {
      AppLogger.info(
        '_markTeacherAsOnboarded: Starting completion process',
        category: LogCategory.auth,
      );

      final sl = GetIt.instance;
      final userStateService = sl<UserStateService>();
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      final currentTenant = userStateService.currentTenant;

      if (currentUser == null) {
        AppLogger.warning(
          'Cannot mark teacher as onboarded: no current user',
          category: LogCategory.auth,
        );
        if (mounted) setState(() => _isSaving = false);
        return;
      }

      if (currentTenant == null) {
        AppLogger.warning(
          'Cannot mark teacher as onboarded: no current tenant',
          category: LogCategory.auth,
        );
        if (mounted) setState(() => _isSaving = false);
        return;
      }

      final bloc = _bloc;
      final setupState = bloc.setupState;
      final academicYear = _getAcademicYear();
      final startDate = _getAcademicYearStartDate();
      final endDate = _getAcademicYearEndDate();

      AppLogger.info(
        '_markTeacherAsOnboarded: Academic year calculation',
        category: LogCategory.auth,
        context: {
          'academicYear': academicYear,
          'startDate': startDate.toString(),
          'endDate': endDate.toString(),
        },
      );

      // Collect all teacher_subjects records to insert
      final teacherSubjectsToInsert = <Map<String, dynamic>>[];

      // Iterate through selected grades and their sections
      for (final grade in setupState.selectedGrades) {
        final sections = setupState.sectionsPerGrade[grade.gradeNumber] ?? [];

        for (final section in sections) {
          final selectedSubjects = setupState.getSubjectsForGradeSection(
            grade.gradeNumber,
            section,
          );

          // For each selected subject, find its subject_id and create a record
          for (final subjectName in selectedSubjects) {
            try {
              // Find the subject_catalog_id for this subject name
              final catalogResponse = await supabase
                  .from('subject_catalog')
                  .select('id')
                  .eq('subject_name', subjectName)
                  .eq('is_active', true)
                  .maybeSingle();

              if (catalogResponse == null) {
                AppLogger.warning(
                  'Subject not found in catalog, skipping',
                  category: LogCategory.auth,
                  context: {'subjectName': subjectName},
                );
                continue;
              }

              final catalogSubjectId = catalogResponse['id'] as String;

              // Find the subject record for this tenant
              final subjectsResponse = await supabase
                  .from('subjects')
                  .select('id')
                  .eq('tenant_id', currentTenant.id)
                  .eq('catalog_subject_id', catalogSubjectId);

              if ((subjectsResponse as List).isEmpty) {
                AppLogger.error(
                  'Subject not found for teacher onboarding - admin must'
                  ' create subjects',
                  category: LogCategory.auth,
                  context: {
                    'subjectName': subjectName,
                    'catalogSubjectId': catalogSubjectId,
                    'tenantId': currentTenant.id,
                  },
                );
                throw Exception(
                  'Subject "$subjectName" not found.'
                  ' Admin must create subjects first.',
                );
              }

              final subjectId = subjectsResponse[0]['id'] as String;

              teacherSubjectsToInsert.add({
                'tenant_id': currentTenant.id,
                'teacher_id': currentUser.id,
                'grade_id': grade.gradeId,
                'subject_id': subjectId,
                'section': section,
                'academic_year': academicYear,
                'start_date': startDate.toIso8601String(),
                'end_date': endDate.toIso8601String(),
                'is_active': true,
              });
            } catch (e) {
              AppLogger.error(
                'Error processing subject during onboarding',
                category: LogCategory.auth,
                error: e,
                context: {
                  'subjectName': subjectName,
                  'grade': grade.gradeNumber,
                  'section': section,
                },
              );
            }
          }
        }
      }

      // Insert all teacher_subjects records
      if (teacherSubjectsToInsert.isNotEmpty) {
        AppLogger.info(
          '_markTeacherAsOnboarded: Inserting teacher_subjects records',
          category: LogCategory.auth,
          context: {
            'recordCount': teacherSubjectsToInsert.length,
          },
        );

        // Use upsert in case any conflicts exist
        await supabase.from('teacher_subjects').upsert(
          teacherSubjectsToInsert,
          onConflict:
              'tenant_id,teacher_id,grade_id,subject_id,section,academic_year',
        );
      }

      // Update is_onboarded flag in profiles
      AppLogger.info(
        '_markTeacherAsOnboarded: Updating is_onboarded flag',
        category: LogCategory.auth,
        context: {'userId': currentUser.id},
      );

      try {
        await supabase
            .from('profiles')
            .update({'is_onboarded': true}).eq('id', currentUser.id);

        AppLogger.info(
          'Teacher onboarded successfully',
          category: LogCategory.auth,
          context: {
            'userId': currentUser.id,
            'teacherSubjectsCount': teacherSubjectsToInsert.length,
            'academicYear': academicYear,
          },
        );
      } catch (updateError) {
        // Log but don't fail — teacher_subjects records are the main indicator
        AppLogger.warning(
          'Failed to update is_onboarded flag (non-critical)',
          category: LogCategory.auth,
          context: {'error': updateError.toString()},
        );
      }

      // After updating database, refresh auth state and navigate
      if (mounted) {
        setState(() => _isSaving = false);

        AppLogger.info(
          '_markTeacherAsOnboarded: Refreshing auth state',
          category: LogCategory.auth,
        );
        context.read<AuthBloc>().add(const AuthCheckStatus());
        context.go(AppRoutes.home);
      }
    } catch (e) {
      AppLogger.error(
        'Failed to mark teacher as onboarded',
        category: LogCategory.auth,
        error: e,
      );

      if (mounted) {
        setState(() => _isSaving = false);

        // Show error dialog with retry — do NOT navigate away on error
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            icon: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.error10,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 28,
              ),
            ),
            title: const Text(
              'Setup Failed',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
            content: Text(
              'Something went wrong while saving your profile.'
              ' Please try again.\n\n${e.toString()}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _markTeacherAsOnboarded(context);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
    }
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
            fontWeight:
                isCurrent ? FontWeight.w700 : FontWeight.w500,
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
      onTapDown:
          isDisabled ? null : (_) => _scaleCtrl.reverse(),
      onTapUp: isDisabled
          ? null
          : (_) {
              _scaleCtrl.forward();
              widget.onPressed?.call();
            },
      onTapCancel:
          isDisabled ? null : () => _scaleCtrl.forward(),
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
      onTapDown:
          isDisabled ? null : (_) => _scaleCtrl.reverse(),
      onTapUp: isDisabled
          ? null
          : (_) {
              _scaleCtrl.forward();
              widget.onPressed?.call();
            },
      onTapCancel:
          isDisabled ? null : () => _scaleCtrl.forward(),
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
