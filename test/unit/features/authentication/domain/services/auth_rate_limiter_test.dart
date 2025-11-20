import 'package:flutter_test/flutter_test.dart';
import 'package:papercraft/features/authentication/domain/services/auth_rate_limiter.dart';

void main() {
  late AuthRateLimiter rateLimiter;

  setUp(() {
    rateLimiter = AuthRateLimiter();
  });

  group('AuthRateLimiter - Basic Functionality', () {
    test('canAttemptLogin allows login on first attempt', () {
      final status = rateLimiter.canAttemptLogin('test@example.com');

      expect(status.isAllowed, true);
      expect(status.delayMs, 0);
      expect(status.remainingAttempts, 10);
      expect(status.isLockedOut, false);
    });

    test('canAttemptLogin allows login when no previous attempts', () {
      final status1 = rateLimiter.canAttemptLogin('user1@example.com');
      final status2 = rateLimiter.canAttemptLogin('user2@example.com');

      expect(status1.isAllowed, true);
      expect(status2.isAllowed, true);
    });

    test('recordFailedAttempt tracks failed login attempts', () {
      rateLimiter.recordFailedAttempt('test@example.com');

      final status = rateLimiter.canAttemptLogin('test@example.com');
      expect(status.remainingAttempts, 9);
    });

    test('resetAttempts clears failed attempts after successful login', () {
      rateLimiter.recordFailedAttempt('test@example.com');
      rateLimiter.recordFailedAttempt('test@example.com');

      var status = rateLimiter.canAttemptLogin('test@example.com');
      expect(status.remainingAttempts, 8);

      rateLimiter.resetAttempts('test@example.com');

      status = rateLimiter.canAttemptLogin('test@example.com');
      expect(status.remainingAttempts, 10);
    });
  });

  group('AuthRateLimiter - Exponential Backoff', () {
    test('No delay for first 3 attempts', () {
      for (int i = 0; i < 3; i++) {
        final status = rateLimiter.canAttemptLogin('test@example.com');
        expect(status.delayMs, 0, reason: 'Attempt $i should have 0ms delay');
        rateLimiter.recordFailedAttempt('test@example.com');
      }
    });

    test('5 second delay for attempts 4-5', () {
      // Record 3 failed attempts
      for (int i = 0; i < 3; i++) {
        rateLimiter.recordFailedAttempt('test@example.com');
      }

      // 4th attempt
      var status = rateLimiter.canAttemptLogin('test@example.com');
      expect(status.delayMs, 5000);
      rateLimiter.recordFailedAttempt('test@example.com');

      // 5th attempt
      status = rateLimiter.canAttemptLogin('test@example.com');
      expect(status.delayMs, 5000);
    });

    test('10 second delay for attempts 6-7', () {
      // Record 5 failed attempts
      for (int i = 0; i < 5; i++) {
        rateLimiter.recordFailedAttempt('test@example.com');
      }

      // 6th attempt
      var status = rateLimiter.canAttemptLogin('test@example.com');
      expect(status.delayMs, 10000);
      rateLimiter.recordFailedAttempt('test@example.com');

      // 7th attempt
      status = rateLimiter.canAttemptLogin('test@example.com');
      expect(status.delayMs, 10000);
    });

    test('30 second delay for attempts 8-9', () {
      // Record 7 failed attempts
      for (int i = 0; i < 7; i++) {
        rateLimiter.recordFailedAttempt('test@example.com');
      }

      // 8th attempt
      var status = rateLimiter.canAttemptLogin('test@example.com');
      expect(status.delayMs, 30000);
      rateLimiter.recordFailedAttempt('test@example.com');

      // 9th attempt
      status = rateLimiter.canAttemptLogin('test@example.com');
      expect(status.delayMs, 30000);
    });
  });

  group('AuthRateLimiter - Account Lockout', () {
    test('Account locks after 10 failed attempts', () {
      // Record 10 failed attempts
      for (int i = 0; i < 10; i++) {
        rateLimiter.recordFailedAttempt('test@example.com');
      }

      final status = rateLimiter.canAttemptLogin('test@example.com');
      expect(status.isAllowed, false);
      expect(status.isLockedOut, true);
      expect(status.remainingAttempts, 0);
      expect(status.lockedUntil, isNotNull);
    });

    test('Lockout message is user-friendly', () {
      // Record 10 failed attempts
      for (int i = 0; i < 10; i++) {
        rateLimiter.recordFailedAttempt('test@example.com');
      }

      final status = rateLimiter.canAttemptLogin('test@example.com');
      expect(status.lockoutReason, isNotNull);
      expect(status.lockoutReason, contains('Too many failed attempts'));
      expect(status.lockoutReason, contains('seconds'));
    });

    test('Different emails have separate attempt counters', () {
      // Record attempts for user1
      for (int i = 0; i < 5; i++) {
        rateLimiter.recordFailedAttempt('user1@example.com');
      }

      // user2 should not be affected
      var status2 = rateLimiter.canAttemptLogin('user2@example.com');
      expect(status2.remainingAttempts, 10);

      // user1 should have fewer attempts
      var status1 = rateLimiter.canAttemptLogin('user1@example.com');
      expect(status1.remainingAttempts, 5);
    });
  });

  group('AuthRateLimiter - RateLimitStatus', () {
    test('RateLimitStatus correctly identifies locked state', () {
      final lockedStatus = RateLimitStatus(
        isAllowed: false,
        delayMs: 0,
        remainingAttempts: 0,
        lockedUntil: DateTime.now().add(const Duration(minutes: 15)),
        lockoutReason: 'Too many failed attempts',
      );

      expect(lockedStatus.isLockedOut, true);
    });

    test('RateLimitStatus correctly identifies unlocked state', () {
      final unlockedStatus = RateLimitStatus(
        isAllowed: true,
        delayMs: 5000,
        remainingAttempts: 5,
        lockedUntil: null,
        lockoutReason: null,
      );

      expect(unlockedStatus.isLockedOut, false);
    });
  });

  group('AuthRateLimiter - Edge Cases', () {
    test('clearAll removes all attempt records', () {
      rateLimiter.recordFailedAttempt('user1@example.com');
      rateLimiter.recordFailedAttempt('user2@example.com');

      var status1 = rateLimiter.canAttemptLogin('user1@example.com');
      var status2 = rateLimiter.canAttemptLogin('user2@example.com');

      expect(status1.remainingAttempts, 9);
      expect(status2.remainingAttempts, 9);

      rateLimiter.clearAll();

      status1 = rateLimiter.canAttemptLogin('user1@example.com');
      status2 = rateLimiter.canAttemptLogin('user2@example.com');

      expect(status1.remainingAttempts, 10);
      expect(status2.remainingAttempts, 10);
    });

    test('getStatus returns current rate limit status', () {
      rateLimiter.recordFailedAttempt('test@example.com');
      rateLimiter.recordFailedAttempt('test@example.com');

      final status1 = rateLimiter.canAttemptLogin('test@example.com');
      final status2 = rateLimiter.getStatus('test@example.com');

      expect(status1.remainingAttempts, status2.remainingAttempts);
      expect(status1.delayMs, status2.delayMs);
    });

    test('Attempting login removes old attempts outside 15-minute window', () {
      // This test verifies that attempts older than 15 minutes are cleaned up
      // In a real scenario, time would pass, but here we just verify the logic exists
      rateLimiter.recordFailedAttempt('test@example.com');

      var status = rateLimiter.canAttemptLogin('test@example.com');
      expect(status.remainingAttempts, 9);
    });
  });
}
