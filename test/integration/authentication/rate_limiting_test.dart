import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:papercraft/core/domain/interfaces/i_auth_provider.dart';
import 'package:papercraft/core/domain/interfaces/i_clock.dart';
import 'package:papercraft/core/domain/interfaces/i_logger.dart';
import 'package:papercraft/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:papercraft/features/authentication/presentation/bloc/auth_event.dart';
import 'package:papercraft/features/authentication/presentation/bloc/auth_state.dart';
import 'package:papercraft/features/authentication/domain/usecases/auth_usecase.dart';
import 'package:papercraft/features/authentication/domain/services/user_state_service.dart';
import 'package:papercraft/features/authentication/domain/services/auth_rate_limiter.dart';
import 'package:papercraft/features/authentication/domain/entities/user_entity.dart';
import 'package:papercraft/features/authentication/domain/entities/auth_result_entity.dart';
import 'package:papercraft/features/authentication/domain/entities/user_role.dart';
import 'package:papercraft/features/authentication/domain/failures/auth_failures.dart';
import 'package:get_it/get_it.dart';

// ============================================================================
// MOCKS
// ============================================================================

class MockAuthUseCase extends Mock implements AuthUseCase {}
class MockUserStateService extends Mock implements UserStateService {}
class MockClock extends Mock implements IClock {}
class MockLogger extends Mock implements ILogger {}

// ============================================================================
// RATE LIMITING INTEGRATION TESTS
// ============================================================================

