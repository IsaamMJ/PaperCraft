import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

// Core dependencies
import '../../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../../features/admin/presentation/pages/admin_setup_wizard_page.dart';
import '../../../features/admin/presentation/pages/admin_assignments_dashboard_page.dart';
import '../../../features/admin/presentation/pages/settings_screen.dart';
import '../../../features/office_staff/presentation/pages/office_staff_dashboard_page.dart';
import '../../../features/office_staff/presentation/pages/office_staff_pdf_preview_page.dart';
import '../../../features/assignments/presentation/bloc/teacher_assignment_bloc.dart';
import '../../../features/assignments/presentation/bloc/teacher_assignment_event.dart';
import '../../../features/assignments/presentation/pages/teacher_assignments_dashboard_page.dart';
import '../../../features/assignments/presentation/pages/teacher_assignment_detail_page_new.dart';
import '../../../features/catalog/presentation/bloc/grade_bloc.dart';
import '../../../features/catalog/presentation/bloc/subject_bloc.dart';
import '../../../features/catalog/presentation/bloc/teacher_pattern_bloc.dart';
import '../../../features/catalog/presentation/pages/grade_management_page.dart';
import '../../../features/catalog/presentation/pages/subject_management_page.dart';
import '../../../features/catalog/presentation/pages/user_management_page.dart';
import '../../../features/onboarding/presentation/pages/teacher_profile_setup_page.dart';
import '../../../features/onboarding/presentation/pages/teacher_onboarding_page.dart';
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
import '../../../features/admin/presentation/pages/exams_dashboard_page.dart';
import '../../../features/catalog/presentation/pages/manage_grade_sections_page.dart';
import '../../../features/catalog/presentation/pages/exam_grade_sections_page.dart';
import '../../../features/catalog/presentation/bloc/grade_section_bloc.dart';
import '../../../features/exams/presentation/pages/exam_calendar_list_page.dart';
import '../../../features/exams/presentation/bloc/exam_calendar_bloc.dart';
import '../../../features/timetable/presentation/pages/exam_timetable_list_page.dart';
import '../../../features/timetable/presentation/pages/exam_timetable_edit_page.dart';
import '../../../features/timetable/presentation/pages/exam_timetable_wizard_page.dart';
import '../../../features/timetable/presentation/bloc/exam_timetable_bloc.dart';
import '../../../features/timetable/presentation/bloc/exam_timetable_wizard_bloc.dart';

// Admin Setup
import '../../../features/admin/presentation/bloc/admin_setup_bloc.dart';
import '../../../features/admin/domain/entities/admin_setup_state.dart';

import '../../domain/interfaces/i_logger.dart';
import '../../infrastructure/di/injection_container.dart';
import '../../infrastructure/logging/app_logger.dart';
import '../../infrastructure/feature_flags/feature_flags.dart';

// Authentication
import '../../../features/authentication/domain/services/user_state_service.dart';
import '../../../features/authentication/domain/entities/user_entity.dart';
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

// Student Management
import '../../../features/student_management/presentation/bloc/student_enrollment_bloc.dart';
import '../../../features/student_management/presentation/bloc/student_management_bloc.dart';
import '../../../features/student_management/presentation/pages/student_list_page.dart';
import '../../../features/student_management/presentation/pages/add_student_page.dart';
import '../../../features/student_management/presentation/pages/bulk_upload_students_page.dart';

// Student Exam Marks
import '../../../features/student_exam_marks/presentation/bloc/marks_entry_bloc.dart';
import '../../../features/student_exam_marks/presentation/pages/marks_entry_screen.dart';

