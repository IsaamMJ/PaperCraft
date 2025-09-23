class AppMessages {
  AppMessages._();

  // General UI Messages
  static const String loading = 'Loading...';
  static const String pleaseLogin = 'Please log in to continue';
  static const String processingAuth = 'Processing authentication...';
  static const String checkAuthStatus = 'Check Auth Status';
  static const String pageNotFound = 'Page Not Found';
  static const String pageNotFoundDescription = 'The requested page could not be found.';
  static const String goHome = 'Go Home';
  static const String goBack = 'Go Back';
  static const String errorPrefix = 'Error: ';

  // Auth error messages
  static const String authFailedGeneric = 'Authentication failed. Please try again.';
  static const String networkError = 'Connection failed. Please check your internet connection and try again.';
  static const String sessionExpired = 'Your session has expired. Please sign in again.';
  static const String organizationNotAuthorized = 'Your organization is not authorized to use this application. Please contact your school administrator.';
  static const String accountDeactivated = 'Your account has been deactivated. Please contact your school administrator.';
  static const String profileCreationFailed = 'Profile creation failed. Please contact your administrator or try again.';
  static const String authTimeout = 'Sign-in timed out. Please check your connection and try again.';
  static const String accessDenied = 'Access denied. Please contact support.';

  // Route error messages
  static const String routeError = 'Failed to build the requested page. Please try again.';
  static const String parameterMissing = 'Required route parameter is missing.';
}