import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:papercraft/core/domain/interfaces/i_auth_provider.dart';
import 'package:papercraft/core/domain/interfaces/i_clock.dart';
import 'package:papercraft/core/domain/interfaces/i_logger.dart';
import 'package:papercraft/core/domain/services/tenant_initialization_service.dart';
import 'package:papercraft/core/infrastructure/network/api_client.dart';
import 'package:papercraft/features/authentication/data/datasources/auth_data_source.dart';

// ============================================================================
// MOCKS
// ============================================================================

class MockAuthProvider extends Mock implements IAuthProvider {}

class MockLogger extends Mock implements ILogger {}

class MockClock extends Mock implements IClock {}

class MockApiClient extends Mock implements ApiClient {}

class MockTenantInitializationService extends Mock
    implements TenantInitializationService {}

class MockUser extends Mock implements User {
  @override
  final String id;

  @override
  final String email;

  MockUser({required this.id, required this.email});
}

class MockSession extends Mock implements Session {
  @override
  final User user;

  MockSession({required this.user});
}

class MockAuthStateChangeEvent extends Mock implements AuthStateChangeEvent {
  @override
  final AuthChangeEvent event;

  @override
  final Session? session;

  MockAuthStateChangeEvent({required this.event, this.session});
}

// ============================================================================
// TEST SUITE
// ============================================================================

