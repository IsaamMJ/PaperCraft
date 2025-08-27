import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../features/authentication/domain/entities/user_entity.dart';
import '../../features/authentication/presentation/pages/login_page.dart';
import '../../features/authentication/presentation/bloc/auth_bloc.dart';
import '../../features/authentication/presentation/bloc/auth_state.dart';
import '../../features/home/presentation/pages/question_paper_edit_screen.dart';
import '../main_scaffold/main_scaffold_screen.dart';

class AppRouter {
  static GoRouter createRouter(AuthBloc authBloc) {
    return GoRouter(
      initialLocation: '/home',
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      redirect: (context, state) {
        final authState = authBloc.state;
        final isGoingToLogin = state.matchedLocation == '/login';

        // If loading, don't redirect yet
        if (authState is AuthLoading) {
          return null;
        }

        // If authenticated and trying to go to login, redirect to home
        if (authState is AuthAuthenticated && isGoingToLogin) {
          return '/home';
        }

        // If not authenticated and not going to login, redirect to login
        if (authState is! AuthAuthenticated && !isGoingToLogin) {
          return '/login';
        }

        return null; // No redirection needed
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
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

                // This should not happen due to redirect, but just in case
                return const Scaffold(
                  body: Center(
                    child: Text('Please log in to continue'),
                  ),
                );
              },
            );
          },
        ),
        GoRoute(
          path: '/qps/:id',
          builder: (context, state) {
            final questionPaperId = state.pathParameters['id']!;
            return QuestionPaperEditScreen(questionPaperId: questionPaperId);
          },
        ),
      ],
    );
  }

  // Keep the old router for fallback (remove this after testing)
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          final user = state.extra as UserEntity?;

          if (user == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/login');
            });
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return MainScaffoldPage();
        },
      ),
      GoRoute(
        path: '/qps/:id',
        builder: (context, state) {
          final questionPaperId = state.pathParameters['id']!;
          final isViewOnly = state.uri.queryParameters['view'] == 'true';

          return QuestionPaperEditScreen(
            questionPaperId: questionPaperId,
            isViewOnly: isViewOnly, // NEW
          );
        },
      ),


    ],
  );
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