// Corrected main.dart with critical fixes applied
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'core/domain/interfaces/i_logger.dart';
import 'core/infrastructure/config/environment_config.dart';
import 'core/infrastructure/di/injection_container.dart';
import 'core/infrastructure/feature_flags/feature_flags.dart';
import 'core/infrastructure/logging/app_logger.dart';
import 'core/presentation/constants/ui_constants.dart';
import 'core/presentation/routes/app_router.dart';
import 'firebase_options.dart';

import 'features/authentication/domain/services/user_state_service.dart';
import 'features/authentication/presentation/bloc/auth_bloc.dart';

/// Entry point of the PaperCraft application
Future<void> main() async {
  runZonedGuarded(
        () async => await _initializeAndRunApp(),
    _handleZoneError,
  );
}

/// Initialize the app with proper error handling
Future<void> _initializeAndRunApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await EnvironmentConfig.load();
    await _initializeServices();
    _setupErrorHandlers();
    await _runApp();
  } catch (e, stackTrace) {
    await _handleCriticalError(e, stackTrace);
  }
}

/// Initialize core services in order
Future<void> _initializeServices() async {
  final services = [
    _InitStep('Firebase', _initializeFirebase),
    _InitStep('Dependencies', setupDependencies),
  ];

  for (final service in services) {
    try {
      if (kDebugMode) debugPrint('Initializing ${service.name}...');
      await service.initialize();
      if (kDebugMode) debugPrint('${service.name} initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('Failed to initialize ${service.name}: $e');
      rethrow;
    }
  }
}

/// Initialize Firebase with platform-specific options
/// FIXED: Added error handling for Firebase initialization
Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) debugPrint('Firebase initialized successfully');
  } catch (e, stackTrace) {
    debugPrint('Firebase initialization failed: $e');
    // Continue without Firebase - app can still work without Crashlytics
    if (kDebugMode) debugPrint('Continuing without Firebase services');
  }
}

/// Configure global error handlers for Flutter and Crashlytics
void _setupErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    _logFlutterError(details);

    // FIXED: Only try Crashlytics if Firebase is available
    if (FeatureFlags.enableCrashlytics) {
      _sendToCrashlytics(
            () => FirebaseCrashlytics.instance.recordFlutterError(details),
      );
    }
  };
}

/// Run the main application
Future<void> _runApp() async {
  try {
    _logAppStart();
    AppLogger.info('Dependencies initialized', category: LogCategory.system);

    if (FeatureFlags.enableDebugLogging) {
      await _performDebugTasks();
      FeatureFlags.logFlags();
    }

    runApp(const PaperCraftApp());
    AppLogger.info('App launched successfully', category: LogCategory.system);
  } catch (e, stackTrace) {
    AppLogger.recordNonFatalError(
      e,
      stackTrace,
      reason: 'Failed to initialize app',
      category: LogCategory.system,
      context: _getAppContext(),
    );
    runApp(const _ErrorApp());
  }
}

/// Perform debug-specific tasks
Future<void> _performDebugTasks() async {
  await _cleanupOldDraftData();

  // FIXED: Safe access to UserStateService
  try {
    sl<UserStateService>().debugUserInfo();
  } catch (e) {
    debugPrint('Failed to debug user info: $e');
  }
}

/// Clean up old draft data from SharedPreferences
Future<void> _cleanupOldDraftData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final draftKeys = prefs
        .getKeys()
        .where((k) => k.startsWith('draft_paper_') || k == 'draft_papers_index')
        .toList();

    for (final key in draftKeys) {
      await prefs.remove(key);
    }

    if (draftKeys.isNotEmpty) {
      AppLogger.info(
        'Cleaned up ${draftKeys.length} old draft keys',
        category: LogCategory.storage,
      );
    }
  } catch (e, stackTrace) {
    AppLogger.recordNonFatalError(
      e,
      stackTrace,
      reason: 'Failed to cleanup old draft data',
      category: LogCategory.storage,
    );
  }
}

/// Handle critical errors that prevent app initialization
Future<void> _handleCriticalError(Object error, StackTrace stackTrace) async {
  _logCriticalError(error, stackTrace);

  try {
    await sl<ILogger>().initialize();
    AppLogger.critical(
      'Failed to start app',
      error: error,
      stackTrace: stackTrace,
      category: LogCategory.system,
      context: {'step': 'main_initialization'},
    );
  } catch (_) {
    // Logger initialization failed, continue with minimal error app
  }

  runApp(const _CriticalErrorApp());
}

/// Handle zone errors (uncaught async errors)
void _handleZoneError(Object error, StackTrace stackTrace) {
  // FIXED: Only try Crashlytics if it's available
  if (FeatureFlags.enableCrashlytics) {
    _sendToCrashlytics(
          () => FirebaseCrashlytics.instance.recordError(error, stackTrace),
    );
  }
  try {
    AppLogger.critical(
      'Zone Error: $error',
      error: error,
      stackTrace: stackTrace,
      category: LogCategory.system,
    );
  } catch (e) {
    debugPrint('Failed to log zone error: $e');
  }
}

/// Log Flutter framework errors
void _logFlutterError(FlutterErrorDetails details) {
  try {
    AppLogger.error(
      'Flutter Error: ${details.exception}',
      error: details.exception,
      stackTrace: details.stack,
      category: LogCategory.system,
      context: {
        'library': details.library,
        'context': details.context?.toString(),
        'informationCollector': details.informationCollector?.toString(),
      },
    );
  } catch (e) {
    debugPrint('Failed to log Flutter error: $e');
  }
}

