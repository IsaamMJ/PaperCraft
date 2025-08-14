import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AppStartedEvent extends AuthEvent {}

class SignInWithGoogleEvent extends AuthEvent {}

class GetCurrentUserEvent extends AuthEvent {}

class SignOutEvent extends AuthEvent {}