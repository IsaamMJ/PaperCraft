class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? message;
  final ApiErrorType? errorType;
  final String? operation;
  final Duration? duration;
  final Object? originalError;

  const ApiResponse._({
    required this.isSuccess,
    this.data,
    this.message,
    this.errorType,
    this.operation,
    this.duration,
    this.originalError,
  });

  factory ApiResponse.success({
    required T data,
    String? operation,
    Duration? duration,
  }) {
    return ApiResponse._(
      isSuccess: true,
      data: data,
      operation: operation,
      duration: duration,
    );
  }

  factory ApiResponse.error({
    required String message,
    required ApiErrorType type,
    String? operation,
    Duration? duration,
    Object? originalError,
  }) {
    return ApiResponse._(
      isSuccess: false,
      message: message,
      errorType: type,
      operation: operation,
      duration: duration,
      originalError: originalError,
    );
  }

  bool get isError => !isSuccess;
  bool get hasData => data != null;
}

enum ApiErrorType {
  network,      // No internet connection
  timeout,      // Request timeout
  server,       // Server error (5xx)
  validation,   // Validation error (4xx)
  notFound,     // Resource not found
  unauthorized, // Auth error
  unknown,      // Unexpected error
}