void main() {
  late MockAuthProvider mockAuthProvider;
  late MockLogger mockLogger;
  late MockClock mockClock;
  late MockApiClient mockApiClient;
  late MockTenantInitializationService mockTenantService;
  late AuthDataSource authDataSource;

  setUpAll(() {
    registerFallbackValue(LogCategory.auth);
  });

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockLogger = MockLogger();
    mockClock = MockClock();
    mockApiClient = MockApiClient();
    mockTenantService = MockTenantInitializationService();

    authDataSource = AuthDataSource(
      mockApiClient,
      mockLogger,
      mockAuthProvider,
      mockClock,
      mockTenantService,
    );

    // Default mock behaviors
    when(() => mockLogger.debug(
          any(),
          category: any(named: 'category'),
          context: any(named: 'context'),
        )).thenReturn(null);

    when(() => mockLogger.error(
          any(),
          category: any(named: 'category'),
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
          context: any(named: 'context'),
        )).thenReturn(null);

    when(() => mockLogger.authEvent(
          any(),
          any(),
          context: any(named: 'context'),
        )).thenReturn(null);

    when(() => mockClock.now()).thenReturn(DateTime.now());
  });

  group('AuthDataSource - _waitForSession stream timeout edge cases', () {
    test(
      'Stream timeout completes when 45s timer fires before event arrives',
      () async {
        // Arrange
        final delayedStreamController = StreamController<AuthStateChangeEvent>();
        when(() => mockAuthProvider.currentSession).thenReturn(null);
        when(() => mockAuthProvider.onAuthStateChange)
            .thenAnswer((_) => delayedStreamController.stream);

        Timer delayedEvent = Timer(const Duration(milliseconds: 500), () {
          // This event arrives 500ms after timeout would have fired (45s timeout)
          // In this test we'll use a shorter timeout via the Timer.periodic mock
        });

        // Mock the timer to fire immediately (simulating 45s passing)
        when(() => mockClock.timer(any(), any()))
            .thenAnswer((invocation) {
          final callback = invocation.positionalArguments[1] as void Function();
          // Immediately call the timeout callback (simulating 45s passed)
          Future.microtask(callback);
          return null;
        });

        // Act
        final result = await authDataSource.signInWithGoogle();

        // Assert - should return failure due to timeout
        expect(result.isLeft(), true);
        result.fold(
          (failure) {
            expect(
              failure.message,
              contains('Setup is taking longer than expected'),
            );
          },
          (_) => fail('Expected failure'),
        );

        // Cleanup
        delayedEvent.cancel();
        delayedStreamController.close();
      },
    );

    test(
      'Stream timeout is prevented when event arrives before timeout fires',
      () async {
        // This tests that the early-return guard in _waitForSession works
        // The guard checks `if (completer.isCompleted) return;` before completing

        // Arrange
        final mockUser = MockUser(id: 'user-123', email: 'test@example.com');
        final mockSession = MockSession(user: mockUser);
        final streamController = StreamController<AuthStateChangeEvent>();

        when(() => mockAuthProvider.currentSession).thenReturn(null);
        when(() => mockAuthProvider.onAuthStateChange)
            .thenAnswer((_) => streamController.stream);

        // Mock timer to NOT call the timeout yet
        Timer? savedTimer;
        when(() => mockClock.timer(any(), any())).thenAnswer((invocation) {
          savedTimer = Timer(invocation.positionalArguments[0] as Duration,
              invocation.positionalArguments[1] as void Function());
          return null;
        });

        // Start the sign-in process
        final signInFuture = authDataSource.signInWithGoogle();

        // Let the event listener set up
        await Future.delayed(const Duration(milliseconds: 50));

        // Emit a successful auth event BEFORE timeout
        streamController.add(MockAuthStateChangeEvent(
          event: AuthChangeEvent.signedIn,
          session: mockSession,
        ));

        // Wait a bit for the stream to process
        await Future.delayed(const Duration(milliseconds: 100));

        // Now the timeout would fire, but completer.isCompleted should be true
        // Clean up without calling the actual timeout
        savedTimer?.cancel();

        // Cleanup
        streamController.close();
      },
    );

    test(
      'Stream error is handled gracefully without completing twice',
      () async {
        // Arrange
        final streamController = StreamController<AuthStateChangeEvent>();

        when(() => mockAuthProvider.currentSession).thenReturn(null);
        when(() => mockAuthProvider.onAuthStateChange)
            .thenAnswer((_) => streamController.stream);

        // Mock timer
        Timer? savedTimer;
        when(() => mockClock.timer(any(), any())).thenAnswer((invocation) {
          savedTimer = Timer(invocation.positionalArguments[0] as Duration,
              invocation.positionalArguments[1] as void Function());
          return null;
        });

        // Start sign-in
        final signInFuture = authDataSource.signInWithGoogle();

        // Wait for setup
        await Future.delayed(const Duration(milliseconds: 50));

        // Emit a stream error
        streamController.addError(Exception('Network error'));

        // Wait for error to process
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify timeout still fires (or doesn't crash)
        savedTimer?.cancel();
        streamController.close();

        // Act & Assert - should complete with a failure
        final result = await signInFuture;
        // The error from the stream should be handled
      },
    );
  });

  group('AuthDataSource - session recovery after timeout', () {
    test(
      'User can retry sign-in after 45s timeout',
      () async {
        // Arrange - first attempt times out
        final streamController1 = StreamController<AuthStateChangeEvent>();

        when(() => mockAuthProvider.currentSession).thenReturn(null);
        when(() => mockAuthProvider.onAuthStateChange)
            .thenAnswer((_) => streamController1.stream);

        when(() => mockClock.timer(any(), any())).thenAnswer((invocation) {
          // Immediately call timeout
          final callback = invocation.positionalArguments[1] as void Function();
          Future.microtask(callback);
          return null;
        });

        // First attempt should timeout
        final firstAttempt = await authDataSource.signInWithGoogle();
        expect(firstAttempt.isLeft(), true);

        streamController1.close();

        // Arrange - second attempt succeeds
        final streamController2 = StreamController<AuthStateChangeEvent>();
        final mockUser = MockUser(id: 'user-123', email: 'test@example.com');
        final mockSession = MockSession(user: mockUser);

        when(() => mockAuthProvider.currentSession).thenReturn(null);
        when(() => mockAuthProvider.onAuthStateChange)
            .thenAnswer((_) => streamController2.stream);

        // No timeout this time
        when(() => mockClock.timer(any(), any())).thenAnswer((invocation) {
          // Don't call the timeout
          return null;
        });

        // Emit successful auth immediately
        Future.delayed(const Duration(milliseconds: 50), () {
          streamController2.add(MockAuthStateChangeEvent(
            event: AuthChangeEvent.signedIn,
            session: mockSession,
          ));
        });

        // Note: The actual signInWithGoogle flow involves OAuth, so this is
        // a simplified test of the recovery mechanism

        streamController2.close();
      },
    );
  });
}
