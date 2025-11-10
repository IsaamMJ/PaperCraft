import '../../../../core/domain/errors/failures.dart';

/// User-friendly error message mapping
class ErrorHandler {
  /// Convert failure to user-friendly message
  static String getErrorMessage(dynamic error) {
    if (error is Failure) {
      return _mapFailureToMessage(error);
    } else if (error is String) {
      return error;
    } else if (error is Exception) {
      return _mapExceptionToMessage(error);
    }
    return 'An unexpected error occurred. Please try again.';
  }

  /// Map Failure types to messages
  static String _mapFailureToMessage(Failure failure) {
    if (failure is ValidationFailure) {
      return 'Validation error: ${failure.message}';
    }
    return failure.message;
  }

  /// Map Exception types to messages
  static String _mapExceptionToMessage(Exception exception) {
    final errorString = exception.toString();

    if (errorString.contains('SocketException')) {
      return 'Network connection failed. Please check your internet.';
    } else if (errorString.contains('TimeoutException')) {
      return 'Request timed out. Please try again.';
    } else if (errorString.contains('FormatException')) {
      return 'Invalid data format received from server.';
    }

    return 'An unexpected error occurred: $errorString';
  }

  /// Check if error is recoverable
  static bool isRecoverable(dynamic error) {
    if (error is Failure) {
      // Most failures are recoverable except those that indicate auth issues
      // For now, treat all failures as recoverable
      return true;
    }
    return true;
  }

  /// Categorize error severity
  static ErrorSeverity getSeverity(dynamic error) {
    if (error is Failure) {
      if (error is ValidationFailure) {
        return ErrorSeverity.warning;
      }
      // Default to error severity for other failure types
      return ErrorSeverity.error;
    }
    return ErrorSeverity.error;
  }
}

/// Error severity levels
enum ErrorSeverity {
  info,
  warning,
  error,
  critical,
}

/// Error action suggestions
class ErrorAction {
  final String label;
  final Future<void> Function() action;

  ErrorAction({required this.label, required this.action});
}

/// Suggestion provider based on error type
class ErrorSuggestions {
  /// Get suggestions for an error
  static List<ErrorAction> getSuggestions(dynamic error) {
    if (error is Failure) {
      if (error is ValidationFailure) {
        return [
          ErrorAction(
            label: 'Review Details',
            action: () async {},
          ),
        ];
      }
      // Default suggestions for other failure types
      return [
        ErrorAction(
          label: 'Retry',
          action: () async => Future.delayed(const Duration(seconds: 1)),
        ),
      ];
    }
    return [
      ErrorAction(
        label: 'Dismiss',
        action: () async {},
      ),
    ];
  }
}

/// Enhanced SnackBar message builder
class ErrorSnackBar {
  /// Build snackbar content with error details
  static String buildMessage(dynamic error) {
    final message = ErrorHandler.getErrorMessage(error);
    return message;
  }

  /// Get snackbar duration based on severity
  static Duration getDuration(dynamic error) {
    final severity = ErrorHandler.getSeverity(error);
    switch (severity) {
      case ErrorSeverity.info:
        return const Duration(seconds: 2);
      case ErrorSeverity.warning:
        return const Duration(seconds: 4);
      case ErrorSeverity.error:
        return const Duration(seconds: 5);
      case ErrorSeverity.critical:
        return const Duration(seconds: 6);
    }
  }

  /// Get snackbar background color based on severity
  static int getBackgroundColor(dynamic error) {
    final severity = ErrorHandler.getSeverity(error);
    switch (severity) {
      case ErrorSeverity.info:
        return 0xFF2196F3; // Blue
      case ErrorSeverity.warning:
        return 0xFFFFA726; // Orange
      case ErrorSeverity.error:
        return 0xFFF44336; // Red
      case ErrorSeverity.critical:
        return 0xFFC62828; // Dark Red
    }
  }
}

/// Validation error formatter
class ValidationErrorFormatter {
  /// Format list of validation errors for display
  static String formatErrors(List<String> errors) {
    if (errors.isEmpty) return '';
    if (errors.length == 1) return errors.first;

    return errors.asMap().entries.map((entry) {
      return '${entry.key + 1}. ${entry.value}';
    }).join('\n');
  }

  /// Group errors by category
  static Map<String, List<String>> groupErrors(List<String> errors) {
    final groups = <String, List<String>>{};

    for (final error in errors) {
      if (error.contains('time') || error.contains('Time')) {
        groups.putIfAbsent('Time Issues', () => []).add(error);
      } else if (error.contains('duplicate') || error.contains('Duplicate')) {
        groups.putIfAbsent('Duplicate Entries', () => []).add(error);
      } else if (error.contains('conflict') || error.contains('Conflict')) {
        groups.putIfAbsent('Conflicts', () => []).add(error);
      } else if (error.contains('date') || error.contains('Date')) {
        groups.putIfAbsent('Date Issues', () => []).add(error);
      } else if (error.contains('empty') || error.contains('required')) {
        groups.putIfAbsent('Missing Information', () => []).add(error);
      } else {
        groups.putIfAbsent('Other', () => []).add(error);
      }
    }

    return groups;
  }
}
