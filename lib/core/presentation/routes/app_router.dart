import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

// Core dependencies
import '../../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../../features/admin/presentation/pages/admin_home_dashboard.dart';
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
import '../../../features/onboarding/presentation/pages/tenant_onboarding_page.dart';
import '../../../features/onboarding/presentation/pages/teacher_profile_setup_page.dart';
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

    // Handle first-time teacher login
    if (authState is AuthAuthenticated) {
      final isFirstLogin = authState.isFirstLogin;
      final isTeacher = authState.user.isTeacher;

      if (isFirstLogin && isTeacher &&
          currentLocation != AppRoutes.onboarding &&
          currentLocation != AppRoutes.teacherProfileSetup &&
          currentLocation != AppRoutes.home) {

        try {
          final userStateService = sl<UserStateService>();
          final currentTenant = userStateService.currentTenant;

          if (currentTenant == null) {
            return null;
          }

          final isTenantInitialized = currentTenant.isInitialized;

          if (!isTenantInitialized) {
            return AppRoutes.onboarding;
          } else {
            return AppRoutes.teacherProfileSetup;
          }
        } catch (e) {
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
        builder: (context, state) => const _OAuthCallbackPage(),
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
        path: AppRoutes.onboarding,
        builder: (context, state) => const TenantOnboardingPage(),
      ),

      GoRoute(
        path: AppRoutes.teacherOnboarding,
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => GradeBloc(repository: sl())),
            BlocProvider(create: (_) => sl<SubjectBloc>()),
          ],
          child: const TenantOnboardingPage(isTeacherOnboarding: true),
        ),
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

/// OAuth callback page with proper state handling
/// OAuth callback page with proper state handling and ENHANCED DEBUGGING
/// OAuth callback page with AGGRESSIVE DEBUGGING
class _OAuthCallbackPage extends StatefulWidget {
  const _OAuthCallbackPage();

  @override
  State<_OAuthCallbackPage> createState() => _OAuthCallbackPageState();
}

class _OAuthCallbackPageState extends State<_OAuthCallbackPage> {
  bool _isProcessing = true;
  String _statusMessage = 'Initializing OAuth callback...';
  String _debugLog = '';

  void _addLog(String msg) {
    setState(() {
      _debugLog += '$msg\n';
    });
  }

  @override
  void initState() {
    super.initState();
    _addLog('🔐 [INIT] _OAuthCallbackPage.initState() called');
    _handleOAuthCallback();
  }

