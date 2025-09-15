// lib/core/routes/app_router.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../../../core/main_scaffold/main_scaffold_screen.dart';
import '../../../../core/services/permission_service.dart';
import '../../features/authentication/presentation/bloc/auth_bloc.dart';
import '../../features/authentication/presentation/bloc/auth_event.dart';
import '../../features/authentication/presentation/bloc/auth_state.dart';
import '../../features/authentication/presentation/pages/login_page.dart';
import '../../features/question_papers/presentation/pages/question_bank_page.dart';
import '../../features/question_papers/presentation/pages/question_paper_detail_page.dart';
import '../../features/question_papers/presentation/pages/question_paper_create_page.dart';
import '../../features/question_papers/presentation/admin/admin_dashboard_page.dart';
import '../../features/question_papers/presentation/admin/paper_review_page.dart';
import '../../features/question_papers/presentation/bloc/question_paper_bloc.dart';
import '../di/injection_container.dart';

class AppRouter {
  static GoRouter createRouter(AuthBloc authBloc) {
    return GoRouter(
      initialLocation: '/home',
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      redirect: (context, state) async {
        final authState = authBloc.state;
        final isGoingToLogin = state.matchedLocation == '/login';
        final isGoingToCallback = state.matchedLocation == '/auth/callback';

        if (authState is AuthLoading) {
          return null;
        }

        if (isGoingToCallback) {
          return null;
        }

        if (authState is AuthAuthenticated && isGoingToLogin) {
          return '/home';
        }

        if (authState is! AuthAuthenticated && !isGoingToLogin) {
          return '/login';
        }

        // Admin route protection
        if (state.matchedLocation.startsWith('/admin/')) {
          final isAdmin = await PermissionService.currentUserIsAdmin();
          if (!isAdmin) {
            return '/home';
          }
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
        ),

        GoRoute(
          path: '/auth/callback',
          builder: (context, state) => const OAuthCallbackPage(),
        ),

        GoRoute(
          path: '/home',
          builder: (context, state) {
            return BlocBuilder<AuthBloc, AuthState>(
              builder: (context, authState) {
                if (authState is AuthAuthenticated) {
                  return const MainScaffoldPage();
                }

                if (authState is AuthLoading) {
                  return const Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading...'),
                        ],
                      ),
                    ),
                  );
                }

                return const Scaffold(
                  body: Center(
                    child: Text('Please log in to continue'),
                  ),
                );
              },
            );
          },
        ),

        // Question Paper Management Routes
        GoRoute(
          path: '/question-papers/create',
          builder: (context, state) => BlocProvider(
            create: (context) => QuestionPaperBloc(
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
            ),
            child: const QuestionPaperCreatePage(),
          ),
        ),

        GoRoute(
          path: '/question-papers/view/:id',
          builder: (context, state) {
            final questionPaperId = state.pathParameters['id']!;
            return BlocProvider(
              create: (context) => QuestionPaperBloc(
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
              ),
              child: QuestionPaperDetailPage(
                questionPaperId: questionPaperId,
                isViewOnly: true,
              ),
            );
          },
        ),

        GoRoute(
          path: '/question-papers/edit/:id',
          builder: (context, state) {
            final questionPaperId = state.pathParameters['id']!;
            return BlocProvider(
              create: (context) => QuestionPaperBloc(
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
              ),
              child: QuestionPaperDetailPage(
                questionPaperId: questionPaperId,
                isViewOnly: false,
              ),
            );
          },
        ),

        // =============== ADMIN ROUTES ===============
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) => BlocProvider(
            create: (context) => QuestionPaperBloc(
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
            ),
            child: const AdminDashboardPage(),
          ),
        ),

        GoRoute(
          path: '/admin/review/:id',
          builder: (context, state) {
            final paperId = state.pathParameters['id']!;
            return BlocProvider(
              create: (context) => QuestionPaperBloc(
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
              ),
              child: PaperReviewPage(paperId: paperId),
            );
          },
        ),

        // Backward compatibility routes
        GoRoute(
          path: '/qps/create',
          redirect: (context, state) => '/question-papers/create',
        ),

        GoRoute(
          path: '/qps/view/:id',
          redirect: (context, state) {
            final id = state.pathParameters['id']!;
            return '/question-papers/view/$id';
          },
        ),
        GoRoute(
          path: '/question-bank',
          builder: (context, state) => BlocProvider(
            create: (context) => QuestionPaperBloc(
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
            ),
            child: const QuestionBankPage(),
          ),
        ),

        GoRoute(
          path: '/qps/edit/:id',
          redirect: (context, state) {
            final id = state.pathParameters['id']!;
            return '/question-papers/edit/$id';
          },
        ),
      ],
      // Global error handling
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              SizedBox(height: 16),
              Text(
                'Page Not Found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'The requested page could not be found.',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// OAuth Callback Page
class OAuthCallbackPage extends StatelessWidget {
  const OAuthCallbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/home');
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
          context.go('/login');
        } else if (state is AuthUnauthenticated) {
          context.go('/login');
        }
      },
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Processing authentication...'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  context.read<AuthBloc>().add(const AuthCheckStatus());
                },
                child: const Text('Check Auth Status'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper class to make GoRouter listen to AuthBloc stream
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// Helper extension for easy navigation to admin routes
extension AdminRoutes on BuildContext {
  void goToAdminDashboard() => go('/admin/dashboard');
  void goToReviewPaper(String paperId) => go('/admin/review/$paperId');
}