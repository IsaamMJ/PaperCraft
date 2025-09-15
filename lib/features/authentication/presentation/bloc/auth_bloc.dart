import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../domain/usecases/auth_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthUseCase _authUseCase;
  late StreamSubscription _authSubscription;

  AuthBloc(this._authUseCase) : super(const AuthInitial()) {
    on<AuthInitialize>(_onInitialize);
    on<AuthSignInGoogle>(_onSignInGoogle);
    on<AuthSignOut>(_onSignOut);
    on<AuthCheckStatus>(_onCheckStatus);

    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      // Handle session expiry - silent redirect to login
      if (data.event == AuthChangeEvent.signedOut && state is AuthAuthenticated) {
        _handleSessionExpiry();
      }
    });
  }

  void _handleSessionExpiry() {
    // Silent redirect - preserves draft papers
    add(const AuthSignOut());
  }

  @override
  Future<void> close() {
    _authSubscription.cancel();
    return super.close();
  }

  Future<void> _onInitialize(AuthInitialize event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final user = await _authUseCase.initialize();
      emit(user != null
          ? AuthAuthenticated(user)
          : const AuthUnauthenticated());
    } catch (e) {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onSignInGoogle(AuthSignInGoogle event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final result = await _authUseCase.signInWithGoogle();
      emit(AuthAuthenticated(result.user, isFirstLogin: result.isFirstLogin));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignOut(AuthSignOut event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      await _authUseCase.signOut();
      emit(const AuthUnauthenticated());
    } catch (e) {
      // Even if logout fails, we should clear the local state
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onCheckStatus(AuthCheckStatus event, Emitter<AuthState> emit) async {
    try {
      final user = await _authUseCase.getCurrentUser();
      emit(user != null
          ? AuthAuthenticated(user)
          : const AuthUnauthenticated());
    } catch (e) {
      emit(const AuthUnauthenticated());
    }
  }
}