import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

// Core dependencies
import '../../../features/question_papers/presentation/bloc/question_paper_bloc.dart';
import '../../../features/question_papers/presentation/bloc/grade_bloc.dart';
import '../../../features/question_papers/presentation/pages/question_paper_edit_page.dart';
import '../../../features/shared/presentation/main_scaffold_screen.dart';
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
import '../../../features/question_papers/presentation/admin/admin_dashboard_page.dart';
import '../../../features/question_papers/presentation/admin/paper_review_page.dart';
import '../../../features/question_papers/presentation/pages/question_paper_detail_page.dart';
import '../../../features/question_papers/presentation/pages/question_paper_create_page.dart';
import '../../../features/question_papers/presentation/pages/question_bank_page.dart';

// Widgets and routes
import '../widgets/app_error_widget.dart';
import '../widgets/bloc_provider.dart';
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


  static String? _handleRedirection(BuildContext context, GoRouterState state, AuthBloc authBloc) {
    final authState = authBloc.state;
    final currentLocation = state.matchedLocation;

    AppLogger.info('Router redirect check', category: LogCategory.navigation, context: {
      'currentLocation': currentLocation,
      'authState': authState.runtimeType.toString(),
    });

    // Skip redirection during authentication loading
    if (authState is AuthLoading) {
      AppLogger.info('Skipping redirect - auth loading', category: LogCategory.navigation);
      return null;
    }

    // Allow auth callback always
    if (currentLocation == AppRoutes.authCallback) {
      AppLogger.info('Allowing auth callback', category: LogCategory.navigation);
      return null;
    }

    // Handle authenticated user trying to access login
    if (authState is AuthAuthenticated && currentLocation == AppRoutes.login) {
      AppLogger.info('Redirecting authenticated user to home', category: LogCategory.navigation);
      return AppRoutes.home;
    }

    // Handle unauthenticated user trying to access protected routes
    if (authState is! AuthAuthenticated && RouteGuard.needsAuth(currentLocation)) {
      AppLogger.warning('Redirecting unauthenticated user to login',
          category: LogCategory.navigation,
          context: {'attemptedRoute': currentLocation});
      return AppRoutes.login;
    }

    // SECURITY FIX: Safe admin route protection for Pearl Matric School
    if (RouteGuard.isAdmin(currentLocation)) {
      if (authState is! AuthAuthenticated) {
        AppLogger.warning('Unauthenticated admin access attempt',
            category: LogCategory.navigation,
            context: {'attemptedRoute': currentLocation});
        return AppRoutes.login;
      }

      final authUser = (authState as AuthAuthenticated).user;

      try {
        final userStateService = sl<UserStateService>();
        final stateUser = userStateService.currentUser;

        // SECURITY FIX: Use AuthBloc as primary source of truth
        bool isAdminByAuth = authUser.isAdmin;
        bool isAdminByState = userStateService.isAdmin;

        // Check for consistency
        if (stateUser?.id == authUser.id) {
          // States are consistent, check admin status
          if (!isAdminByAuth || !isAdminByState) {
            AppLogger.warning('Non-admin user attempted admin access',
                category: LogCategory.navigation,
                context: {
                  'attemptedRoute': currentLocation,
                  'userId': authUser.id,
                  'userRole': authUser.role.value,
                  'authAdmin': isAdminByAuth,
                  'stateAdmin': isAdminByState,
                });
            return AppRoutes.home;
          }
        } else {
          // State inconsistency detected
          AppLogger.warning('Auth state inconsistency in admin check',
              category: LogCategory.navigation,
              context: {
                'authUserId': authUser.id,
                'stateUserId': stateUser?.id,
                'securityIssue': 'admin_check_inconsistency',
              });

          // Use AuthBloc state as source of truth for security
          if (!authUser.isAdmin) {
            return AppRoutes.home;
          }

          // Allow access but log the inconsistency
          AppLogger.info('Allowing admin access based on AuthBloc state',
              category: LogCategory.navigation);
        }
      } catch (e) {
        // If UserStateService is not available, fall back to AuthBloc
        AppLogger.warning('UserStateService error in admin check, using AuthBloc fallback',
            category: LogCategory.navigation,
            context: {'error': e.toString()});

        if (!authUser.isAdmin) {
          return AppRoutes.home;
        }
      }
    }

    return null;
  }

  /// Create QuestionPaperBloc with all dependencies
  static QuestionPaperBloc _createQuestionPaperBloc() {
    return QuestionPaperBloc(
      saveDraftUseCase: sl(),

      getExamTypesUseCase: sl(), // ADD THIS LINE
      submitPaperUseCase: sl(),
      getDraftsUseCase: sl(),
      getUserSubmissionsUseCase: sl(),
      approvePaperUseCase: sl(),
      rejectPaperUseCase: sl(),
      getPapersForReviewUseCase: sl(),
      deleteDraftUseCase: sl(),
      pullForEditingUseCase: sl(),
      getPaperByIdUseCase: sl(),
      getAllPapersForAdminUseCase: sl(), // NEW
      getApprovedPapersUseCase: sl(),    // NEW
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
        path: AppRoutes.authCallback,
        builder: (context, state) => const _OAuthCallbackPage(),
      ),

      // Main routes
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => _AuthenticatedBuilder(
          builder: (context, user) => const MainScaffoldPage(),
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
            ],
            child: QuestionPaperEditPage(questionPaperId: id),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.questionBank,
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => _createQuestionPaperBloc()),
            BlocProvider(create: (_) => GradeBloc(repository: sl())),
          ],
          child: const QuestionBankPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.questionPaperCreate,
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => _createQuestionPaperBloc()),
            BlocProvider(create: (_) => GradeBloc(repository: sl())),
          ],
          child: const QuestionPaperCreatePage(),
        ),
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
            ],
            child: const AdminDashboardPage(),
          );
        },
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
class _OAuthCallbackPage extends StatefulWidget {
  const _OAuthCallbackPage();

