// core/infrastructure/logging/app_logger.dart
import '../../domain/interfaces/i_logger.dart';
import '../di/injection_container.dart';

/// Static wrapper for the logger to provide convenient access throughout the app
class AppLogger {
  AppLogger._();

  static ILogger get _logger => sl<ILogger>();

  static void debug(String message, {
    LogCategory category = LogCategory.system,
    Map<String, dynamic>? context,
  }) {
    _logger.debug(message, category: category, context: context);
  }

  static void info(String message, {
    LogCategory category = LogCategory.system,
    Map<String, dynamic>? context,
  }) {
    _logger.info(message, category: category, context: context);
  }

  static void warning(String message, {
    LogCategory category = LogCategory.system,
    Map<String, dynamic>? context,
  }) {
    _logger.warning(message, category: category, context: context);
  }

  static void error(String message, {
    LogCategory category = LogCategory.system,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    _logger.error(message, category: category, error: error, stackTrace: stackTrace, context: context);
  }

  static void critical(String message, {
    LogCategory category = LogCategory.system,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    _logger.critical(message, category: category, error: error, stackTrace: stackTrace, context: context);
  }

  // Specialized methods
  static void authEvent(String event, String userId, {Map<String, dynamic>? context}) {
    _logger.authEvent(event, userId, context: context);
  }

  static void authError(String message, Object? error, {Map<String, dynamic>? context}) {
    _logger.authError(message, error, context: context);
  }

  static void blocEvent(String blocName, String event, {Map<String, dynamic>? context}) {
    _logger.blocEvent(blocName, event, context: context);
  }

  static void blocError(String blocName, String message, Object? error, {Map<String, dynamic>? context}) {
    _logger.blocError(blocName, message, error, context: context);
  }

  static void paperAction(String action, String paperId, {Map<String, dynamic>? context}) {
    _logger.paperAction(action, paperId, context: context);
  }

  static void paperError(String action, String paperId, Object? error, {Map<String, dynamic>? context}) {
    _logger.paperError(action, paperId, error, context: context);
  }

  static void networkRequest(String method, String endpoint, {
    int? statusCode,
    Map<String, dynamic>? context,
  }) {
    _logger.networkRequest(method, endpoint, statusCode: statusCode, context: context);
  }

  static void networkError(String method, String endpoint, Object? error, {Map<String, dynamic>? context}) {
    _logger.networkError(method, endpoint, error, context: context);
  }

  // Utility methods
  static void recordNonFatalError(Object error, StackTrace? stackTrace, {
    String? reason,
    LogCategory category = LogCategory.system,
    Map<String, dynamic>? context,
  }) {
    _logger.recordNonFatalError(error, stackTrace, reason: reason, category: category, context: context);
  }

  static void setUserId(String userId) {
    _logger.setUserId(userId);
  }

  static void addBreadcrumb(String message, {LogCategory category = LogCategory.system}) {
    _logger.addBreadcrumb(message, category: category);
  }

  // Status getters
  static bool get isInitialized => _logger.isInitialized;
  static bool get isCrashlyticsAvailable => _logger.isCrashlyticsAvailable;
  static Map<String, dynamic> get status => _logger.status;
}