class AppRouter {
  /// Helper function to extract tenantId from AuthBloc state
  /// This is more reliable than UserStateService which is async
  static String _getTenantIdFromAuth(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.user.tenantId ?? '';
    }
    return '';
  }

  /// Helper function to extract userId from AuthBloc state
  static String _getUserIdFromAuth(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.user.id;
    }
    return '';
  }

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
    print('[DEBUG ROUTER] _handleRedirection - currentLocation: $currentLocation, uri: $uri');


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

    // For authenticated users, check initialization status and route accordingly
    if (authState is AuthAuthenticated) {
      // LEVEL 1: Tenant initialization (highest priority)
      // If tenant is not initialized, redirect to admin setup wizard
      // Only admins should see the admin setup wizard
      if (!authState.tenantInitialized && authState.user.role.value == 'admin') {
        return AppRoutes.adminSetupWizard;
      }

      // LEVEL 1.5: Reviewer-only access (high priority)
      // Primary and secondary reviewers have access to:
      // - Admin dashboard (papers for review)
      // - Exams dashboard
      // - Paper view pages
      final userRole = authState.user.role.value;
      if (userRole == 'primary_reviewer' || userRole == 'secondary_reviewer') {
        // Allow access to these routes for reviewers
        final allowedRoutes = [
          AppRoutes.home, // Main scaffold wrapper route
          AppRoutes.adminDashboard,
          AppRoutes.examsHome,
          '/papers/view', // Allow paper viewing
        ];

        final isAllowedRoute = allowedRoutes.any((route) => currentLocation.startsWith(route));

        if (!isAllowedRoute) {
          print('[DEBUG ROUTER] Reviewer trying to access unauthorized route: $currentLocation - redirecting to home with scaffold');
          return AppRoutes.home; // Redirect to home which uses MainScaffoldWrapper
        }
      }

      // LEVEL 2: User onboarding (only for non-admins)
      // If user is not an admin and hasn't completed onboarding, send them there
      if (!authState.userOnboarded && authState.user.role.value != 'admin') {
        return AppRoutes.teacherOnboarding;
      }

      // LEVEL 3: Normal operation - allow navigation
      return null;
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
      restoreSparePaperUseCase: sl(),
      questionPaperRepository: sl(),
      getPapersForReviewUseCase: sl(),
      deleteDraftUseCase: sl(),
      pullForEditingUseCase: sl(),
      getPaperByIdUseCase: sl(),
      getAllPapersForAdminUseCase: sl(),
      getApprovedPapersUseCase: sl(),
      getApprovedPapersPaginatedUseCase: sl(),
      getApprovedPapersByExamDateRangeUseCase: sl(),
      updatePaperUseCase: sl(),
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
          print('[DEBUG ROUTER] Opening QuestionPaperDetailPage (View) with id: $id');
          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => _createQuestionPaperBloc()),
              BlocProvider(create: (_) => GradeBloc(repository: sl())),
              BlocProvider(create: (_) => sl<SubjectBloc>()),
            ],
            child: QuestionPaperDetailPage(
              key: ValueKey(id),
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
            child: QuestionPaperEditPage(
              key: ValueKey(id),
              questionPaperId: id,
            ),
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
            BlocProvider(create: (_) => sl<TeacherAssignmentBloc>()),
            BlocProvider(create: (_) => GradeBloc(repository: sl())),
            BlocProvider(create: (_) => sl<SubjectBloc>()),
          ],
          child: const TeacherAssignmentsDashboardPage(),
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
                create: (_) => sl<TeacherAssignmentBloc>(),
              ),
              BlocProvider(create: (_) => GradeBloc(repository: sl())),
              BlocProvider(create: (_) => sl<GradeSectionBloc>()),
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

      GoRoute(
        path: '${AppRoutes.questionPaperCreate}/:${RouteParams.id}',
        builder: (context, state) {
          final draftId = state.pathParameters[RouteParams.id]!;
          print('[DEBUG ROUTER] Opening QuestionPaperCreatePage with draftId: $draftId');
          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => _createQuestionPaperBloc()),
              BlocProvider(create: (_) => GradeBloc(repository: sl())),
              BlocProvider(create: (_) => sl<SubjectBloc>()),
            ],
            child: QuestionPaperCreatePage(
              key: ValueKey(draftId),
              draftPaperId: draftId,
            ),
          );
        },
      ),

      // Admin routes
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

          // Get tenant ID from authenticated user (more reliable than UserStateService)
          // UserStateService is populated asynchronously, so we use the Auth state
          final authState = context.read<AuthBloc>().state;


          String tenantId = '';
          if (authState is AuthAuthenticated) {
            tenantId = authState.user.tenantId ?? '';
            if (tenantId.isEmpty) {
            }
          } else {
          }


          AppLogger.info('Admin setup wizard loaded',
            category: LogCategory.navigation,
            context: {'tenantId': tenantId},
          );

          return BlocProvider(
            create: (_) => sl<AdminSetupBloc>(),
            child: AdminSetupWizardPage(tenantId: tenantId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.adminAssignmentsDashboard,
        builder: (context, state) {
          AppLogger.info('Admin accessing assignments dashboard', category: LogCategory.navigation);

          // Create an empty setup state for viewing current assignments
          return _AssignmentsDashboardLoader();
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
        path: '${AppRoutes.officeStaffPdfPreview}/:${RouteParams.id}',
        builder: (context, state) {
          final id = state.pathParameters[RouteParams.id]!;
          AppLogger.info('Office staff viewing PDF for paper: $id', category: LogCategory.navigation);
          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => _createQuestionPaperBloc()),
            ],
            child: OfficeStaffPdfPreviewPage(paperId: id),
          );
        },
      ),

      // Removed: Old TeacherAssignmentMatrixPage route - replaced by TeacherAssignmentsDashboardPage
      // GoRoute(
      //   path: AppRoutes.assignmentMatrix,
      //   builder: (context, state) {
      //     AppLogger.info('Admin accessing assignment matrix', category: LogCategory.navigation);
      //     return MultiBlocProvider(
      //       providers: [
      //         BlocProvider(create: (_) => UserManagementBloc(repository: sl())),
      //         BlocProvider(create: (_) => sl<TeacherAssignmentBloc>()),
      //       ],
      //       child: const TeacherAssignmentMatrixPage(),
      //     );
      //   },
      // ),

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

          // Get tenant ID from authenticated user (more reliable than UserStateService)
          final authState = context.read<AuthBloc>().state;
          final tenantId = (authState is AuthAuthenticated)
              ? authState.user.tenantId ?? ''
              : '';

          // Provide AdminSetupBloc for teacher onboarding (reuses same BLoC as admin setup)
          return BlocProvider(
            create: (_) => sl<AdminSetupBloc>(),
            child: TeacherOnboardingPage(tenantId: tenantId),
          );
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

      // Exams Home Dashboard
      GoRoute(
        path: AppRoutes.examsHome,
        builder: (context, state) {
          AppLogger.info('Admin accessing exams management',
              category: LogCategory.navigation);

          final tenantId = _getTenantIdFromAuth(context);

          return ExamsDashboardPage(tenantId: tenantId);
        },
      ),

      // Grade Sections Management
      GoRoute(
        path: AppRoutes.gradeSectionsList,
        builder: (context, state) {
          AppLogger.info('Admin managing grade sections',
              category: LogCategory.navigation);

          final tenantId = _getTenantIdFromAuth(context);

          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => sl<GradeSectionBloc>(),
              ),
              BlocProvider(
                create: (_) => sl<GradeBloc>(),
              ),
            ],
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

          final tenantId = _getTenantIdFromAuth(context);
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

      // Exam Grade Sections Assignment
      GoRoute(
        path: AppRoutes.examGradeSections,
        builder: (context, state) {
          AppLogger.info('Admin assigning grade sections to exam',
              category: LogCategory.navigation);

          final tenantId = _getTenantIdFromAuth(context);
          final examCalendarId = state.uri.queryParameters['calendarId'] ?? '';
          final examCalendarName = state.uri.queryParameters['calendarName'] ?? 'Exam';

          return BlocProvider(
            create: (_) => sl<GradeSectionBloc>(),
            child: ExamGradeSectionsPage(
              tenantId: tenantId,
              examCalendarId: examCalendarId,
              examCalendarName: examCalendarName,
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

          final tenantId = _getTenantIdFromAuth(context);

          try {
            final bloc = sl<ExamTimetableBloc>();
            return BlocProvider.value(
              value: bloc,
              child: ExamTimetableListPage(
                tenantId: tenantId,
              ),
            );
          } catch (e, st) {
            // Try to get any registered types
            rethrow;
          }
        },
      ),

      // Exam Timetable Create/Edit
      GoRoute(
        path: AppRoutes.examTimetableCreate,
        builder: (context, state) {
          AppLogger.info('Admin creating exam timetable',
              category: LogCategory.navigation);

          final tenantId = _getTenantIdFromAuth(context);
          final userId = _getUserIdFromAuth(context);

          final bloc = sl<ExamTimetableBloc>();
          return BlocProvider.value(
            value: bloc,
            child: ExamTimetableEditPage(
              tenantId: tenantId,
              createdBy: userId,
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

          final tenantId = _getTenantIdFromAuth(context);
          final userId = _getUserIdFromAuth(context);

          final bloc = sl<ExamTimetableBloc>();
          return BlocProvider.value(
            value: bloc,
            child: ExamTimetableEditPage(
              tenantId: tenantId,
              createdBy: userId,
              timetableId: timetableId,
            ),
          );
        },
      ),

      // New 3-Step Exam Timetable Wizard
      GoRoute(
        path: '/exam-timetable/wizard',
        name: 'examTimetableWizard',
        builder: (context, state) {
          AppLogger.info('Opening exam timetable wizard',
              category: LogCategory.navigation);

          final tenantId = _getTenantIdFromAuth(context);
          final userId = _getUserIdFromAuth(context);
          final userStateService = sl<UserStateService>();
          final academicYear = userStateService.currentAcademicYear ?? '2024-2025';

          final bloc = sl<ExamTimetableWizardBloc>();
          return BlocProvider.value(
            value: bloc,
            child: ExamTimetableWizardPage(
              tenantId: tenantId,
              userId: userId,
              academicYear: academicYear,
            ),
          );
        },
      ),

      // Student Management routes
      // NOTE: More specific routes (with fixed path segments) MUST come before generic routes with parameters
      GoRoute(
        path: '/students/add',
        name: 'add_student',
        builder: (context, state) {
          return BlocProvider(
            create: (_) => sl<StudentEnrollmentBloc>(),
            child: const AddStudentPage(),
          );
        },
      ),
      GoRoute(
        path: '/students/all',
        name: 'students_all',
        builder: (context, state) {
          return BlocProvider(
            create: (_) => sl<StudentManagementBloc>()
              ..add(const LoadStudentsForGradeSection(gradeSectionId: '')),
            child: const StudentListPage(),
          );
        },
      ),
      GoRoute(
        path: '/students/bulk-upload',
        name: 'bulk_upload_students',
        builder: (context, state) {
          return BlocProvider(
            create: (_) => sl<StudentEnrollmentBloc>(),
            child: const BulkUploadStudentsPage(),
          );
        },
      ),
      GoRoute(
        path: '/students/:gradeSectionId',
        name: 'students_list',
        builder: (context, state) {
          final gradeSectionId = state.pathParameters['gradeSectionId']!;
          return BlocProvider(
            create: (_) => sl<StudentManagementBloc>()
              ..add(LoadStudentsForGradeSection(gradeSectionId: gradeSectionId)),
            child: const StudentListPage(),
          );
        },
      ),
      GoRoute(
        path: '/marks/entry',
        name: 'marks_entry',
        builder: (context, state) {
          final examTimetableEntryId = state.uri.queryParameters['examTimetableEntryId'] ?? '';
          final teacherId = state.uri.queryParameters['teacherId'] ?? '';
          final examName = state.uri.queryParameters['examName'];
          final subjectName = state.uri.queryParameters['subjectName'];
          final gradeName = state.uri.queryParameters['gradeName'];
          final section = state.uri.queryParameters['section'];

          return BlocProvider(
            create: (_) => sl<MarksEntryBloc>(),
            child: MarksEntryScreen(
              examTimetableEntryId: examTimetableEntryId,
              teacherId: teacherId,
              examName: examName,
              subjectName: subjectName,
              gradeName: gradeName,
              section: section,
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
            context.read<TeacherAssignmentBloc>().add(
              LoadTeacherAssignmentsEvent(
                tenantId: teacher.tenantId ?? 'main',
                teacherId: teacher.id,
              ),
            );
          } catch (e) {
            // Teacher not found - handled by detail page error state
          }
        }
      },
      child: BlocBuilder<UserManagementBloc, UserManagementState>(
        builder: (context, state) {
          if (state is UserManagementLoaded) {
            try {
              final teacher =
                  state.users.firstWhere((u) => u.id == teacherId);
              return TeacherAssignmentDetailPageNew(teacher: teacher);
            } catch (e) {
              return Scaffold(
                appBar: AppBar(title: const Text('Teacher Not Found')),
                body: const Center(child: Text('Teacher not found')),
              );
            }
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}

/// Helper widget to load and display the assignments dashboard
class _AssignmentsDashboardLoader extends StatefulWidget {
  const _AssignmentsDashboardLoader({Key? key}) : super(key: key);

  @override
  State<_AssignmentsDashboardLoader> createState() =>
      _AssignmentsDashboardLoaderState();
}

class _AssignmentsDashboardLoaderState extends State<_AssignmentsDashboardLoader> {
  late AdminSetupState _currentSetupState;

  @override
  void initState() {
    super.initState();
    _loadCurrentSetupState();
  }

  void _loadCurrentSetupState() {
    // Get the tenant ID from auth state
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final tenantId = authState.user.tenantId ?? '';
      // Create setup state with empty grades (will be loaded from previous setup)
      _currentSetupState = AdminSetupState(
        tenantId: tenantId,
        selectedGrades: [],
      );
    } else {
      _currentSetupState = const AdminSetupState(
        tenantId: '',
        selectedGrades: [],
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AdminAssignmentsDashboardPage(setupState: _currentSetupState);
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