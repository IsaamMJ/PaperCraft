import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

// Core dependencies
import '../../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../../features/admin/presentation/pages/admin_home_dashboard.dart';
import '../../../features/admin/presentation/pages/admin_setup_wizard_page.dart';
import '../../../features/admin/presentation/pages/settings_screen.dart';
import '../../../features/office_staff/presentation/pages/office_staff_dashboard_page.dart';
import '../../../features/assignments/presentation/bloc/teacher_assignment_bloc.dart';
import '../../../features/assignments/presentation/pages/teacher_assignment_detail_page.dart';
import '../../../features/assignments/presentation/pages/teacher_assignment_management_page.dart';
import '../../../features/assignments/presentation/pages/teacher_assignment_matrix_page.dart';
import '../../../features/catalog/presentation/bloc/grade_bloc.dart';
import '../../../features/catalog/presentation/bloc/subject_bloc.dart';
import '../../../features/catalog/presentation/bloc/teacher_pattern_bloc.dart';
import '../../../features/catalog/presentation/pages/grade_management_page.dart';
import '../../../features/catalog/presentation/pages/subject_management_page.dart';
import '../../../features/catalog/presentation/pages/user_management_page.dart';
import '../../../features/onboarding/presentation/pages/teacher_profile_setup_page.dart';
import '../../../features/onboarding/presentation/pages/teacher_onboarding_page.dart';
import '../../../features/onboarding/presentation/pages/solo_teacher_onboarding_page.dart';
import '../../../features/paper_review/presentation/pages/paper_review_page.dart';
import '../../../features/paper_workflow/presentation/bloc/question_paper_bloc.dart';
import '../../../features/notifications/presentation/bloc/notification_bloc.dart';
import '../../../features/notifications/presentation/pages/notifications_page.dart';
import '../../../features/paper_workflow/presentation/bloc/user_management_bloc.dart';
import '../../../features/paper_creation/presentation/pages/question_paper_edit_page.dart';
import '../../../features/paper_workflow/presentation/pages/question_paper_detail_page.dart';
import '../../../features/question_bank/presentation/pages/question_bank_page.dart';
import '../../../features/question_bank/presentation/bloc/question_bank_bloc.dart';
import '../../../features/shared/presentation/main_scaffold_wrapper.dart';

// Exam Timetable Management
import '../../../features/catalog/presentation/pages/manage_grade_sections_page.dart';
import '../../../features/catalog/presentation/bloc/grade_section_bloc.dart';
import '../../../features/exams/presentation/pages/exam_calendar_list_page.dart';
import '../../../features/exams/presentation/bloc/exam_calendar_bloc.dart';
import '../../../features/exams/presentation/pages/exam_timetable_list_page.dart';
import '../../../features/exams/presentation/pages/exam_timetable_edit_page.dart';
import '../../../features/exams/presentation/bloc/exam_timetable_bloc.dart';

// Admin Setup
import '../../../features/admin/presentation/bloc/admin_setup_bloc.dart';

import '../../domain/interfaces/i_logger.dart';
import '../../infrastructure/di/injection_container.dart';
import '../../infrastructure/logging/app_logger.dart';
import '../../infrastructure/feature_flags/feature_flags.dart';

// Authentication
import '../../../features/authentication/domain/services/user_state_service.dart';
import '../../../features/authentication/presentation/bloc/auth_bloc.dart';
import '../../../features/authentication/presentation/bloc/auth_event.dart';
import '../../../features/authentication/presentation/bloc/auth_state.dart';
import '../../../features/authentication/presentation/pages/login_page.dart';

// Question papers
import '../../../features/paper_creation/presentation/pages/question_paper_create_page.dart';

// Widgets and routes
import '../constants/ui_constants.dart';
import '../constants/app_colors.dart';
import '../widgets/app_error_widget.dart';
import '../constants/app_messages.dart';
import 'app_routes.dart';

