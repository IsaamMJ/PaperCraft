import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/sign_out.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SignInWithGoogle _signInWithGoogle;
  final GetCurrentUser _getCurrentUser;
  final SignOut _signOutUseCase;

  AuthBloc({
    required SignInWithGoogle signInWithGoogle,
    required GetCurrentUser getCurrentUser,
    required SignOut signOutUseCase,
  }) : _signInWithGoogle = signInWithGoogle,
        _getCurrentUser = getCurrentUser,
        _signOutUseCase = signOutUseCase,
        super(AuthInitial()) {
    on<AppStartedEvent>(_onAppStarted);
    on<SignInWithGoogleEvent>(_onSignInWithGoogle);
    on<GetCurrentUserEvent>(_onGetCurrentUser);
    on<SignOutEvent>(_onSignOut);

    // Check current user when bloc is created
    add(AppStartedEvent());
  }

  Future<void> _onAppStarted(
      AppStartedEvent event,
      Emitter<AuthState> emit,
      ) async {
    emit(AuthLoading());

    try {
      final user = await _getCurrentUser();
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(_formatError(e)));
    }
  }

  Future<void> _onSignInWithGoogle(
      SignInWithGoogleEvent event,
      Emitter<AuthState> emit,
      ) async {
    // Don't emit loading if already authenticated
    if (state is! AuthAuthenticated) {
      emit(AuthLoading());
    }

    try {
      final (user, _) = await _signInWithGoogle();
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(_formatError(e)));
    }
  }

  Future<void> _onGetCurrentUser(
      GetCurrentUserEvent event,
      Emitter<AuthState> emit,
      ) async {
    emit(AuthLoading());

    try {
      final user = await _getCurrentUser();
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(_formatError(e)));
    }
  }

  Future<void> _onSignOut(
      SignOutEvent event,
      Emitter<AuthState> emit,
      ) async {
    emit(AuthLoading());

    try {
      await _signOutUseCase();
      emit(AuthUnauthenticated());
    } catch (e) {
      // Even if sign out fails, go to unauthenticated state
      emit(AuthUnauthenticated());
    }
  }

  String _formatError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Domain-specific error messages
    if (errorString.contains('access denied') ||
        errorString.contains('not authorized') ||
        errorString.contains('domain') && errorString.contains('authorized')) {
      return 'Access denied. Your organization domain is not authorized to use this application. Please contact your administrator.';
    }

    // Network-related errors
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout')) {
      return 'Network error. Please check your internet connection and try again.';
    }

    // Authentication-related errors
    if (errorString.contains('cancelled')) {
      return 'Sign in was cancelled.';
    }

    if (errorString.contains('oauth') || errorString.contains('sign-in')) {
      return 'Sign in failed. Please try again.';
    }

    // Profile-related errors
    if (errorString.contains('profile')) {
      return 'Account setup failed. Please try again or contact administrator.';
    }

    // Generic fallback
    return 'An error occurred. Please try again.';
  }
}