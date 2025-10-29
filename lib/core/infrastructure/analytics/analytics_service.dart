import 'package:flutter/foundation.dart';

/// Analytics service interface for tracking user events and errors
abstract class IAnalyticsService {
  /// Log a user event (e.g., "paper_submitted", "pdf_generated")
  void logEvent(String name, {Map<String, dynamic>? parameters});

  /// Log an error for monitoring
  void logError(dynamic error, StackTrace? stackTrace, {String? reason});

  /// Set user ID for tracking
  void setUserId(String userId);

  /// Set user properties (e.g., role, school)
  void setUserProperty(String name, String value);

  /// Log screen view
  void logScreenView(String screenName);
}

/// Implementation of analytics service
/// TODO: Replace with Firebase Analytics or PostHog in production
class AnalyticsService implements IAnalyticsService {
  @override
  void logEvent(String name, {Map<String, dynamic>? parameters}) {
    if (kDebugMode) {
      if (parameters != null) {
      }
    }

    // TODO: Implement actual analytics
    // Example: FirebaseAnalytics.instance.logEvent(name: name, parameters: parameters);
  }

  @override
  void logError(dynamic error, StackTrace? stackTrace, {String? reason}) {
    if (kDebugMode) {
      if (reason != null) {
      }
      if (stackTrace != null) {
      }
    }

    // TODO: Implement actual error tracking
    // Example: Sentry.captureException(error, stackTrace: stackTrace);
  }

  @override
  void setUserId(String userId) {
    if (kDebugMode) {
    }

    // TODO: Implement actual user tracking
    // Example: FirebaseAnalytics.instance.setUserId(id: userId);
  }

  @override
  void setUserProperty(String name, String value) {
    if (kDebugMode) {
    }

    // TODO: Implement actual user properties
    // Example: FirebaseAnalytics.instance.setUserProperty(name: name, value: value);
  }

  @override
  void logScreenView(String screenName) {
    if (kDebugMode) {
    }

    // TODO: Implement actual screen tracking
    // Example: FirebaseAnalytics.instance.logScreenView(screenName: screenName);
  }
}

/// Key analytics events to track
class AnalyticsEvents {
  // Paper events
  static const paperCreated = 'paper_created';
  static const paperSaved = 'paper_saved';
  static const paperSubmitted = 'paper_submitted';
  static const paperApproved = 'paper_approved';
  static const paperRejected = 'paper_rejected';
  static const paperEdited = 'paper_edited';

  // PDF events
  static const pdfGenerated = 'pdf_generated';
  static const pdfDownloaded = 'pdf_downloaded';
  static const pdfShared = 'pdf_shared';
  static const pdfPrinted = 'pdf_printed';

  // Auth events
  static const userSignedIn = 'user_signed_in';
  static const userSignedOut = 'user_signed_out';
  static const userSignedUp = 'user_signed_up';

  // Error events
  static const errorOccurred = 'error_occurred';
  static const networkError = 'network_error';
  static const validationError = 'validation_error';
}
