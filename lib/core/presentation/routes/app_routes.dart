/// All application route paths
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String authCallback = '/auth/callback';

  // Main routes
  static const String home = '/';
  static const String settings = '/settings'; // ADD THIS
  static const String notifications = '/notifications';

  // Onboarding routes
  static const String onboarding = '/onboarding';
  static const String teacherOnboarding = '/onboarding/teacher';
  static const String teacherProfileSetup = '/onboarding/teacher/profile-setup';

  // Question paper routes
  static const String questionPaperCreate = '/papers/create';
  static const String questionPaperView = '/papers/view';
  static const String questionPaperEdit = '/papers/edit';
  static const String questionBank = '/papers/bank';

  // Settings sub-routes
  static const String settingsSubjects = '/settings/subjects';
  static const String settingsGrades = '/settings/grades';
  static const String settingsExamTypes = '/settings/exam-types';
  static const String settingsUsers = '/settings/users';

  // Admin routes
  static const String adminHome = '/admin/home';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminReview = '/admin/review';

  // Office staff routes
  static const String officeStaffDashboard = '/office/dashboard';

  // Teacher Assignment routes
  static const String teacherAssignments = '/settings/teacher-assignments';
  static const String assignmentMatrix = '/admin/assignment-matrix';

  // Helper methods for parameterized routes
  static String questionPaperViewWithId(String id) => '$questionPaperView/$id';
  static String questionPaperEditWithId(String id) => '$questionPaperEdit/$id';
  static String adminReviewWithId(String id) => '$adminReview/$id';
}

/// Route parameters used in dynamic routes
class RouteParams {
  RouteParams._();
  static const String id = 'id';
}

/// Simplified route guard utilities
class RouteGuard {
  RouteGuard._();

  static bool needsAuth(String route) {
    return ![AppRoutes.login, AppRoutes.authCallback].contains(route);
  }

  static bool isAdmin(String route) {
    return route.startsWith('/admin');
  }

  static bool isOfficeStaff(String route) {
    return route.startsWith('/office');
  }
}