class AppRouter {
  static GoRouter createRouter(AuthBloc authBloc) {
    AppLogger.info('Creating app router', category: LogCategory.navigation);

    return GoRouter(
      initialLocation: AppRoutes.home,
      refreshListenable: _GoRouterRefreshStream(authBloc.stream),
      redirect: (context, state) => _handleRedirection(context, state, authBloc),
      routes: _buildRoutes(),
      errorBuilder: (context, state) => AppErrorWidget(
        title: AppMessages.pageNotFound,
        message: AppMessages.pageNotFoundDescription,
        error: state.error,
        showError: FeatureFlags.enableDebugLogging,
      ),
    );
  }

  /// Handle authentication and authorization redirects
  // In your _handleRedirection method, replace the OAuth callback detection section:

  // REPLACE the entire _handleRedirection method in app_router.dart:

  static String? _handleRedirection(BuildContext context, GoRouterState state, AuthBloc authBloc) {
    final authState = authBloc.state;
    final currentLocation = state.matchedLocation;
    final uri = state.uri;


    // ✅ FIRST: Check if we're ALREADY on the auth callback page
    if (currentLocation == AppRoutes.authCallback) {
      return null;
    }

    // ✅ SECOND: Check for OAuth code in query params (BEFORE any other checks)
    if (uri.queryParameters.containsKey('code')) {
      return AppRoutes.authCallback;
    }

    // ⏳ Skip redirection during authentication loading
    if (authState is AuthLoading) {
      return null;
    }

    // Handle authenticated user trying to access login
    if (authState is AuthAuthenticated && currentLocation == AppRoutes.login) {
      return AppRoutes.home;
    }

    // Handle first-time user login with onboarding
    if (authState is AuthAuthenticated) {
      final isFirstLogin = authState.isFirstLogin;
      final isAdmin = authState.user.isAdmin;
      final isTeacher = authState.user.isTeacher;

      // If user is on any onboarding or profile setup route, don't redirect them away
      // Let the page logic handle navigation based on tenant initialization state
      if (currentLocation == AppRoutes.adminSetupWizard ||
          currentLocation == AppRoutes.teacherOnboarding ||
          currentLocation == AppRoutes.soloTeacherOnboarding ||
          currentLocation == AppRoutes.teacherProfileSetup ||
          currentLocation == AppRoutes.home) {
        return null;
      }

      // Redirect on first login if tenant not initialized
      if (isFirstLogin) {
        try {
          final userStateService = sl<UserStateService>();
          final currentTenant = userStateService.currentTenant;

          AppLogger.info('First-time user redirect check',
            category: LogCategory.auth,
            context: {
              'hasTenant': currentTenant != null,
              'tenantId': currentTenant?.id,
              'tenantDomain': currentTenant?.domain,
              'currentLocation': currentLocation,
            }
          );

          if (currentTenant == null) {
            AppLogger.warning('Tenant is NULL, cannot redirect',
              category: LogCategory.auth);
            return null;
          }

          final isTenantInitialized = currentTenant.isInitialized;

          AppLogger.info('Tenant found for first-time user',
            category: LogCategory.auth,
            context: {
              'tenantId': currentTenant.id,
              'tenantDomain': currentTenant.domain,
              'isTenantInitialized': isTenantInitialized,
            }
          );

          // ✅ If tenant not initialized, route to appropriate onboarding
          if (!isTenantInitialized) {
            // Check if this is a solo tenant (personal email with no domain)
            final isSoloTenant = currentTenant.domain == null || currentTenant.domain!.isEmpty;

            AppLogger.info('Routing first-time user to onboarding',
              category: LogCategory.auth,
              context: {
                'userRole': authState.user.role.value,
                'isSoloTenant': isSoloTenant,
                'tenantDomain': currentTenant.domain,
                'isFirstLogin': isFirstLogin,
              }
            );

            if (isSoloTenant && isAdmin) {
              // Solo teacher (Gmail user) → 2-step onboarding (grades + subjects only)
              AppLogger.debug('Redirecting solo teacher to setup wizard',
                category: LogCategory.auth);
              return AppRoutes.soloTeacherOnboarding;
            } else if (!isSoloTenant && isAdmin) {
              // School admin (first user from domain) → 4-step setup wizard
              AppLogger.debug('Redirecting school admin to setup wizard',
                category: LogCategory.auth);
              return AppRoutes.adminSetupWizard;
            } else if (!isSoloTenant && isTeacher) {
              // School teacher (subsequent user from domain) → 3-step onboarding
              AppLogger.debug('Redirecting school teacher to onboarding',
                category: LogCategory.auth);
              return AppRoutes.teacherOnboarding;
            } else {
              AppLogger.warning('Unknown onboarding scenario',
                category: LogCategory.auth,
                context: {
                  'userRole': authState.user.role.value,
                  'isSoloTenant': isSoloTenant,
                }
              );
            }
          } else {
            // ✅ Tenant initialized, go to profile setup or home
            if (isTeacher) {
              return AppRoutes.teacherProfileSetup;
            }
            // Admins go to dashboard after initialization
          }
        } catch (e, stackTrace) {
          AppLogger.error('Exception in first-time user redirect',
            error: e,
            stackTrace: stackTrace,
            category: LogCategory.auth,
            context: {
              'operation': 'first_time_user_redirect',
              'errorType': e.runtimeType.toString(),
            }
          );
          return null;
        }
      }
    }

    // Handle unauthenticated user trying to access protected routes
    if (authState is! AuthAuthenticated && RouteGuard.needsAuth(currentLocation)) {
      return AppRoutes.login;
    }

    // SECURITY FIX: Safe admin route protection
    if (RouteGuard.isAdmin(currentLocation)) {
      if (authState is! AuthAuthenticated) {
        return AppRoutes.login;
      }

      final authUser = authState.user;

      try {
        final userStateService = sl<UserStateService>();
        final stateUser = userStateService.currentUser;

        bool isAdminByAuth = authUser.isAdmin;
        bool isAdminByState = userStateService.isAdmin;

        if (stateUser?.id == authUser.id) {
          if (!isAdminByAuth || !isAdminByState) {
            return AppRoutes.home;
          }
        } else {
          if (!authUser.isAdmin) {
            return AppRoutes.home;
          }
        }
      } catch (e) {
        if (!authUser.isAdmin) {
          return AppRoutes.home;
        }
      }
    }

    // Office staff route protection
    if (RouteGuard.isOfficeStaff(currentLocation)) {
      if (authState is! AuthAuthenticated) {
        return AppRoutes.login;
      }

      final authUser = authState.user;

      try {
        final userStateService = sl<UserStateService>();
        final isOfficeStaff = authUser.role.value == 'office_staff';
        final isAdmin = authUser.isAdmin;

        if (!isOfficeStaff && !isAdmin) {
          return AppRoutes.home;
        }
      } catch (e) {
        return AppRoutes.home;
      }
    }

    return null;
  }

