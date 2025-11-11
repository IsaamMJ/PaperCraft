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

class _TeacherOnboardingPageState extends State<TeacherOnboardingPage> {
  late AdminSetupBloc _bloc;
  List<AdminSetupGrade> _availableGrades = [];
  Map<int, List<AdminSetupSection>> _availableSectionsPerGrade = {};
  Map<int, List<String>> _availableSubjectsPerGrade = {};
  // Map: gradeNumber -> sectionName -> [subjectNames]
  Map<int, Map<String, List<String>>> _availableSubjectsPerGradePerSection = {};

  @override
  void initState() {
    super.initState();
    AppLogger.info('TeacherOnboardingPage: Initializing',
      category: LogCategory.auth,
      context: {'tenantId': widget.tenantId},
    );

    _bloc = context.read<AdminSetupBloc>();
    _bloc.add(InitializeAdminSetupEvent(tenantId: widget.tenantId));

    // Load school information and available data from the database
    AppLogger.info('TeacherOnboardingPage: Starting data load',
      category: LogCategory.auth,
    );
    _loadSchoolInfoAndAvailableData();
  }

  /// Load school info and available grades/sections/subjects from database
  Future<void> _loadSchoolInfoAndAvailableData() async {
    try {
      final sl = GetIt.instance;
      final userStateService = sl<UserStateService>();
      final supabase = Supabase.instance.client;

      final currentTenant = userStateService.currentTenant;
      if (currentTenant == null) {
        AppLogger.error('No current tenant found',
          category: LogCategory.auth,
        );
        return;
      }

      AppLogger.info('Loading teacher onboarding data for tenant',
        category: LogCategory.auth,
        context: {
          'tenantId': currentTenant.id,
          'tenantName': currentTenant.name,
        },
      );

      // Update the admin setup bloc with school details
      _bloc.add(UpdateSchoolDetailsEvent(
        schoolName: currentTenant.name,
        schoolAddress: currentTenant.address ?? '',
      ));

      // Load available grades for this school
      AppLogger.info('Fetching grades from database',
        category: LogCategory.auth,
      );

      final gradesData = await supabase
          .from('grades')
          .select()
          .eq('tenant_id', currentTenant.id);

      AppLogger.info('Grades fetched from database',
        category: LogCategory.auth,
        context: {
          'count': (gradesData as List).length,
          'data': gradesData.toString(),
        },
      );

      final availableGrades = (gradesData as List).map((g) {
        AppLogger.debug('Processing grade: $g',
          category: LogCategory.auth,
        );
        return AdminSetupGrade(
          gradeId: g['id'] as String,
          gradeNumber: g['grade_number'] as int,
          sections: [],
        );
      }).toList();

      // Load available sections for each grade
      AppLogger.info('Fetching sections from database',
        category: LogCategory.auth,
      );

      // FIX: Fetch distinct sections from grade_section_subject table
      final sectionsRaw = await supabase
          .from('grade_section_subject')
          .select('grade_id, section')
          .eq('tenant_id', currentTenant.id);

      // Deduplicate: sections table has multiple rows per (grade_id, section) due to different subjects
      final sectionsMap = <String, Set<String>>{}; // grade_id -> set of sections
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
            'tenant_id': currentTenant.id,
          });
        }
      });

      for (var section in sectionsData) {
      }

      AppLogger.info('Sections fetched from database',
        category: LogCategory.auth,
        context: {
          'count': (sectionsData as List).length,
          'data': sectionsData.toString(),
        },
      );

      // Build grade_number lookup map from already-fetched grades
      final gradeNumberMap = <String, int>{};  // grade_id -> grade_number
      for (var grade in (gradesData as List)) {
        gradeNumberMap[grade['id'] as String] = grade['grade_number'] as int;
      }

      gradeNumberMap.forEach((gradeId, gradeNumber) {
      });

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
          } else {
          }
        } catch (e) {
          AppLogger.debug('Error processing section: $e', category: LogCategory.auth);
        }
      }

      sectionsPerGrade.forEach((gradeNumber, sections) {
      });

      // Load available subjects for each grade and section (from grade_section_subject junction table)
      AppLogger.info('Fetching subjects per grade/section from database',
        category: LogCategory.auth,
      );

      // FIX: Don't JOIN grades/subjects, fetch with tenant filter only
      final gradeSubjectsData = await supabase
          .from('grade_section_subject')
          .select('grade_id, section, subject_id')  // Only needed columns
          .eq('tenant_id', currentTenant.id)
          .eq('is_offered', true);

      AppLogger.info('Grade section subjects fetched from database',
        category: LogCategory.auth,
        context: {
          'count': (gradeSubjectsData as List).length,
          'data': gradeSubjectsData.toString(),
        },
      );

      final subjectsPerGrade = <int, List<String>>{};
      final subjectsPerGradePerSection = <int, Map<String, List<String>>>{};

      // First, collect all subject_ids we need to lookup
      final subjectIds = <String>{};
      for (var gradeSectionSubject in gradeSubjectsData as List) {
        final subjectId = gradeSectionSubject['subject_id'] as String?;
        if (subjectId != null) {
          subjectIds.add(subjectId);
        }
      }

      // Fetch all subject details (with catalog info) in one query
      final subjectMap = <String, String>{};  // subject_id -> subject_name
      if (subjectIds.isNotEmpty) {
        try {
          // Fetch subjects with their catalog_subject_id
          final subjectsData = await supabase
              .from('subjects')
              .select('id, catalog_subject_id')
              .inFilter('id', subjectIds.toList())
              .eq('tenant_id', currentTenant.id);  // ← Filter by tenant!

          // Collect catalog IDs
          final catalogSubjectIds = <String>{};
          final catalogMap = <String, String>{};  // catalog_id -> subject_id (from subjects table)

          for (var subject in subjectsData as List) {
            final subjectId = subject['id'] as String;
            final catalogSubjectId = subject['catalog_subject_id'] as String?;
            if (catalogSubjectId != null) {
              catalogSubjectIds.add(catalogSubjectId);
              catalogMap[catalogSubjectId] = subjectId;
            }
          }

          // Fetch subject names from catalog
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
          AppLogger.error('Error fetching subjects',
            category: LogCategory.auth,
            error: e,
          );
        }
      }

      // Now process the grade_section_subject data
      for (var gradeSectionSubject in gradeSubjectsData as List) {
        try {
          final gradeId = gradeSectionSubject['grade_id'] as String?;
          final sectionName = gradeSectionSubject['section'] as String?;
          final subjectId = gradeSectionSubject['subject_id'] as String?;

          // Lookup grade_number from our map (only from this tenant's grades)
          if (gradeId != null && gradeNumberMap.containsKey(gradeId)) {
            final gradeNumber = gradeNumberMap[gradeId]!;
            final subjectName = subjectId != null ? subjectMap[subjectId] : null;

            if (subjectName != null) {
              // Add subject to the list for this grade (only if not already added)
              subjectsPerGrade.putIfAbsent(gradeNumber, () => []);
              if (!subjectsPerGrade[gradeNumber]!.contains(subjectName)) {
                subjectsPerGrade[gradeNumber]!.add(subjectName);
              }

              // Also track subjects per grade+section
              if (sectionName != null) {
                subjectsPerGradePerSection.putIfAbsent(gradeNumber, () => {});
                subjectsPerGradePerSection[gradeNumber]!.putIfAbsent(sectionName, () => []);
                if (!subjectsPerGradePerSection[gradeNumber]![sectionName]!.contains(subjectName)) {
                  subjectsPerGradePerSection[gradeNumber]![sectionName]!.add(subjectName);
                }
              }
            }
          }
        } catch (e) {
          AppLogger.error('Error processing grade section subject mapping',
            category: LogCategory.auth,
            error: e,
            context: {
              'gradeSectionSubject': gradeSectionSubject.toString(),
            },
          );
        }
      }

      AppLogger.info('Processed subjects per grade',
        category: LogCategory.auth,
        context: {
          'gradesWithSubjects': subjectsPerGrade.length,
          'subjectsPerGrade': subjectsPerGrade.toString(),
        },
      );

      // Store available data
      AppLogger.info('Storing available data in state',
        category: LogCategory.auth,
        context: {
          'gradesCount': availableGrades.length,
          'sectionsCount': sectionsPerGrade.length,
          'subjectsCount': subjectsPerGrade.length,
        },
      );

      if (mounted) {
        sectionsPerGrade.forEach((gradeNumber, sections) {
        });

        setState(() {
          _availableGrades = availableGrades;
          _availableSectionsPerGrade = sectionsPerGrade;
          _availableSubjectsPerGrade = subjectsPerGrade;
          _availableSubjectsPerGradePerSection = subjectsPerGradePerSection;
        });


        AppLogger.info('State updated with available data',
          category: LogCategory.auth,
          context: {
            'mounted': mounted,
            'gradesInState': _availableGrades.length,
            'sectionsInState': _availableSectionsPerGrade.length,
            'subjectsInState': _availableSubjectsPerGrade.length,
          },
        );
      } else {
        AppLogger.warning('Widget not mounted, cannot update state',
          category: LogCategory.auth,
        );
      }

      AppLogger.info('Loaded teacher onboarding data successfully',
        category: LogCategory.auth,
        context: {
          'grades': availableGrades.length,
          'sections': sectionsPerGrade.length,
          'subjects': subjectsPerGrade.length,
        },
      );
    } catch (e, _) {
      AppLogger.error('Failed to load school onboarding data',
        category: LogCategory.auth,
        error: e,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug: Log current state
    AppLogger.debug('TeacherOnboardingPage.build() - rendering',
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
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: BlocListener<AdminSetupBloc, AdminSetupUIState>(
            listener: (context, state) {
              AppLogger.debug('TeacherOnboardingPage: BLoC state changed',
                category: LogCategory.auth,
                context: {'state': state.runtimeType.toString()},
              );

              // Note: AdminSetupSaved is no longer used for teacher onboarding
              // Teachers call _markTeacherAsOnboarded directly instead

              if (state is AdminSetupError) {
                AppLogger.error('TeacherOnboardingPage: Setup error',
                  category: LogCategory.auth,
                  context: {'error': state.errorMessage},
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${state.errorMessage}'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }

              if (state is StepValidationFailed) {
                AppLogger.warning('TeacherOnboardingPage: Step validation failed',
                  category: LogCategory.auth,
                  context: {'error': state.errorMessage},
                );
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
                AppLogger.debug('TeacherOnboardingPage: BLocBuilder rendering',
                  category: LogCategory.auth,
                  context: {'state': state.runtimeType.toString()},
                );

                if (state is AdminSetupInitial || state is LoadingGrades) {
                  AppLogger.info('TeacherOnboardingPage: Loading state',
                    category: LogCategory.auth,
                  );
                  return const Center(child: CircularProgressIndicator());
                }

                // Get current setup state from BLoC
                final setupState = _bloc.setupState;
                AppLogger.debug('TeacherOnboardingPage: Current setup state',
                  category: LogCategory.auth,
                  context: {
                    'currentStep': setupState.currentStep,
                    'selectedGradesCount': setupState.selectedGrades.length,
                    'selectedSectionsCount': setupState.sectionsPerGrade.length,
                    'selectedSubjectsCount': setupState.subjectsPerGrade.length,
                  },
                );

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

  /// Build progress indicator showing current step (3 steps for teacher flow)
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
    AppLogger.debug('_buildStepContent: Building step ${setupState.currentStep}',
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
        AppLogger.debug('_buildStepContent: Step 1 - Grades',
          category: LogCategory.auth,
          context: {
            'availableGradesCount': _availableGrades.length,
            'selectedGradesCount': setupState.selectedGrades.length,
            'schoolName': setupState.schoolName,
          },
        );
        return TeacherOnboardingStep1Grades(
          selectedGrades: setupState.selectedGrades,
          availableGrades: _availableGrades,
          schoolName: setupState.schoolName.isNotEmpty ? setupState.schoolName : null,
          schoolAddress: setupState.schoolAddress.isNotEmpty ? setupState.schoolAddress : null,
          onRefresh: _loadSchoolInfoAndAvailableData,
        );
      case 2:
        AppLogger.debug('_buildStepContent: Step 2 - Sections',
          category: LogCategory.auth,
          context: {
            'selectedGradesCount': setupState.selectedGrades.length,
            'availableSectionsPerGradeCount': _availableSectionsPerGrade.length,
            'selectedSectionsCount': setupState.sectionsPerGrade.length,
          },
        );
        // DEBUG: Show what's being passed to Step 2 widget
        _availableSectionsPerGrade.forEach((gradeNumber, sections) {
        });
        setupState.sectionsPerGrade.forEach((gradeNumber, sectionNames) {
        });

        return TeacherOnboardingStep2Sections(
          selectedGrades: setupState.selectedGrades,
          availableSectionsPerGrade: _availableSectionsPerGrade,
          sectionsPerGrade: setupState.sectionsPerGrade,
        );
      case 3:
        AppLogger.debug('_buildStepContent: Step 3 - Subjects',
          category: LogCategory.auth,
          context: {
            'selectedGradesCount': setupState.selectedGrades.length,
            'availableSubjectsPerGradeCount': _availableSubjectsPerGrade.length,
            'selectedSubjectsPerSectionCount': setupState.subjectsPerGradeSection.length,
          },
        );
        return TeacherOnboardingStep3Subjects(
          selectedGrades: setupState.selectedGrades,
          availableSectionsPerGrade: _availableSectionsPerGrade,
          availableSubjectsPerGrade: _availableSubjectsPerGrade,
          availableSubjectsPerGradePerSection: _availableSubjectsPerGradePerSection,
          setupState: setupState,
        );
      default:
        AppLogger.warning('_buildStepContent: Unknown step',
          category: LogCategory.auth,
          context: {'currentStep': setupState.currentStep},
        );
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

    AppLogger.debug('_buildNavigationButtons',
      category: LogCategory.auth,
      context: {
        'currentStep': setupState.currentStep,
        'isFirstStep': isFirstStep,
        'isLastStep': isLastStep,
      },
    );

    return Row(
      children: [
        // Previous button
        if (!isFirstStep)
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                AppLogger.info('Previous step clicked',
                  category: LogCategory.auth,
                  context: {'currentStep': setupState.currentStep},
                );
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
                AppLogger.info('Complete button clicked - Saving teacher subjects',
                  category: LogCategory.auth,
                  context: {
                    'currentStep': setupState.currentStep,
                    'selectedGradesCount': setupState.selectedGrades.length,
                    'selectedSectionsCount': setupState.sectionsPerGrade.length,
                    'selectedSubjectsPerSectionCount': setupState.subjectsPerGradeSection.length,
                  },
                );
                // Mark teacher as onboarded and save teacher_subjects
                _markTeacherAsOnboarded(context);
              } else {
                AppLogger.info('Next step clicked',
                  category: LogCategory.auth,
                  context: {
                    'currentStep': setupState.currentStep,
                    'selectedGradesCount': setupState.selectedGrades.length,
                  },
                );
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
    try {
      AppLogger.info('_markTeacherAsOnboarded: Starting completion process',
        category: LogCategory.auth,
      );

      final sl = GetIt.instance;
      final userStateService = sl<UserStateService>();
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      final currentTenant = userStateService.currentTenant;

      if (currentUser == null) {
        AppLogger.warning('Cannot mark teacher as onboarded: no current user',
          category: LogCategory.auth,
        );
        return;
      }

      if (currentTenant == null) {
        AppLogger.warning('Cannot mark teacher as onboarded: no current tenant',
          category: LogCategory.auth,
        );
        return;
      }

      final bloc = _bloc;
      final setupState = bloc.setupState;
      final academicYear = _getAcademicYear();
      final startDate = _getAcademicYearStartDate();
      final endDate = _getAcademicYearEndDate();

      AppLogger.info('_markTeacherAsOnboarded: Academic year calculation',
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
                  .single();

              final catalogSubjectId = catalogResponse['id'] as String;

              // Find the subject record for this tenant
              // NOTE: Admin must have created this subject - teacher can only select from admin-created options
              final subjectsResponse = await supabase
                  .from('subjects')
                  .select('id')
                  .eq('tenant_id', currentTenant.id)
                  .eq('catalog_subject_id', catalogSubjectId);

              if ((subjectsResponse as List).isEmpty) {
                // This should never happen - admin must have created the subject
                AppLogger.error(
                  'Subject not found for teacher onboarding - admin must create subjects',
                  category: LogCategory.auth,
                  context: {
                    'subjectName': subjectName,
                    'catalogSubjectId': catalogSubjectId,
                    'tenantId': currentTenant.id,
                  },
                );
                throw Exception(
                  'Subject "$subjectName" not found. Admin must create subjects first.',
                );
              }

              final subjectId = subjectsResponse[0]['id'] as String;

              // Create teacher_subjects record
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
              AppLogger.error('Error processing subject during onboarding',
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
        AppLogger.info('_markTeacherAsOnboarded: Inserting teacher_subjects records',
          category: LogCategory.auth,
          context: {
            'recordCount': teacherSubjectsToInsert.length,
          },
        );

        // Use upsert in case any conflicts exist
        await supabase
            .from('teacher_subjects')
            .upsert(
              teacherSubjectsToInsert,
              onConflict:
                  'tenant_id,teacher_id,grade_id,subject_id,section,academic_year',
            );

      }

      // Update is_onboarded flag in profiles to mark completion
      AppLogger.info('_markTeacherAsOnboarded: Updating is_onboarded flag',
        category: LogCategory.auth,
        context: {'userId': currentUser.id},
      );

      try {
        await supabase
            .from('profiles')
            .update({'is_onboarded': true})
            .eq('id', currentUser.id);

        AppLogger.info('Teacher onboarded successfully',
          category: LogCategory.auth,
          context: {
            'userId': currentUser.id,
            'teacherSubjectsCount': teacherSubjectsToInsert.length,
            'academicYear': academicYear,
          },
        );
      } catch (updateError) {
        // Log but don't fail - teacher_subjects records are the main indicator
        AppLogger.warning('Failed to update is_onboarded flag (non-critical)',
          category: LogCategory.auth,
          context: {'error': updateError.toString()},
        );
      }

      // After updating database, refresh auth state and navigate
      if (context.mounted) {
        AppLogger.info('_markTeacherAsOnboarded: Refreshing auth state',
          category: LogCategory.auth,
        );
        context.read<AuthBloc>().add(const AuthCheckStatus());

        // Give auth state time to refresh from database before navigating
        Future.delayed(const Duration(seconds: 1), () {
          if (context.mounted) {
            AppLogger.info('_markTeacherAsOnboarded: Navigating to home',
              category: LogCategory.auth,
            );
            context.go(AppRoutes.home);
          }
        });
      }
    } catch (e, _) {
      AppLogger.error('Failed to mark teacher as onboarded',
        category: LogCategory.auth,
        error: e,
      );


      // Still try to navigate even if marking failed
      if (context.mounted) {
        AppLogger.warning('_markTeacherAsOnboarded: Navigation after error',
          category: LogCategory.auth,
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (context.mounted) {
            context.go(AppRoutes.home);
          }
        });
      }
    }
  }
}
