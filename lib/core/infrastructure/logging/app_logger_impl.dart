import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../../domain/interfaces/i_logger.dart';
import '../../domain/interfaces/i_feature_flags.dart';
import '../config/logging_config.dart';
import '../utils/platform_utils.dart';

class AppLoggerImpl implements ILogger {
  static bool _initialized = false;
  static bool _crashlyticsAvailable = false;
  final IFeatureFlags _featureFlags;

  AppLoggerImpl(this._featureFlags);

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    if (_featureFlags.enableCrashlytics) {
      await _initializeCrashlytics();
    }

    _initialized = true;

    if (_featureFlags.enableDebugLogging) {
      info('Logger initialized successfully', context: {
        'crashlyticsAvailable': _crashlyticsAvailable,
        'debugLogging': _featureFlags.enableDebugLogging,
        'platform': PlatformUtils.platformName,
      });
    }
  }

  Future<void> _initializeCrashlytics() async {
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      FirebaseCrashlytics.instance.setCustomKey('app_version', LoggingConfig.appVersion);
      FirebaseCrashlytics.instance.setCustomKey('platform', PlatformUtils.platformName);
      _crashlyticsAvailable = true;
      if (kDebugMode) print('✅ Crashlytics initialized successfully');
    } catch (e) {
      _crashlyticsAvailable = false;
      if (kDebugMode) print('⚠️ Crashlytics not available: $e');
    }
  }

  @override
  void debug(String message, {LogCategory category = LogCategory.system, Map<String, dynamic>? context}) {
    if (_featureFlags.enableDebugLogging) {
      _log(LogLevel.debug, category, message, context: context);
    }
  }

  @override
  void info(String message, {LogCategory category = LogCategory.system, Map<String, dynamic>? context}) {
    _log(LogLevel.info, category, message, context: context);
  }

  @override
  void warning(String message, {LogCategory category = LogCategory.system, Map<String, dynamic>? context}) {
    _log(LogLevel.warning, category, message, context: context);
  }

  @override
  void error(String message, {LogCategory category = LogCategory.system, Object? error, StackTrace? stackTrace, Map<String, dynamic>? context}) {
    _log(LogLevel.error, category, message, error: error, stackTrace: stackTrace, context: context);
  }

  @override
  void critical(String message, {LogCategory category = LogCategory.system, Object? error, StackTrace? stackTrace, Map<String, dynamic>? context}) {
    _log(LogLevel.critical, category, message, error: error, stackTrace: stackTrace, context: context);
  }

  @override
  void authEvent(String event, String userId, {Map<String, dynamic>? context}) {
    info('Auth: $event', category: LogCategory.auth, context: {'userId': userId, 'event': event, ...?context});
    addBreadcrumb('Auth: $event', category: LogCategory.auth);
  }

  @override
  void authError(String message, Object? error, {Map<String, dynamic>? context}) {
    if (error != null) {
      recordNonFatalError(error, StackTrace.current, reason: 'Auth Error: $message', category: LogCategory.auth, context: context);
    } else {
      this.error('Auth Error: $message', category: LogCategory.auth, context: context);
    }
  }

  @override
  void blocEvent(String blocName, String event, {Map<String, dynamic>? context}) {
    debug('$blocName: $event', category: LogCategory.bloc, context: {'bloc': blocName, 'event': event, ...?context});

    if (event.contains('Error') || event.contains('Failed')) {
      addBreadcrumb('$blocName: $event', category: LogCategory.bloc);
    }
  }

  @override
  void blocError(String blocName, String message, Object? error, {Map<String, dynamic>? context}) {
    if (error != null) {
      recordNonFatalError(error, StackTrace.current, reason: '$blocName Error: $message', category: LogCategory.bloc, context: {'bloc': blocName, ...?context});
    } else {
      this.error('$blocName Error: $message', category: LogCategory.bloc, context: {'bloc': blocName, ...?context});
    }
  }

  @override
  void paperAction(String action, String paperId, {Map<String, dynamic>? context}) {
    info('Paper $action', category: LogCategory.paper, context: {'action': action, 'paperId': paperId, ...?context});
    addBreadcrumb('Paper $action: $paperId', category: LogCategory.paper);
  }

  @override
  void paperError(String action, String paperId, Object? error, {Map<String, dynamic>? context}) {
    if (error != null) {
      recordNonFatalError(error, StackTrace.current, reason: 'Paper $action failed', category: LogCategory.paper, context: {'action': action, 'paperId': paperId, ...?context});
    } else {
      this.error('Paper $action failed', category: LogCategory.paper, context: {'action': action, 'paperId': paperId, ...?context});
    }
  }

  @override
  void networkRequest(String method, String endpoint, {int? statusCode, Map<String, dynamic>? context}) {
    if (_featureFlags.enableNetworkLogging) {
      info('Network: $method $endpoint', category: LogCategory.network, context: {'method': method, 'endpoint': endpoint, if (statusCode != null) 'statusCode': statusCode, ...?context});
    }

    if (statusCode != null && statusCode >= 400) {
      addBreadcrumb('Network Error: $method $endpoint ($statusCode)', category: LogCategory.network);
    }
  }

  @override
  void networkError(String method, String endpoint, Object? error, {Map<String, dynamic>? context}) {
    if (error != null) {
      recordNonFatalError(error, StackTrace.current, reason: 'Network Error: $method $endpoint', category: LogCategory.network, context: {'method': method, 'endpoint': endpoint, ...?context});
    } else {
      this.error('Network Error: $method $endpoint', category: LogCategory.network, context: {'method': method, 'endpoint': endpoint, ...?context});
    }
  }

  @override
  void recordNonFatalError(Object error, StackTrace? stackTrace, {String? reason, LogCategory category = LogCategory.system, Map<String, dynamic>? context}) {
    this.error(reason ?? error.toString(), category: category, error: error, stackTrace: stackTrace, context: context);

    if (_crashlyticsAvailable && _featureFlags.enableCrashlytics) {
      _sendToCrashlytics(error, stackTrace, reason: reason, category: category, context: context);
    }
  }

  @override
  void setUserId(String userId) {
    if (_crashlyticsAvailable && _featureFlags.enableCrashlytics) {
      try {
        FirebaseCrashlytics.instance.setUserIdentifier(userId);
        info('User ID set for crash reporting', category: LogCategory.auth, context: {'userId': userId});
      } catch (e) {
        if (_featureFlags.enableDebugLogging) print('Failed to set user ID: $e');
      }
    }
  }

  @override
  void addBreadcrumb(String message, {LogCategory category = LogCategory.system}) {
    if (_crashlyticsAvailable && _featureFlags.enableCrashlytics) {
      try {
        FirebaseCrashlytics.instance.log('${category.prefix}: $message');
      } catch (e) {
        if (_featureFlags.enableDebugLogging) print('Failed to add breadcrumb: $e');
      }
    }
    debug('Breadcrumb: $message', category: category);
  }

  @override
  void testCrashlytics() {
    if (!_featureFlags.enableDebugLogging) return;

    try {
      throw Exception('Test error for Firebase Crashlytics - this is intentional!');
    } catch (e, stackTrace) {
      recordNonFatalError(e, stackTrace, reason: 'Testing Crashlytics integration', category: LogCategory.system, context: {'test': true, 'timestamp': DateTime.now().toIso8601String()});
    }
  }

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isCrashlyticsAvailable => _crashlyticsAvailable;

  @override
  Map<String, dynamic> get status => {
    'initialized': _initialized,
    'crashlyticsAvailable': _crashlyticsAvailable,
    'debugLogging': _featureFlags.enableDebugLogging,
    'networkLogging': _featureFlags.enableNetworkLogging,
    'crashlyticsEnabled': _featureFlags.enableCrashlytics,
    'platform': PlatformUtils.platformName,
    'platformContext': PlatformUtils.platformContext,
  };

  void _log(LogLevel level, LogCategory category, String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? context}) {
    if (_featureFlags.enableDebugLogging || level.value >= LogLevel.warning.value) {
      _printToConsole(level, category, message, error, stackTrace, context);
    }

    if (level == LogLevel.critical && _crashlyticsAvailable && _featureFlags.enableCrashlytics) {
      _sendToCrashlytics(error ?? Exception(message), stackTrace ?? StackTrace.current, reason: message, category: category, context: context);
    }
  }

  void _printToConsole(LogLevel level, LogCategory category, String message, Object? error, StackTrace? stackTrace, Map<String, dynamic>? context) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final prefix = '${level.prefix} [$timestamp] [${category.prefix}]';

    developer.log('$prefix $message', name: LoggingConfig.loggerName, level: level.value * LoggingConfig.logLevelMultiplier);

    if (context != null && context.isNotEmpty) {
      developer.log('   Context: $context', name: LoggingConfig.loggerName);
    }
    if (error != null) {
      developer.log('   Error: $error', name: LoggingConfig.loggerName);
    }
    if (stackTrace != null && _featureFlags.enableDebugLogging) {
      developer.log('   StackTrace: $stackTrace', name: LoggingConfig.loggerName);
    }
  }

  void _sendToCrashlytics(Object error, StackTrace? stackTrace, {String? reason, LogCategory? category, Map<String, dynamic>? context}) {
    try {
      if (category != null) {
        FirebaseCrashlytics.instance.setCustomKey('log_category', category.name);
      }
      if (context != null && context.isNotEmpty) {
        context.forEach((key, value) {
          try {
            FirebaseCrashlytics.instance.setCustomKey('context_$key', value.toString());
          } catch (e) {
            // Ignore individual key failures
          }
        });
      }
      FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: reason, printDetails: false);
    } catch (e) {
      if (_featureFlags.enableDebugLogging) print('Failed to send to Crashlytics: $e');
    }
  }
}