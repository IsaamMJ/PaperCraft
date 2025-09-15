import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object> get props => [];
}

class AuthInitialize extends AuthEvent {
  const AuthInitialize();
}

class AuthSignInGoogle extends AuthEvent {
  const AuthSignInGoogle();
}

class AuthSignOut extends AuthEvent {
  const AuthSignOut();
}

class AuthCheckStatus extends AuthEvent {
  const AuthCheckStatus();
}