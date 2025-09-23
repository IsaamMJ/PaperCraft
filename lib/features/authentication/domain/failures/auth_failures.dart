import '../../../../core/domain/errors/failures.dart';

class AuthFailure extends Failure {
  const AuthFailure(String message, {String? code}) : super(message, code: code);
}

class UnauthorizedDomainFailure extends AuthFailure {
  const UnauthorizedDomainFailure(String domain)
      : super('Your organization ($domain) is not authorized to use this application');
}

class DeactivatedAccountFailure extends AuthFailure {
  const DeactivatedAccountFailure()
      : super('Your account has been deactivated');
}

class SessionExpiredFailure extends AuthFailure {
  const SessionExpiredFailure()
      : super('Your session has expired. Please sign in again');
}