  /// Create QuestionPaperBloc with all dependencies
  static QuestionPaperBloc _createQuestionPaperBloc() {
    return QuestionPaperBloc(
      saveDraftUseCase: sl(),
      submitPaperUseCase: sl(),
      getDraftsUseCase: sl(),
      getUserSubmissionsUseCase: sl(),
      approvePaperUseCase: sl(),
      rejectPaperUseCase: sl(),
      getPapersForReviewUseCase: sl(),
      deleteDraftUseCase: sl(),
      pullForEditingUseCase: sl(),
      getPaperByIdUseCase: sl(),
      getAllPapersForAdminUseCase: sl(),
      getApprovedPapersUseCase: sl(),
      getApprovedPapersPaginatedUseCase: sl(),
      getApprovedPapersByExamDateRangeUseCase: sl(),
    );
  }

  /// Build all application routes
  static List<RouteBase> _buildRoutes() {
    return [
      // Authentication routes
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => _AuthenticatedBuilder(
          builder: (context, user) => const SettingsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => BlocProvider(
          create: (_) => NotificationBloc(
            getUserNotificationsUseCase: sl(),
            getUnreadCountUseCase: sl(),
            markNotificationReadUseCase: sl(),
            logger: sl<ILogger>(),
          ),
          child: const NotificationsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.authCallback,
        redirect: (context, state) async {
          // OAuth callback - just redirect based on auth state
          final supabase = Supabase.instance.client;
          final user = supabase.auth.currentUser;

          if (user != null) {
            return AppRoutes.home; // User authenticated
          }
          return AppRoutes.login; // Not authenticated
        },
      ),

      // Main routes
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => _AuthenticatedBuilder(
          builder: (context, user) => const MainScaffoldWrapper(),
        ),
      ),

      // Question paper routes
      GoRoute(
        path: '${AppRoutes.questionPaperView}/:${RouteParams.id}',
        builder: (context, state) {
          final id = state.pathParameters[RouteParams.id]!;
          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => _createQuestionPaperBloc()),
              BlocProvider(create: (_) => GradeBloc(repository: sl())),
              BlocProvider(create: (_) => sl<SubjectBloc>()),
            ],
            child: QuestionPaperDetailPage(
              questionPaperId: id,
              isViewOnly: false,
            ),
          );
        },
      ),

      GoRoute(
        path: '${AppRoutes.questionPaperEdit}/:${RouteParams.id}',
        builder: (context, state) {
          final id = state.pathParameters[RouteParams.id]!;
          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => _createQuestionPaperBloc()),
              BlocProvider(create: (_) => GradeBloc(repository: sl())),
              BlocProvider(create: (_) => sl<SubjectBloc>()),
              BlocProvider(create: (_) => sl<TeacherPatternBloc>()), // Add TeacherPatternBloc for pattern loading
            ],
            child: QuestionPaperEditPage(questionPaperId: id),
          );
        },
      ),

      GoRoute(
        path: AppRoutes.questionBank,
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => sl<QuestionBankBloc>()),
            BlocProvider(create: (_) => GradeBloc(repository: sl())),
            BlocProvider(create: (_) => sl<SubjectBloc>()),
          ],
          child: const QuestionBankPage(),
        ),
      ),

      // Replace your teacherAssignments route in app_router.dart with this:

      GoRoute(
        path: AppRoutes.teacherAssignments,
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => UserManagementBloc()),
            // Add the missing bloc providers
            BlocProvider(create: (_) => GradeBloc(repository: sl())),
            BlocProvider(create: (_) => sl<SubjectBloc>()),
          ],
          child: const TeacherAssignmentManagementPage(),
        ),
      ),

      GoRoute(
        path: '${AppRoutes.teacherAssignments}/:${RouteParams.id}',
        builder: (context, state) {
          final teacherId = state.pathParameters[RouteParams.id]!;

          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => UserManagementBloc()..add(const LoadUsers())),
              BlocProvider(
                create: (_) => TeacherAssignmentBloc(
                  sl(), // AssignmentRepository
                  sl(), // GradeRepository
                  sl(), // SubjectRepository
                  sl(), // UserStateService
                ),
              ),
              BlocProvider(create: (_) => GradeBloc(repository: sl())),
              BlocProvider(create: (_) => sl<SubjectBloc>()),
            ],
            child: _TeacherAssignmentDetailLoader(teacherId: teacherId),
          );
        },
      ),


      GoRoute(
        path: AppRoutes.questionPaperCreate,
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => _createQuestionPaperBloc()),
            BlocProvider(create: (_) => GradeBloc(repository: sl())),
            BlocProvider(create: (_) => sl<SubjectBloc>()),
          ],
          child: const QuestionPaperCreatePage(),
        ),
      ),

      // Admin routes
      GoRoute(
        path: AppRoutes.adminHome,
        builder: (context, state) {
          AppLogger.info('Admin accessing home dashboard', category: LogCategory.navigation);
          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => UserManagementBloc(repository: sl())),
              BlocProvider(create: (_) => GradeBloc(repository: sl())),
              BlocProvider(create: (_) => sl<SubjectBloc>()),
            ],
            child: const AdminHomeDashboard(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (context, state) {
          AppLogger.info('Admin accessing dashboard', category: LogCategory.navigation);
          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => _createQuestionPaperBloc()),
              BlocProvider(create: (_) => GradeBloc(repository: sl())),
              BlocProvider(create: (_) => sl<SubjectBloc>()),
            ],
            child: const AdminDashboardPage(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.adminSetupWizard,
        builder: (context, state) {
          AppLogger.info('Admin accessing setup wizard', category: LogCategory.navigation);

          // Get tenant ID from user state
          final userStateService = sl<UserStateService>();
          final tenantId = userStateService.currentTenant?.id ?? '';

          return BlocProvider(
            create: (_) => sl<AdminSetupBloc>(),
            child: AdminSetupWizardPage(tenantId: tenantId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.officeStaffDashboard,
        builder: (context, state) {
          AppLogger.info('Office staff accessing dashboard', category: LogCategory.navigation);
          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => _createQuestionPaperBloc()),
              BlocProvider(create: (_) => GradeBloc(repository: sl())),
              BlocProvider(create: (_) => sl<SubjectBloc>()),
            ],
            child: const OfficeStaffDashboardPage(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.assignmentMatrix,
        builder: (context, state) {
          AppLogger.info('Admin accessing assignment matrix', category: LogCategory.navigation);
          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => UserManagementBloc(repository: sl())),
              BlocProvider(create: (_) => TeacherAssignmentBloc(
                sl(),
                sl(),
                sl(),
                sl(),
              )),
            ],
            child: const TeacherAssignmentMatrixPage(),
          );
        },
      ),

      // Settings management routes
      GoRoute(
        path: AppRoutes.settingsSubjects,
        builder: (context, state) => BlocProvider(
          create: (_) => sl<SubjectBloc>(),
          child: const SubjectManagementPage(),
        ),
      ),

      GoRoute(
        path: AppRoutes.settingsGrades,
        builder: (context, state) => BlocProvider(
          create: (_) => GradeBloc(repository: sl()),
          child: const GradeManagementPage(),
        ),
      ),

      GoRoute(
        path: AppRoutes.settingsUsers,
        builder: (context, state) => BlocProvider(
          create: (_) => UserManagementBloc(),
          child: const UserManagementPage(),
        ),
      ),

      GoRoute(
        path: AppRoutes.teacherOnboarding,
        builder: (context, state) {
          AppLogger.info('Teacher accessing onboarding wizard', category: LogCategory.navigation);
          final userStateService = sl<UserStateService>();
          final tenantId = userStateService.currentTenant?.id ?? '';
          return TeacherOnboardingPage(tenantId: tenantId);
        },
      ),

      GoRoute(
        path: AppRoutes.soloTeacherOnboarding,
        builder: (context, state) {
          AppLogger.info('Solo teacher accessing onboarding wizard', category: LogCategory.navigation);
          final userStateService = sl<UserStateService>();
          final tenantId = userStateService.currentTenant?.id ?? '';
          return SoloTeacherOnboardingPage(tenantId: tenantId);
        },
      ),

      GoRoute(
        path: AppRoutes.teacherProfileSetup,
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => GradeBloc(repository: sl())),
            BlocProvider(create: (_) => sl<SubjectBloc>()),
          ],
          child: const TeacherProfileSetupPage(),
        ),
      ),

      GoRoute(
        path: '${AppRoutes.adminReview}/:${RouteParams.id}',
        builder: (context, state) {
          final id = state.pathParameters[RouteParams.id]!;
          AppLogger.info('Admin reviewing paper',
              category: LogCategory.navigation,
              context: {'paperId': id});
          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => _createQuestionPaperBloc()),
              BlocProvider(create: (_) => GradeBloc(repository: sl())),
              BlocProvider(create: (_) => sl<SubjectBloc>()),
            ],
            child: PaperReviewPage(paperId: id),
          );
        },
      ),

      // ========== EXAM TIMETABLE MANAGEMENT ROUTES ==========

      // Grade Sections Management
      GoRoute(
        path: AppRoutes.gradeSectionsList,
        builder: (context, state) {
          AppLogger.info('Admin managing grade sections',
              category: LogCategory.navigation);

          // Get tenant ID from user state
          final userStateService = sl<UserStateService>();
          final tenantId = userStateService.currentTenant?.id ?? '';

          return BlocProvider(
            create: (_) => sl<GradeSectionBloc>(),
            child: ManageGradeSectionsPage(tenantId: tenantId),
          );
        },
      ),

      // Exam Calendar Management
      GoRoute(
        path: AppRoutes.examCalendarList,
        builder: (context, state) {
          AppLogger.info('Admin managing exam calendar',
              category: LogCategory.navigation);

          final userStateService = sl<UserStateService>();
          final tenantId = userStateService.currentTenant?.id ?? '';
          final academicYear = state.uri.queryParameters['academicYear'] ?? '2024-2025';

          return BlocProvider(
            create: (_) => sl<ExamCalendarBloc>(),
            child: ExamCalendarListPage(
              tenantId: tenantId,
              academicYear: academicYear,
            ),
          );
        },
      ),

      // Exam Timetable List
      GoRoute(
        path: AppRoutes.examTimetableList,
        builder: (context, state) {
          AppLogger.info('Admin viewing exam timetables',
              category: LogCategory.navigation);

          final userStateService = sl<UserStateService>();
          final tenantId = userStateService.currentTenant?.id ?? '';
          final academicYear = state.uri.queryParameters['academicYear'] ?? '2024-2025';

          return BlocProvider(
            create: (_) => sl<ExamTimetableBloc>(),
            child: ExamTimetableListPage(
              tenantId: tenantId,
              academicYear: academicYear,
            ),
          );
        },
      ),

      // Exam Timetable Create/Edit
      GoRoute(
        path: AppRoutes.examTimetableCreate,
        builder: (context, state) {
          AppLogger.info('Admin creating exam timetable',
              category: LogCategory.navigation);

          final userStateService = sl<UserStateService>();
          final currentUser = userStateService.currentUser;
          final tenantId = userStateService.currentTenant?.id ?? '';

          return BlocProvider(
            create: (_) => sl<ExamTimetableBloc>(),
            child: ExamTimetableEditPage(
              tenantId: tenantId,
              createdBy: currentUser?.id ?? '',
              examCalendarId: state.uri.queryParameters['calendarId'],
            ),
          );
        },
      ),

      GoRoute(
        path: '${AppRoutes.examTimetableEdit}/:${RouteParams.id}',
        builder: (context, state) {
          final timetableId = state.pathParameters[RouteParams.id]!;
          AppLogger.info('Admin editing exam timetable',
              category: LogCategory.navigation,
              context: {'timetableId': timetableId});

          final userStateService = sl<UserStateService>();
          final currentUser = userStateService.currentUser;
          final tenantId = userStateService.currentTenant?.id ?? '';

          return BlocProvider(
            create: (_) => sl<ExamTimetableBloc>(),
            child: ExamTimetableEditPage(
              tenantId: tenantId,
              createdBy: currentUser?.id ?? '',
              timetableId: timetableId,
            ),
          );
        },
      ),
    ];
  }
}

/// Widget that builds content only when user is authenticated
class _AuthenticatedBuilder extends StatelessWidget {
  const _AuthenticatedBuilder({required this.builder});

  final Widget Function(BuildContext, dynamic) builder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is AuthAuthenticated) {
          return builder(context, authState.user);
        }
        if (authState is AuthLoading) {
          return const AppLoadingWidget();
        }
        return const AppMessageWidget(message: AppMessages.pleaseLogin);
      },
    );
  }
}


/// Helper widget to load teacher data before showing detail page
class _TeacherAssignmentDetailLoader extends StatelessWidget {
  final String teacherId;

  const _TeacherAssignmentDetailLoader({required this.teacherId});

  @override
  Widget build(BuildContext context) {
    return BlocListener<UserManagementBloc, UserManagementState>(
      listener: (context, state) {
        if (state is UserManagementLoaded) {
          try {
            final teacher = state.users.firstWhere((u) => u.id == teacherId);
            context.read<TeacherAssignmentBloc>().add(LoadTeacherAssignments(teacher));
          } catch (e) {
            // Teacher not found - handled by detail page error state
          }
        }
      },
      child: TeacherAssignmentDetailPage(teacherId: teacherId),
    );
  }
}

/// Helper class for GoRouter refresh stream
class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}