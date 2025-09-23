// core/domain2/interfaces/i_logger.dart
abstract class ILogger {
  /// Initialize the logger system
  Future<void> initialize();

  /// Basic logging methods
  void debug(String message, {
    LogCategory category = LogCategory.system,
    Map<String, dynamic>? context,
  });

  void info(String message, {
    LogCategory category = LogCategory.system,
    Map<String, dynamic>? context,
  });

  void warning(String message, {
    LogCategory category = LogCategory.system,
    Map<String, dynamic>? context,
  });

  void error(String message, {
    LogCategory category = LogCategory.system,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  });

  void critical(String message, {
    LogCategory category = LogCategory.system,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  });

  /// Specialized logging methods for common use cases
  void authEvent(String event, String userId, {Map<String, dynamic>? context});

  void authError(String message, Object? error, {Map<String, dynamic>? context});

  void blocEvent(String blocName, String event, {Map<String, dynamic>? context});

  void blocError(String blocName, String message, Object? error, {Map<String, dynamic>? context});

  void paperAction(String action, String paperId, {Map<String, dynamic>? context});

  void paperError(String action, String paperId, Object? error, {Map<String, dynamic>? context});

  void networkRequest(String method, String endpoint, {
    int? statusCode,
    Map<String, dynamic>? context,
  });

  void networkError(String method, String endpoint, Object? error, {Map<String, dynamic>? context});

  /// Crash reporting methods
  void recordNonFatalError(Object error, StackTrace? stackTrace, {
    String? reason,
    LogCategory category = LogCategory.system,
    Map<String, dynamic>? context,
  });

  void setUserId(String userId);

  void addBreadcrumb(String message, {LogCategory category = LogCategory.system});

  void testCrashlytics();

  /// Status methods
  bool get isInitialized;
  bool get isCrashlyticsAvailable;
  Map<String, dynamic> get status;
}

/// Log categories for organizing and filtering logs
enum LogCategory {
  auth('AUTH'),
  network('NETWORK'),
  bloc('BLOC'),
  ui('UI'),
  navigation('NAVIGATION'),
  paper('PAPER'),
  storage('STORAGE'),
  system('SYSTEM');

  const LogCategory(this.prefix);
  final String prefix;
}

/// Log levels for controlling verbosity
enum LogLevel {
  debug(0, '[DEBUG]'),
  info(1, '[INFO]'),
  warning(2, '[WARNING]'),
  error(3, '[ERROR]'),
  critical(4, '[CRITICAL]');

  const LogLevel(this.value, this.prefix);
  final int value;
  final String prefix;
}