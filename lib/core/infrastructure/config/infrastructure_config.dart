class InfrastructureConfig {
  InfrastructureConfig._();

  // Network timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 10);

  // Cache settings
  static const Duration cacheExpiration = Duration(hours: 1);
  static const Duration shortCacheExpiration = Duration(minutes: 15);

  // Retry settings
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // File upload limits
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const List<String> allowedFileTypes = ['pdf', 'doc', 'docx', 'txt'];

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // HTTP settings
  static const int httpErrorThreshold = 400;
}