  Future<void> _handleOAuthCallback() async {
    try {
      _addLog('🔐 [START] _handleOAuthCallback() started');

      // Get current Supabase state
      final supabase = Supabase.instance.client;
      final currentSession = supabase.auth.currentSession;
      final currentUser = supabase.auth.currentUser;

      _addLog('🔐 [CHECK] Initial Supabase state:');
      _addLog('   - Has session: ${currentSession != null}');
      _addLog('   - Session user ID: ${currentSession?.user.id}');
      _addLog('   - Current user ID: ${currentUser?.id}');
      _addLog('   - Current user email: ${currentUser?.email}');

      // Wait for session with detailed logging
      _addLog('🔐 [WAIT] Starting session wait...');
      final session = await _waitForSessionWithRetry();

      _addLog('🔐 [RESULT] Session wait completed');
      _addLog('   - Session: $session');
      _addLog('   - Has user: ${session?.user != null}');
      _addLog('   - User ID: ${session?.user?.id}');
      _addLog('   - User email: ${session?.user?.email}');

      if (session?.user == null) {
        _addLog('❌ [ERROR] No session found - redirecting to login');
        setState(() {
          _statusMessage = 'No authentication session found.';
          _isProcessing = false;
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          _addLog('➡️ [REDIRECT] Going to login');
          context.go(AppRoutes.login);
        }
        return;
      }

      final email = session!.user.email;
      final isValidDomain = _isValidDomain(email ?? '');

      _addLog('🔐 [DOMAIN] Email: $email');
      _addLog('🔐 [DOMAIN] Is valid: $isValidDomain');

      if (email != null && isValidDomain) {
        _addLog('✅ [VALID] Domain is valid');
        setState(() {
          _statusMessage = 'Loading your account...';
        });

        if (mounted) {
          _addLog('🔐 [BLOC] Getting AuthBloc...');
          final authBloc = context.read<AuthBloc>();
          _addLog('🔐 [BLOC] Current AuthBloc state: ${authBloc.state.runtimeType}');
          _addLog('🔐 [BLOC] Adding AuthCheckStatus event');

          authBloc.add(const AuthCheckStatus());

          _addLog('✅ [BLOC] AuthCheckStatus event added');
          _addLog('🔐 [BLOC] Waiting 1 second for state update...');

          await Future.delayed(const Duration(seconds: 1));

          _addLog('🔐 [BLOC] Current AuthBloc state now: ${authBloc.state.runtimeType}');

          if (authBloc.state is AuthAuthenticated) {
            _addLog('✅ [SUCCESS] AuthBloc is now AuthAuthenticated');
            _addLog('   - User: ${(authBloc.state as AuthAuthenticated).user.id}');
          } else if (authBloc.state is AuthLoading) {
            _addLog('⏳ [WAITING] AuthBloc still loading...');
          } else if (authBloc.state is AuthError) {
            _addLog('❌ [ERROR] AuthBloc has error: ${(authBloc.state as AuthError).message}');
          } else {
            _addLog('ⓘ [OTHER] AuthBloc state: ${authBloc.state.runtimeType}');
          }
        }
      } else {
        _addLog('❌ [INVALID] Invalid domain: $email');
        await Supabase.instance.client.auth.signOut();
        setState(() {
          _statusMessage = 'Organization not authorized.';
          _isProcessing = false;
        });
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          context.go(AppRoutes.login);
        }
      }
    } catch (e, stackTrace) {
      _addLog('❌ [EXCEPTION] $e');
      _addLog('📍 Stack: $stackTrace');
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
        _isProcessing = false;
      });
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        context.go(AppRoutes.login);
      }
    }
  }

  Future<Session?> _waitForSessionWithRetry() async {
    const maxAttempts = 10;
    const baseDelay = Duration(milliseconds: 500);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final session = Supabase.instance.client.auth.currentSession;
      final user = session?.user;

      _addLog('🔐 [ATTEMPT ${attempt + 1}/$maxAttempts]');
      _addLog('   - Has session: ${session != null}');
      _addLog('   - Has user: ${user != null}');
      _addLog('   - User ID: ${user?.id}');

      if (user != null) {
        _addLog('✅ [FOUND] Session found at attempt ${attempt + 1}');
        return session;
      }

      final delayMs = (baseDelay.inMilliseconds * (1 << attempt)).clamp(500, 5000);
      _addLog('⏳ [DELAY] Waiting ${delayMs}ms...');
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    _addLog('❌ [TIMEOUT] No session after $maxAttempts attempts');
    return null;
  }

  bool _isValidDomain(String email) {
    final domain = email.split('@').last.toLowerCase();
    final isValid = domain == 'pearlmatricschool.com' || domain == 'gmail.com';
    _addLog('   - Domain: $domain = $isValid');
    return isValid;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: _handleAuthState,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(UIConstants.paddingLarge),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isProcessing)
                  SizedBox(
                    width: UIConstants.iconXLarge,
                    height: UIConstants.iconXLarge,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  )
                else
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: UIConstants.spacing24),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeLarge,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: UIConstants.spacing24),
                if (!_isProcessing)
                  Padding(
                    padding: EdgeInsets.only(top: UIConstants.spacing24),
                    child: ElevatedButton(
                      onPressed: () => context.go(AppRoutes.login),
                      child: const Text('Return to Login'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleAuthState(BuildContext context, AuthState state) {
    _addLog('🔐 [STATE CHANGE] ${state.runtimeType}');

    if (state is AuthAuthenticated) {
      _addLog('✅ [SUCCESS] User authenticated: ${state.user.id}');
      _addLog('➡️ [NAVIGATE] Going to home');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          context.go(AppRoutes.home);
        }
      });
    } else if (state is AuthError) {
      _addLog('❌ [ERROR STATE] ${state.message}');
      setState(() {
        _statusMessage = 'Error: ${state.message}';
        _isProcessing = false;
      });
    } else if (state is AuthLoading) {
      _addLog('⏳ [LOADING] Auth is loading...');
    } else {
      _addLog('ⓘ [OTHER] State: ${state.runtimeType}');
    }
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