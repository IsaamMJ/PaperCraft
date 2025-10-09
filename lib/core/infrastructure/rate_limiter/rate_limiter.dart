// core/infrastructure/rate_limiter/rate_limiter.dart

/// Rate limiter to prevent resource exhaustion and abuse
///
/// Tracks operation frequency per user/operation and enforces limits
class RateLimiter {
  final Map<String, List<DateTime>> _callHistory = {};
  final int maxCallsPerWindow;
  final Duration window;

  RateLimiter({
    required this.maxCallsPerWindow,
    this.window = const Duration(minutes: 1),
  });

  /// Check if operation can proceed based on rate limit
  ///
  /// Returns true if operation is allowed, false if rate limit exceeded
  bool canProceed(String operationKey) {
    final now = DateTime.now();
    final windowStart = now.subtract(window);

    // Clean up old entries outside the window
    _callHistory[operationKey]?.removeWhere((time) => time.isBefore(windowStart));

    final recentCalls = _callHistory[operationKey]?.length ?? 0;

    if (recentCalls >= maxCallsPerWindow) {
      return false;
    }

    // Record this call
    _callHistory.putIfAbsent(operationKey, () => []).add(now);
    return true;
  }

  /// Get wait time before next operation is allowed
  ///
  /// Returns Duration.zero if operation can proceed immediately
  Duration getWaitTime(String operationKey) {
    final calls = _callHistory[operationKey];
    if (calls == null || calls.isEmpty) {
      return Duration.zero;
    }

    if (calls.length < maxCallsPerWindow) {
      return Duration.zero;
    }

    // Find the oldest call in the current window
    final now = DateTime.now();
    final windowStart = now.subtract(window);

    // Clean up old entries
    calls.removeWhere((time) => time.isBefore(windowStart));

    if (calls.length < maxCallsPerWindow) {
      return Duration.zero;
    }

    // Calculate time until oldest call expires
    final oldestCall = calls.first;
    final timeSinceOldest = now.difference(oldestCall);

    if (timeSinceOldest >= window) {
      return Duration.zero;
    }

    return window - timeSinceOldest;
  }

  /// Get remaining calls allowed in current window
  int getRemainingCalls(String operationKey) {
    final now = DateTime.now();
    final windowStart = now.subtract(window);

    // Clean up old entries
    _callHistory[operationKey]?.removeWhere((time) => time.isBefore(windowStart));

    final recentCalls = _callHistory[operationKey]?.length ?? 0;
    return maxCallsPerWindow - recentCalls;
  }

  /// Reset rate limit for a specific operation
  void reset(String operationKey) {
    _callHistory.remove(operationKey);
  }

  /// Clear all rate limit history
  void clearAll() {
    _callHistory.clear();
  }

  /// Cleanup expired entries (call periodically)
  void cleanup() {
    final now = DateTime.now();
    final windowStart = now.subtract(window);

    for (final key in _callHistory.keys.toList()) {
      _callHistory[key]?.removeWhere((time) => time.isBefore(windowStart));

      // Remove empty lists
      if (_callHistory[key]?.isEmpty ?? true) {
        _callHistory.remove(key);
      }
    }
  }
}

/// Pre-configured rate limiters for common operations
class RateLimiters {
  /// PDF generation rate limiter (10 per minute)
  static final pdfGeneration = RateLimiter(
    maxCallsPerWindow: 10,
    window: const Duration(minutes: 1),
  );

  /// Paper submission rate limiter (20 per hour)
  static final paperSubmission = RateLimiter(
    maxCallsPerWindow: 20,
    window: const Duration(hours: 1),
  );

  /// API call rate limiter (60 per minute)
  static final apiCalls = RateLimiter(
    maxCallsPerWindow: 60,
    window: const Duration(minutes: 1),
  );

  /// File upload rate limiter (30 per hour)
  static final fileUploads = RateLimiter(
    maxCallsPerWindow: 30,
    window: const Duration(hours: 1),
  );

  /// Cleanup all rate limiters
  static void cleanupAll() {
    pdfGeneration.cleanup();
    paperSubmission.cleanup();
    apiCalls.cleanup();
    fileUploads.cleanup();
  }
}
