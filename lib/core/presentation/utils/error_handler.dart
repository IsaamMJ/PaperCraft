import 'package:flutter/material.dart';
import '../../domain/errors/failures.dart';
import '../constants/app_colors.dart';

/// Converts technical Failure objects into user-friendly messages
/// and provides utilities to display them properly
class ErrorHandler {
  /// Get a user-friendly error message from a Failure
  static String getMessage(Failure failure) {
    if (failure is NetworkFailure) {
      return 'No internet connection. Please check your network and try again.';
    } else if (failure is ValidationFailure) {
      // Validation failures already have user-friendly messages
      return failure.message;
    } else if (failure is ServerFailure) {
      return 'Server error. Please try again in a moment.';
    } else if (failure is AuthFailure) {
      return 'Authentication failed. Please sign in again.';
    } else if (failure is PermissionFailure) {
      return 'You don\'t have permission to perform this action.';
    } else if (failure is NotFoundFailure) {
      return 'The requested item could not be found.';
    } else if (failure is CacheFailure) {
      return 'Local storage error. Please try again.';
    } else {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Get an appropriate icon for the failure type
  static IconData getIcon(Failure failure) {
    if (failure is NetworkFailure) {
      return Icons.wifi_off;
    } else if (failure is ValidationFailure) {
      return Icons.error_outline;
    } else if (failure is ServerFailure) {
      return Icons.cloud_off;
    } else if (failure is AuthFailure) {
      return Icons.lock_outline;
    } else if (failure is PermissionFailure) {
      return Icons.block;
    } else if (failure is NotFoundFailure) {
      return Icons.search_off;
    } else {
      return Icons.error;
    }
  }

  /// Get an appropriate color for the failure type
  static Color getColor(Failure failure) {
    if (failure is NetworkFailure) {
      return AppColors.warning;
    } else if (failure is ValidationFailure) {
      return AppColors.error;
    } else {
      return AppColors.error;
    }
  }

  /// Get a short title for the failure type
  static String getTitle(Failure failure) {
    if (failure is NetworkFailure) {
      return 'Connection Issue';
    } else if (failure is ValidationFailure) {
      return 'Invalid Input';
    } else if (failure is ServerFailure) {
      return 'Server Error';
    } else if (failure is AuthFailure) {
      return 'Authentication Required';
    } else if (failure is PermissionFailure) {
      return 'Access Denied';
    } else if (failure is NotFoundFailure) {
      return 'Not Found';
    } else if (failure is CacheFailure) {
      return 'Storage Error';
    } else {
      return 'Error';
    }
  }

  /// Check if failure is retryable
  static bool isRetryable(Failure failure) {
    return failure is NetworkFailure || failure is ServerFailure;
  }

  /// Show error as SnackBar
  static void showSnackBar(
    BuildContext context,
    Failure failure, {
    VoidCallback? onRetry,
  }) {
    final message = getMessage(failure);
    final color = getColor(failure);
    final isRetry = isRetryable(failure);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(getIcon(failure), color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 5),
        action: (isRetry && onRetry != null)
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Show error as Dialog
  static void showDialog(
    BuildContext context,
    Failure failure, {
    VoidCallback? onRetry,
  }) {
    final title = getTitle(failure);
    final message = getMessage(failure);
    final icon = getIcon(failure);
    final color = getColor(failure);
    final isRetry = isRetryable(failure);

    showAdaptiveDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(icon, color: color, size: 48),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          if (isRetry && onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onRetry();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  /// Show error as inline widget (for forms)
  static Widget buildErrorWidget(
    Failure failure, {
    VoidCallback? onRetry,
  }) {
    final message = getMessage(failure);
    final icon = getIcon(failure);
    final color = getColor(failure);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontSize: 14),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
