import 'package:flutter/foundation.dart';
import '../../domain/interfaces/i_logger.dart';
import '../di/injection_container.dart';

/// Global error handler for uncaught exceptions
///
/// Catches and logs all unhandled errors in the app:
/// - Flutter framework errors
/// - Async errors
/// - Zone errors
class GlobalErrorHandler {
  static void initialize() {
    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);

      try {
        final logger = sl<ILogger>();
        logger.error(
          'Flutter Error',
          category: LogCategory.system,
          error: details.exception,
          stackTrace: details.stack,
          context: {
            'library': details.library ?? 'unknown',
            'context': details.context?.toString() ?? 'none',
          },
        );
      } catch (e) {
        // If logger fails, at least print to console
        debugPrint('Flutter Error: ${details.exception}');
        debugPrint('Stack trace: ${details.stack}');
      }
    };

    // Catch async errors outside Flutter
    PlatformDispatcher.instance.onError = (error, stack) {
      try {
        final logger = sl<ILogger>();
        logger.error(
          'Async Error',
          category: LogCategory.system,
          error: error,
          stackTrace: stack,
        );
      } catch (e) {
        debugPrint('Async Error: $error');
        debugPrint('Stack trace: $stack');
      }

      return true; // Handled
    };
  }
}
