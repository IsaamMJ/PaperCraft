import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final UserEntity user;
  final bool isFirstLogin;
  final bool tenantInitialized; // Tenant has completed admin setup
  final bool userOnboarded; // User has completed their personal onboarding

  const AuthAuthenticated(
    this.user, {
    this.isFirstLogin = false,
    this.tenantInitialized = false,
    this.userOnboarded = false,
  });

  @override
  List<Object> get props => [user, isFirstLogin, tenantInitialized, userOnboarded];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object> get props => [message];
}