  @override
  State<_OAuthCallbackPage> createState() => _OAuthCallbackPageState();
}

class _OAuthCallbackPageState extends State<_OAuthCallbackPage> {
  bool _isProcessing = true;
  String _statusMessage = 'Processing authentication...';

  @override
  void initState() {
    super.initState();
    _handleOAuthCallback();
  }

  Future<void> _handleOAuthCallback() async {
    try {
      AppLogger.info('OAuth callback initiated', category: LogCategory.auth);

      setState(() {
        _statusMessage = 'Verifying authentication...';
      });

      // SECURITY FIX: Robust session waiting
      final session = await _waitForSessionWithRetry();

      if (session?.user == null) {
        AppLogger.warning('OAuth callback - no session found', category: LogCategory.auth);
        setState(() {
          _statusMessage = 'Authentication was not completed.';
          _isProcessing = false;
        });

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          context.go(AppRoutes.login);
        }
        return;
      }

      // SECURITY FIX: Validate domain before proceeding
      final email = session!.user.email;
      if (email != null && _isValidDomain(email)) {
        setState(() {
          _statusMessage = 'Authentication successful! Loading your account...';
        });

        if (mounted) {
          context.read<AuthBloc>().add(const AuthCheckStatus());
        }
      } else {
        AppLogger.warning('Unauthorized domain in OAuth callback',
            category: LogCategory.auth,
            context: {
              'email': email,
              'securityViolation': true,
            });

        setState(() {
          _statusMessage = 'Your email domain is not authorized for this application.';
          _isProcessing = false;
        });

        // Sign out unauthorized user
        await Supabase.instance.client.auth.signOut();

        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          context.go(AppRoutes.login);
        }
      }

    } catch (e, stackTrace) {
      AppLogger.error('OAuth callback error',
          error: e,
          stackTrace: stackTrace,
          category: LogCategory.auth
      );

      setState(() {
        _statusMessage = 'Authentication error occurred.';
        _isProcessing = false;
      });

      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        context.go(AppRoutes.login);
      }
    }
  }

  Future<Session?> _waitForSessionWithRetry() async {
    const maxAttempts = 8; // Reduced attempts for faster feedback
    const baseDelay = Duration(milliseconds: 500);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session?.user != null) {
        return session;
      }

      // Exponential backoff with max delay
      final delayMs = (baseDelay.inMilliseconds * (1 << attempt)).clamp(500, 3000);
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    return null;
  }

  bool _isValidDomain(String email) {
    final domain = email.split('@').last.toLowerCase();
    // Pearl Matric School domains
    return domain == 'pearlmatricschool.com' || domain == 'gmail.com';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) => _handleAuthState(context, state),
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isProcessing) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                ],
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                if (!_isProcessing) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go(AppRoutes.login),
                    child: const Text('Return to Login'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleAuthState(BuildContext context, AuthState state) {
    switch (state) {
      case AuthAuthenticated():
        AppLogger.info('OAuth callback successful - user authenticated',
            category: LogCategory.auth,
            context: {
              'userId': state.user.id,
              'userEmail': state.user.email,
            }
        );
        context.go(AppRoutes.home);

      case AuthError():
        AppLogger.error('OAuth callback authentication error',
            category: LogCategory.auth,
            context: {'error': state.message}
        );
        setState(() {
          _statusMessage = 'Authentication failed: ${state.message}';
          _isProcessing = false;
        });

      case AuthUnauthenticated():
        AppLogger.info('OAuth callback - user not authenticated',
            category: LogCategory.auth
        );
        setState(() {
          _statusMessage = 'Authentication was not completed.';
          _isProcessing = false;
        });

      default:
      // Continue processing for AuthLoading or other states
        break;
    }
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