class AuthException implements Exception {
  final String message;
  final String? code;
  final Object? originalError;

  const AuthException(this.message, {this.code, this.originalError});

  @override
  String toString() => message;

  // Helper methods for specific error types
  bool get isUnauthorizedDomain => message.contains('organization is not authorized');
  bool get isDeactivatedAccount => message.contains('account has been deactivated');
  bool get isNetworkError => message.contains('connection') || message.contains('network');
  bool get isSessionError => message.contains('session');
}