/// Send error to Crashlytics with error handling
/// FIXED: Better error handling for Crashlytics calls
void _sendToCrashlytics(VoidCallback crashlyticsAction) {
  try {
    crashlyticsAction();
  } catch (e) {
    debugPrint('Failed to send to Crashlytics: $e');
    // Don't rethrow - continue normal operation
  }
}

/// Log app startup information
void _logAppStart() {
  AppLogger.info(
    'App starting',
    category: LogCategory.system,
    context: _getAppContext(),
  );
}

/// Log critical error with console output
void _logCriticalError(Object error, StackTrace stackTrace) {
  debugPrint('💥 CRITICAL ERROR in main(): $error');
  debugPrint('Stack trace: $stackTrace');
}

/// Get common app context for logging
Map<String, dynamic> _getAppContext() {
  return {
    'appName': 'PaperCraft',
    'version': '1.0.0',
    'environment': EnvironmentConfig.current.name,
    'platform': defaultTargetPlatform.name,
    'featureFlags': FeatureFlags.allFlags,
  };
}

/// Main application widgets
/// FIXED: Safe service locator access and removed double initialization
class PaperCraftApp extends StatelessWidget {
  const PaperCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    // FIXED: Safe service locator access
    try {
      final authBloc = sl<AuthBloc>();

      print('🔥 DEBUG: AuthBloc state is ${authBloc.state}');

      // FIXED: Don't double-initialize - AuthBloc constructor already handles this
      // Remove the manual AuthInitialize event - let the router handle auth initialization

      return BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: Builder(
          builder: (context) => _buildMaterialApp(context, authBloc),
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.recordNonFatalError(
        e,
        stackTrace,
        reason: 'Failed to get AuthBloc from service locator',
        category: LogCategory.system,
      );
      return _buildErrorApp(e);
    }
  }

  /// Build the main MaterialApp with routing and theming
  Widget _buildMaterialApp(BuildContext context, AuthBloc authBloc) {
    try {
      return MaterialApp.router(
        title: 'PaperCraft',
        theme: _buildAppTheme(),
        debugShowCheckedModeBanner: false,
        routerConfig: AppRouter.createRouter(authBloc),
        builder: (context, child) {
          _setupErrorWidgetBuilder();
          return child ?? const SizedBox.shrink();
        },
      );
    } catch (e, stackTrace) {
      AppLogger.recordNonFatalError(
        e,
        stackTrace,
        reason: 'Failed to build PaperCraftApp',
        category: LogCategory.ui,
      );
      return _buildErrorApp(e);
    }
  }

  /// Build the application theme
  ThemeData _buildAppTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
    );
  }

  /// Setup custom error widgets builder
  void _setupErrorWidgetBuilder() {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      AppLogger.addBreadcrumb(
        'Widget error in ${details.library}',
        category: LogCategory.ui,
      );

      return kDebugMode
          ? ErrorWidget(details.exception)
          : const _UserFriendlyErrorWidget();
    };
  }

  /// FIXED: Better error app with more helpful information
  Widget _buildErrorApp(Object error) {
    return MaterialApp(
      home: Scaffold(
        body: _ErrorDisplay(
          icon: Icons.error,
          title: 'App initialization failed',
          message: 'Please restart the app. If the problem persists, check your internet connection.',
          subtitle: 'Error: ${error.toString()}',
        ),
      ),
    );
  }
}

// REMOVED: _AuthBlocInitializer class - not needed anymore

/// Error app shown when initialization fails
class _ErrorApp extends StatelessWidget {
  const _ErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PaperCraft - Error',
      home: Scaffold(
        appBar: AppBar(title: const Text('PaperCraft')),
        body: const _ErrorDisplay(
          icon: Icons.error_outline,
          title: 'Failed to start the app',
          message: 'Please restart the app or contact support.',
          subtitle: 'Error details have been logged for investigation.',
        ),
      ),
    );
  }
}

/// Critical error app shown when core initialization fails
class _CriticalErrorApp extends StatelessWidget {
  const _CriticalErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PaperCraft - Critical Error',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Critical Error'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: const _ErrorDisplay(
          icon: Icons.dangerous,
          title: 'Critical Error',
          message: 'The app failed to initialize properly.',
          subtitle: 'Try restarting the app or contact support if the problem persists.',
          iconColor: Colors.red,
        ),
      ),
    );
  }
}

/// User-friendly error widgets for widgets build failures
class _UserFriendlyErrorWidget extends StatelessWidget {
  const _UserFriendlyErrorWidget();

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        color: Colors.red.shade50,
        child: const _ErrorDisplay(
          icon: Icons.warning_amber_outlined,
          title: 'Something went wrong',
          message: 'Please try again or restart the app.',
          subtitle: 'The error has been reported automatically.',
          iconColor: Colors.orange,
        ),
      ),
    );
  }
}

/// Reusable error display widgets
class _ErrorDisplay extends StatelessWidget {
  const _ErrorDisplay({
    required this.icon,
    required this.title,
    required this.message,
    this.subtitle,
    this.iconColor = Colors.red,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? subtitle;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: iconColor),
            SizedBox(height: UIConstants.spacing16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: UIConstants.spacing8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              SizedBox(height: UIConstants.spacing16),
              Text(
                subtitle!,
                style: const TextStyle(fontSize: UIConstants.fontSizeSmall, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Helper class for initialization steps
class _InitStep {
  const _InitStep(this.name, this.initialize);

  final String name;
  final Future<void> Function() initialize;
}