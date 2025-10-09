/// Production-ready application configuration
///
/// Defines all app-wide constants, limits, and timeouts
class AppConfig {
  // ========================================
  // Network & API Configuration
  // ========================================

  /// Standard network timeout for API calls
  static const Duration networkTimeout = Duration(seconds: 30);

  /// Timeout for long-running operations (PDF generation, file uploads)
  static const Duration longOperationTimeout = Duration(seconds: 60);

  /// Timeout for PDF generation specifically
  static const Duration pdfGenerationTimeout = Duration(seconds: 45);

  /// Timeout for file uploads
  static const Duration fileUploadTimeout = Duration(minutes: 2);

  /// Maximum number of retry attempts for failed requests
  static const int maxNetworkRetries = 2;

  /// Initial delay before retry (exponential backoff)
  static const Duration retryDelay = Duration(milliseconds: 500);

  // ========================================
  // Paper & Question Limits
  // ========================================

  /// Maximum title length for papers
  static const int maxPaperTitleLength = 200;

  /// Minimum title length for papers
  static const int minPaperTitleLength = 3;

  /// Maximum description length
  static const int maxDescriptionLength = 1000;

  /// Maximum number of questions per paper
  static const int maxQuestionsPerPaper = 200;

  /// Maximum number of sections per paper
  static const int maxSectionsPerPaper = 20;

  /// Maximum questions per section
  static const int maxQuestionsPerSection = 100;

  /// Maximum total marks per paper
  static const int maxTotalMarks = 500;

  /// Maximum marks per question
  static const int maxMarksPerQuestion = 100;

  // ========================================
  // PDF Generation Limits
  // ========================================

  /// Maximum PDF file size in megabytes
  static const int maxPdfSizeMB = 10;

  /// Recommended maximum questions for optimal PDF performance
  static const int recommendedMaxQuestionsForPdf = 100;

  /// Warning threshold for large papers
  static const int largePaperWarningThreshold = 50;

  // ========================================
  // Caching Configuration
  // ========================================

  /// Default cache TTL (Time To Live)
  static const Duration defaultCacheTTL = Duration(minutes: 5);

  /// Cache TTL for catalog data (subjects, grades) - longer since rarely changes
  static const Duration catalogCacheTTL = Duration(minutes: 30);

  /// Cache TTL for approved papers list
  static const Duration approvedPapersCacheTTL = Duration(minutes: 10);

  // ========================================
  // UI/UX Configuration
  // ========================================

  /// Debounce duration for search inputs
  static const Duration searchDebounce = Duration(milliseconds: 500);

  /// Duration for success messages
  static const Duration successMessageDuration = Duration(seconds: 3);

  /// Duration for error messages
  static const Duration errorMessageDuration = Duration(seconds: 5);

  /// Pagination page size
  static const int defaultPageSize = 20;

  /// Maximum items to load before requiring pagination
  static const int maxItemsBeforePagination = 50;

  // ========================================
  // Feature Flags (can be overridden by remote config)
  // ========================================

  /// Enable/disable compression mode for PDFs
  static const bool enablePdfCompression = true;

  /// Enable/disable print functionality
  static const bool enablePdfPrint = true;

  /// Enable/disable analytics tracking
  static const bool enableAnalytics = true;

  /// Enable/disable crash reporting
  static const bool enableCrashReporting = true;

  // ========================================
  // Support & Contact
  // ========================================

  /// Support email for users
  static const String supportEmail = 'support@papercraft.app';

  /// Privacy policy URL
  static const String privacyPolicyUrl = 'https://papercraft.app/privacy';

  /// Terms of service URL
  static const String termsOfServiceUrl = 'https://papercraft.app/terms';

  // ========================================
  // App Information
  // ========================================

  /// App name
  static const String appName = 'PaperCraft';

  /// Current environment (dev/prod)
  static String get environment => const String.fromEnvironment('ENV', defaultValue: 'dev');

  /// Is production build
  static bool get isProduction => environment == 'prod';

  /// Is development build
  static bool get isDevelopment => environment == 'dev';

  // ========================================
  // Validation Methods
  // ========================================

  /// Check if paper is too large for optimal PDF generation
  static bool isPaperTooLarge(int questionCount) {
    return questionCount > recommendedMaxQuestionsForPdf;
  }

  /// Check if paper needs pagination warning
  static bool needsPaginationWarning(int questionCount) {
    return questionCount > largePaperWarningThreshold;
  }

  /// Get human-readable file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Get timeout based on operation type
  static Duration getTimeout(OperationType type) {
    switch (type) {
      case OperationType.api:
        return networkTimeout;
      case OperationType.pdfGeneration:
        return pdfGenerationTimeout;
      case OperationType.fileUpload:
        return fileUploadTimeout;
      case OperationType.longRunning:
        return longOperationTimeout;
    }
  }
}

/// Operation types for timeout configuration
enum OperationType {
  api,
  pdfGeneration,
  fileUpload,
  longRunning,
}
