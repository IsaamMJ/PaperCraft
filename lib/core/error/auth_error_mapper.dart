class AuthErrorMapper {
  // Error categories
  static const Map<String, String> _organizationErrors = {
    'unauthorized domain': 'Your organization is not authorized to use this application. Please contact your school administrator.',
    'organization is not authorized': 'Your organization is not authorized to use this application. Please contact your school administrator.',
  };

  static const Map<String, String> _accountErrors = {
    'account has been deactivated': 'Your account has been deactivated. Please contact your school administrator.',
    'user is not active': 'Your account has been deactivated. Please contact your school administrator.',
    'profile creation failed': 'Profile creation failed. Please contact your administrator or try again.',
  };

  static const Map<String, String> _authErrors = {
    'failed to start oauth': 'Failed to start sign-in process. Please try again.',
    'oauth sign-in failed': 'Failed to start sign-in process. Please try again.',
    'authentication failed': 'Authentication failed. Please try again.',
    'sign-in failed': 'Authentication failed. Please try again.',
  };

  static const Map<String, String> _networkErrors = {
    'timed out': 'Sign-in timed out. Please check your connection and try again.',
    'timeout': 'Sign-in timed out. Please check your connection and try again.',
    'network': 'Connection failed. Please check your internet connection and try again.',
    'connection': 'Connection failed. Please check your internet connection and try again.',
    'internet': 'Connection failed. Please check your internet connection and try again.',
  };

  static const Map<String, String> _sessionErrors = {
    'session expired': 'Your session has expired. Please sign in again.',
    'invalid session': 'Your session has expired. Please sign in again.',
  };

  static String mapError(Object error) {
    final errorString = error.toString().toLowerCase();

    // Check each error category
    for (final category in [_organizationErrors, _accountErrors, _authErrors, _networkErrors, _sessionErrors]) {
      for (final entry in category.entries) {
        if (errorString.contains(entry.key)) {
          return entry.value;
        }
      }
    }

    return 'Access denied. Please contact support.';
  }
}