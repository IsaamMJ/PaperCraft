/// All application route paths
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String authCallback = '/auth/callback';

  // Main routes
  static const String home = '/';
  static const String settings = '/settings'; // ADD THIS

  // Question paper routes
  static const String questionPaperCreate = '/papers/create';
  static const String questionPaperView = '/papers/view';
  static const String questionPaperEdit = '/papers/edit';
  static const String questionBank = '/papers/bank';

  // Admin routes
  static const String adminDashboard = '/admin/dashboard';
  static const String adminReview = '/admin/review';

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
}