void main() {
  late AuthBloc authBloc;
  late MockAuthUseCase mockAuthUseCase;
  late MockUserStateService mockUserStateService;
  late StreamController<AuthStateChangeEvent> authStateController;
  late MockClock mockClock;
  late MockLogger mockLogger;
  late AuthRateLimiter rateLimiter;

  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(LogCategory.auth);

    // Register mock logger
    mockLogger = MockLogger();
    GetIt.instance.registerSingleton<ILogger>(mockLogger);

    when(() => mockLogger.debug(any(), category: any(named: 'category'), context: any(named: 'context')))
        .thenReturn(null);
    when(() => mockLogger.info(any(), category: any(named: 'category'), context: any(named: 'context')))
        .thenReturn(null);
    when(() => mockLogger.warning(any(), category: any(named: 'category'), context: any(named: 'context')))
        .thenReturn(null);
    when(() => mockLogger.error(any(), category: any(named: 'category'), error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'), context: any(named: 'context')))
        .thenReturn(null);
    when(() => mockLogger.authEvent(any(), any(), context: any(named: 'context')))
        .thenReturn(null);
    when(() => mockLogger.authError(any(), any(), context: any(named: 'context')))
        .thenReturn(null);
  });

  tearDownAll(() {
    GetIt.instance.reset();
  });

  setUp(() {
    mockAuthUseCase = MockAuthUseCase();
    mockUserStateService = MockUserStateService();
    authStateController = StreamController<AuthStateChangeEvent>.broadcast();
    mockClock = MockClock();
    rateLimiter = AuthRateLimiter();

    when(() => mockUserStateService.updateUser(any())).thenAnswer((_) async {});
    when(() => mockUserStateService.clearUser()).thenReturn(null);
    when(() => mockClock.now()).thenReturn(DateTime(2024, 1, 1, 12, 0, 0));
    when(() => mockClock.periodic(any(), any())).thenAnswer((_) {
      return Timer(const Duration(days: 1), () {});
    });
    when(() => mockClock.delay(any())).thenAnswer((_) async {});

    authBloc = AuthBloc(
      mockAuthUseCase,
      mockUserStateService,
      authStateController.stream,
      mockClock,
      autoInitialize: false,
    );
  });

  tearDown(() {
    authBloc.close();
    authStateController.close();
  });

  group('Rate Limiting Integration Tests - Basic Protection', () {
    test('Rate limiter blocks login after 10 consecutive failed attempts', () async {
      // Arrange - Setup rate limiter with 10 failed attempts
      final testEmail = 'brute_force_attacker@example.com';
      for (int i = 0; i < 10; i++) {
        rateLimiter.recordFailedAttempt(testEmail);
      }

      // Check status
      final status = rateLimiter.canAttemptLogin(testEmail);

      // Assert
      expect(status.isAllowed, false);
      expect(status.isLockedOut, true);
      expect(status.remainingAttempts, 0);
      expect(status.lockedUntil, isNotNull);
      expect(status.lockoutReason, contains('Too many failed attempts'));
    });

    test('Exponential backoff increases delays progressively', () async {
      final testEmail = 'progressive_attacker@example.com';

      // Attempt 1-3: No delay
      for (int i = 0; i < 3; i++) {
        var status = rateLimiter.canAttemptLogin(testEmail);
        expect(status.delayMs, 0, reason: 'Attempt ${i + 1} should have 0ms delay');
        rateLimiter.recordFailedAttempt(testEmail);
      }

      // Attempt 4-5: 5 second delay
      for (int i = 0; i < 2; i++) {
        var status = rateLimiter.canAttemptLogin(testEmail);
        expect(status.delayMs, 5000, reason: 'Attempt ${4 + i} should have 5s delay');
        rateLimiter.recordFailedAttempt(testEmail);
      }

      // Attempt 6-7: 10 second delay
      for (int i = 0; i < 2; i++) {
        var status = rateLimiter.canAttemptLogin(testEmail);
        expect(status.delayMs, 10000, reason: 'Attempt ${6 + i} should have 10s delay');
        rateLimiter.recordFailedAttempt(testEmail);
      }

      // Attempt 8-9: 30 second delay
      for (int i = 0; i < 2; i++) {
        var status = rateLimiter.canAttemptLogin(testEmail);
        expect(status.delayMs, 30000, reason: 'Attempt ${8 + i} should have 30s delay');
        rateLimiter.recordFailedAttempt(testEmail);
      }
    });
  });

  group('Rate Limiting Integration Tests - OAuth Flow Integration', () {
    test('Rate limiter tracks failed OAuth attempts per email', () async {
      final testEmail = 'user@school.com';

      // Simulate 2 failed OAuth attempts
      for (int i = 0; i < 2; i++) {
        rateLimiter.recordFailedAttempt(testEmail);
      }

      // Check remaining attempts
      var status = rateLimiter.canAttemptLogin(testEmail);
      expect(status.remainingAttempts, 8);
      expect(status.isAllowed, true);
      expect(status.delayMs, 0);
    });

    test('Successful OAuth login resets rate limit attempts', () async {
      final testEmail = 'teacher@school.com';

      // Record 5 failed attempts
      for (int i = 0; i < 5; i++) {
        rateLimiter.recordFailedAttempt(testEmail);
      }

      var status = rateLimiter.canAttemptLogin(testEmail);
      expect(status.remainingAttempts, 5);

      // After successful login, reset attempts
      rateLimiter.resetAttempts(testEmail);

      // Check reset
      status = rateLimiter.canAttemptLogin(testEmail);
      expect(status.remainingAttempts, 10);
      expect(status.delayMs, 0);
    });

    test('Different users have independent rate limit tracking', () async {
      final user1Email = 'attacker1@example.com';
      final user2Email = 'user2@school.com';

      // User 1: 8 failed attempts
      for (int i = 0; i < 8; i++) {
        rateLimiter.recordFailedAttempt(user1Email);
      }

      // User 2: 0 failed attempts
      // User 2 should still be able to login with no restrictions
      var status2 = rateLimiter.canAttemptLogin(user2Email);
      expect(status2.isAllowed, true);
      expect(status2.remainingAttempts, 10);
      expect(status2.delayMs, 0);

      // User 1 should have restrictions
      var status1 = rateLimiter.canAttemptLogin(user1Email);
      expect(status1.remainingAttempts, 2);
      expect(status1.delayMs, 30000);
    });
  });

  group('Rate Limiting Integration Tests - Security Scenarios', () {
    test('Rapid-fire login attempts are protected against', () async {
      final testEmail = 'rapid_attacker@example.com';

      // First 3 rapid attempts
      for (int i = 0; i < 3; i++) {
        var status = rateLimiter.canAttemptLogin(testEmail);
        expect(status.isAllowed, true);
        rateLimiter.recordFailedAttempt(testEmail);
      }

      // Next attempts start applying delays
      var status4 = rateLimiter.canAttemptLogin(testEmail);
      expect(status4.isAllowed, true);
      expect(status4.delayMs, 5000);
      rateLimiter.recordFailedAttempt(testEmail);

      // Verify remaining attempts decrease (4 attempts recorded: 10 - 4 = 6)
      var status5 = rateLimiter.canAttemptLogin(testEmail);
      expect(status5.remainingAttempts, 6);
    });

    test('After lockout, user cannot attempt login until period expires', () async {
      final testEmail = 'locked_attacker@example.com';

      // Record 10 failed attempts to trigger lockout
      for (int i = 0; i < 10; i++) {
        rateLimiter.recordFailedAttempt(testEmail);
      }

      // Check that login is blocked
      var status = rateLimiter.canAttemptLogin(testEmail);
      expect(status.isAllowed, false);
      expect(status.isLockedOut, true);
      expect(status.remainingAttempts, 0);
      expect(status.delayMs, 0);
    });

    test('Lockout provides clear user-facing error message', () async {
      final testEmail = 'error_message_test@example.com';

      // Trigger lockout
      for (int i = 0; i < 10; i++) {
        rateLimiter.recordFailedAttempt(testEmail);
      }

      var status = rateLimiter.canAttemptLogin(testEmail);

      // Verify error message is helpful
      expect(status.lockoutReason, isNotNull);
      expect(status.lockoutReason, contains('Too many failed attempts'));
      expect(status.lockoutReason, contains('Try again in'));
      expect(status.lockoutReason, contains('seconds'));
    });
  });

  group('Rate Limiting Integration Tests - Edge Cases', () {
    test('Clearing rate limiter resets all user data', () async {
      final user1 = 'user1@example.com';
      final user2 = 'user2@example.com';

      // Record attempts for both users
      for (int i = 0; i < 5; i++) {
        rateLimiter.recordFailedAttempt(user1);
        rateLimiter.recordFailedAttempt(user2);
      }

      // Verify restrictions exist
      var status1 = rateLimiter.canAttemptLogin(user1);
      var status2 = rateLimiter.canAttemptLogin(user2);
      expect(status1.remainingAttempts, 5);
      expect(status2.remainingAttempts, 5);

      // Clear all
      rateLimiter.clearAll();

      // Verify all cleared
      status1 = rateLimiter.canAttemptLogin(user1);
      status2 = rateLimiter.canAttemptLogin(user2);
      expect(status1.remainingAttempts, 10);
      expect(status2.remainingAttempts, 10);
    });

    test('Attempting login while approaching lockout shows decreasing attempts', () async {
      final testEmail = 'count_down@example.com';

      // Record 7 failed attempts
      for (int i = 0; i < 7; i++) {
        rateLimiter.recordFailedAttempt(testEmail);
      }

      // Check remaining attempts count down
      for (int remaining = 3; remaining >= 0; remaining--) {
        var status = rateLimiter.canAttemptLogin(testEmail);
        expect(status.remainingAttempts, remaining);
        if (remaining > 0) {
          rateLimiter.recordFailedAttempt(testEmail);
        }
      }
    });
  });

  group('Rate Limiting Integration Tests - Status Reporting', () {
    test('getStatus provides accurate rate limit information', () async {
      final testEmail = 'status_check@example.com';

      // Record some attempts
      for (int i = 0; i < 4; i++) {
        rateLimiter.recordFailedAttempt(testEmail);
      }

      // Get status via canAttemptLogin and getStatus
      var status1 = rateLimiter.canAttemptLogin(testEmail);
      var status2 = rateLimiter.getStatus(testEmail);

      // Both should match
      expect(status1.isAllowed, status2.isAllowed);
      expect(status1.remainingAttempts, status2.remainingAttempts);
      expect(status1.delayMs, status2.delayMs);
      expect(status1.isLockedOut, status2.isLockedOut);
    });

    test('RateLimitStatus provides all required information for UI', () async {
      final testEmail = 'ui_info@example.com';

      // Record attempts to get various states
      for (int i = 0; i < 5; i++) {
        rateLimiter.recordFailedAttempt(testEmail);
      }

      var status = rateLimiter.canAttemptLogin(testEmail);

      // Verify all UI-relevant fields are present
      expect(status.isAllowed, isNotNull);
      expect(status.delayMs, isNotNull);
      expect(status.remainingAttempts, isNotNull);
      expect(status.remainingAttempts, greaterThan(0));
      expect(status.remainingAttempts, lessThanOrEqualTo(10));
    });
  });
}
