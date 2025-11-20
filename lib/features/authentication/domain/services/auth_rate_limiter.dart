import 'package:flutter/foundation.dart';

/// Auth Rate Limiter Service
///
/// Prevents brute force attacks by implementing exponential backoff
/// and temporary lockouts after repeated failed login attempts.
class AuthRateLimiter {
  static const int maxAttempts = 10;
  static const Duration lockoutDuration = Duration(minutes: 15);

  // Track failed attempts per email
  final Map<String, List<DateTime>> _failedAttempts = {};

  /// Check if login is allowed for the given email
  ///
  /// Returns [RateLimitStatus] with:
  /// - isAllowed: true if login attempt is allowed
  /// - delayMs: milliseconds to wait before next attempt
  /// - remainingAttempts: attempts remaining before lockout
  /// - lockedUntil: when the lockout expires (if locked)
  RateLimitStatus canAttemptLogin(String email) {
    final now = DateTime.now();
    final attempts = _failedAttempts[email] ?? [];

    // Remove attempts older than lockout duration
    final recentAttempts = attempts
        .where((attempt) => now.difference(attempt).inMinutes < 15)
        .toList();

    _failedAttempts[email] = recentAttempts;

    // Check if locked out
    if (recentAttempts.length >= maxAttempts) {
      final lockedUntil = recentAttempts.first.add(lockoutDuration);
      final secondsUntilUnlock = lockedUntil.difference(now).inSeconds;

      if (secondsUntilUnlock > 0) {
        return RateLimitStatus(
          isAllowed: false,
          delayMs: 0,
          remainingAttempts: 0,
          lockedUntil: lockedUntil,
          lockoutReason: 'Too many failed attempts. Try again in $secondsUntilUnlock seconds.',
        );
      }
    }

    // Calculate delay based on attempt count
    final delayMs = _calculateDelay(recentAttempts.length);
    final remainingAttempts = maxAttempts - recentAttempts.length;

    return RateLimitStatus(
      isAllowed: true,
      delayMs: delayMs,
      remainingAttempts: remainingAttempts,
      lockedUntil: null,
      lockoutReason: null,
    );
  }

  /// Record a failed login attempt
  void recordFailedAttempt(String email) {
    _failedAttempts.putIfAbsent(email, () => []);
    _failedAttempts[email]!.add(DateTime.now());
  }

  /// Record a successful login - resets the counter
  void resetAttempts(String email) {
    _failedAttempts.remove(email);
  }

  /// Calculate exponential backoff delay in milliseconds
  ///
  /// Progression:
  /// - 0-3 attempts: 0ms
  /// - 4-5 attempts: 5000ms (5 seconds)
  /// - 6-7 attempts: 10000ms (10 seconds)
  /// - 8-9 attempts: 30000ms (30 seconds)
  /// - 10+ attempts: locked out
  int _calculateDelay(int attemptCount) {
    if (attemptCount < 3) return 0;
    if (attemptCount < 5) return 5000;
    if (attemptCount < 7) return 10000;
    if (attemptCount < 10) return 30000;
    return 0; // Locked out
  }

  /// Get current rate limit status for email (for debugging/UI)
  RateLimitStatus getStatus(String email) {
    return canAttemptLogin(email);
  }

  /// Clear all rate limit data (for testing)
  @visibleForTesting
  void clearAll() {
    _failedAttempts.clear();
  }
}

/// Result of a rate limit check
class RateLimitStatus {
  final bool isAllowed;
  final int delayMs;
  final int remainingAttempts;
  final DateTime? lockedUntil;
  final String? lockoutReason;

  RateLimitStatus({
    required this.isAllowed,
    required this.delayMs,
    required this.remainingAttempts,
    required this.lockedUntil,
    required this.lockoutReason,
  });

  bool get isLockedOut => lockedUntil != null;
}
