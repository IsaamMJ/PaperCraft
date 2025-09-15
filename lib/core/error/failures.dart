import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  List<Object?> get props => [message, code];

  // Factory constructors for common failures
  const factory Failure.server(String message, {String? code}) = ServerFailure;
  const factory Failure.auth(String message, {String? code}) = AuthFailure;
  const factory Failure.network(String message, {String? code}) = NetworkFailure;
  const factory Failure.cache(String message, {String? code}) = CacheFailure;
  const factory Failure.permission(String message, {String? code}) = PermissionFailure;
  const factory Failure.validation(String message, {String? code}) = ValidationFailure;
  const factory Failure.notFound(String message, {String? code}) = NotFoundFailure;
}

class ServerFailure extends Failure {
  const ServerFailure(String message, {String? code}) : super(message, code: code);
}

class CacheFailure extends Failure {
  const CacheFailure(String message, {String? code}) : super(message, code: code);
}

class AuthFailure extends Failure {
  const AuthFailure(String message, {String? code}) : super(message, code: code);
}

class PermissionFailure extends Failure {
  const PermissionFailure(String message, {String? code}) : super(message, code: code);
}

class ValidationFailure extends Failure {
  const ValidationFailure(String message, {String? code}) : super(message, code: code);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(String message, {String? code}) : super(message, code: code);
}

class NetworkFailure extends Failure {
  const NetworkFailure(String message, {String? code}) : super(message, code: code);
}