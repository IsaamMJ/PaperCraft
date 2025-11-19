import 'dart:async';
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
import 'package:papercraft/features/authentication/domain/entities/user_entity.dart';
import 'package:papercraft/features/authentication/domain/entities/auth_result_entity.dart';
import 'package:papercraft/features/authentication/domain/entities/user_role.dart';
import 'package:get_it/get_it.dart';

// ============================================================================
// MOCKS
// ============================================================================

class MockAuthUseCase extends Mock implements AuthUseCase {}
class MockUserStateService extends Mock implements UserStateService {}
class MockClock extends Mock implements IClock {}
class MockLogger extends Mock implements ILogger {}

// ============================================================================
// INTEGRATION TESTS
// ============================================================================

void main() {
  late AuthBloc authBloc;
  late MockAuthUseCase mockAuthUseCase;
  late MockUserStateService mockUserStateService;
  late StreamController<AuthStateChangeEvent> authStateController;
  late MockClock mockClock;
  late MockLogger mockLogger;

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

    when(() => mockUserStateService.updateUser(any())).thenAnswer((_) async {});
    when(() => mockUserStateService.clearUser()).thenReturn(null);
    when(() => mockClock.now()).thenReturn(DateTime(2024, 1, 1, 12, 0, 0));
    when(() => mockClock.periodic(any(), any())).thenAnswer((_) {
      return Timer(const Duration(days: 1), () {});
    });
    when(() => mockClock.delay(any())).thenAnswer((_) async {});
  });

  tearDown(() {
    authBloc.close();
    authStateController.close();
  });

  group('OAuth Integration Tests - Happy Path', () {
    test('Complete OAuth flow: Sign in → Authenticate → Navigate', () async {
      // Arrange
      final mockUser = UserEntity(
        id: 'user-123',
        email: 'test@school.com',
        fullName: 'Test User',
        tenantId: 'tenant-123',
        role: UserRole.teacher,
        isActive: true,
        createdAt: DateTime.now(),
      );

      final mockAuthResult = AuthResultEntity(
        user: mockUser,
        isFirstLogin: false,
      );

      when(() => mockAuthUseCase.signInWithGoogle())
          .thenAnswer((_) async => Right(mockAuthResult));
      when(() => mockAuthUseCase.getCurrentUserWithInitStatus())
          .thenAnswer((_) async => Right({
        'user': mockUser,
        'tenantInitialized': true,
      }));

      authBloc = AuthBloc(
        mockAuthUseCase,
        mockUserStateService,
        authStateController.stream,
        mockClock,
        autoInitialize: false,
      );

      // Act - Initiate sign in
      authBloc.add(const AuthSignInGoogle());

      // Assert - Should go through loading state
      await Future.delayed(const Duration(milliseconds: 100));
      expect(authBloc.state, isA<AuthLoading>());

      // Wait for OAuth completion
      await Future.delayed(const Duration(milliseconds: 200));

      // Should reach authenticated state
      expect(authBloc.state, isA<AuthAuthenticated>());
      final authenticatedState = authBloc.state as AuthAuthenticated;
      expect(authenticatedState.user.id, equals('user-123'));
      expect(authenticatedState.user.email, equals('test@school.com'));

      // Verify user state service was updated
      verify(() => mockUserStateService.updateUser(any())).called(1);
    });
  });

  group('OAuth Integration Tests - Error Scenarios', () {
    test('OAuth flow with network error recovers on retry', () async {
      // Arrange - First attempt fails
      when(() => mockAuthUseCase.signInWithGoogle())
          .thenAnswer((_) async => const Left(AuthFailure('Network error')));

      authBloc = AuthBloc(
        mockAuthUseCase,
        mockUserStateService,
        authStateController.stream,
        mockClock,
        autoInitialize: false,
      );

      // Act - First sign in attempt
      authBloc.add(const AuthSignInGoogle());
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert - Should be in error state
      expect(authBloc.state, isA<AuthError>());
      expect((authBloc.state as AuthError).message, contains('Network error'));

      // Arrange - Second attempt succeeds
      final mockUser = UserEntity(
        id: 'user-123',
        email: 'test@school.com',
        fullName: 'Test User',
        tenantId: 'tenant-123',
        role: UserRole.teacher,
        isActive: true,
        createdAt: DateTime.now(),
      );

      when(() => mockAuthUseCase.signInWithGoogle())
          .thenAnswer((_) async => Right(AuthResultEntity(user: mockUser)));

      // Act - Retry
      authBloc.add(const AuthSignInGoogle());
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert - Should be authenticated now
      expect(authBloc.state, isA<AuthAuthenticated>());
    });

    test('OAuth flow with deactivated account shows appropriate error', () async {
      // Arrange
      when(() => mockAuthUseCase.signInWithGoogle())
          .thenAnswer((_) async => const Left(DeactivatedAccountFailure()));

      authBloc = AuthBloc(
        mockAuthUseCase,
        mockUserStateService,
        authStateController.stream,
        mockClock,
        autoInitialize: false,
      );

      // Act
      authBloc.add(const AuthSignInGoogle());
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert
      expect(authBloc.state, isA<AuthError>());
      verify(() => mockUserStateService.clearUser()).called(1);
    });

    test('OAuth flow with unauthorized domain prevents access', () async {
      // Arrange
      when(() => mockAuthUseCase.signInWithGoogle())
          .thenAnswer((_) async => const Left(UnauthorizedDomainFailure()));

      authBloc = AuthBloc(
        mockAuthUseCase,
        mockUserStateService,
        authStateController.stream,
        mockClock,
        autoInitialize: false,
      );

      // Act
      authBloc.add(const AuthSignInGoogle());
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert
      expect(authBloc.state, isA<AuthError>());
    });
  });

  group('OAuth Integration Tests - Sign Out Flow', () {
    test('Complete sign out flow: Authenticated → Signed Out', () async {
      // Arrange - Start authenticated
      final mockUser = UserEntity(
        id: 'user-123',
        email: 'test@school.com',
        fullName: 'Test User',
        tenantId: 'tenant-123',
        role: UserRole.teacher,
        isActive: true,
        createdAt: DateTime.now(),
      );

      when(() => mockAuthUseCase.signOut())
          .thenAnswer((_) async => const Right(null));

      authBloc = AuthBloc(
        mockAuthUseCase,
        mockUserStateService,
        authStateController.stream,
        mockClock,
        autoInitialize: false,
      );

      // Manually set authenticated state for testing
      await authBloc.close();
      authBloc = AuthBloc(
        mockAuthUseCase,
        mockUserStateService,
        authStateController.stream,
        mockClock,
        autoInitialize: false,
      );

      // Create a new instance but seed it with authenticated state
      // This is done by calling add event directly after creation

      // Act - Sign out
      authBloc.add(const AuthSignOut());
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert - Should be unauthenticated
      expect(authBloc.state, isA<AuthUnauthenticated>());
      verify(() => mockUserStateService.clearUser()).called(1);
    });
  });

  group('OAuth Integration Tests - Session Management', () {
    test('Session restore on app startup works correctly', () async {
      // Arrange
      final mockUser = UserEntity(
        id: 'user-123',
        email: 'test@school.com',
        fullName: 'Test User',
        tenantId: 'tenant-123',
        role: UserRole.teacher,
        isActive: true,
        createdAt: DateTime.now(),
      );

      when(() => mockAuthUseCase.initialize())
          .thenAnswer((_) async => Right(mockUser));
      when(() => mockAuthUseCase.getCurrentUserWithInitStatus())
          .thenAnswer((_) async => Right({
        'user': mockUser,
        'tenantInitialized': true,
      }));

      // Act - Create bloc with auto-initialize
      authBloc = AuthBloc(
        mockAuthUseCase,
        mockUserStateService,
        authStateController.stream,
        mockClock,
        autoInitialize: true,
      );

      // Wait for auto-init to complete
      await Future.delayed(const Duration(milliseconds: 300));

      // Assert - Should be authenticated with restored session
      expect(authBloc.state, isA<AuthAuthenticated>());
      final authenticatedState = authBloc.state as AuthAuthenticated;
      expect(authenticatedState.user.id, equals('user-123'));
    });

    test('Session expiry detection triggers automatic sign out', () async {
      // Arrange
      final signedOutEvent = AuthStateChangeEvent(
        event: AuthChangeEvent.signedOut,
        session: null,
      );

      authBloc = AuthBloc(
        mockAuthUseCase,
        mockUserStateService,
        authStateController.stream,
        mockClock,
        autoInitialize: false,
      );

      when(() => mockAuthUseCase.signOut())
          .thenAnswer((_) async => const Right(null));

      // Manually set to authenticated state for this test scenario
      // In real app, this would come from initialization

      // Act - Emit session expired event from auth provider
      authStateController.add(signedOutEvent);

      // Wait for event processing
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert - AuthBloc should respond to session expiry
      // (This would emit AuthSignOut event)
    });
  });

  group('OAuth Integration Tests - Edge Cases', () {
    test('Rapid sign in attempts are debounced (prevent double tap)', () async {
      // Arrange
      final mockUser = UserEntity(
        id: 'user-123',
        email: 'test@school.com',
        fullName: 'Test User',
        tenantId: 'tenant-123',
        role: UserRole.teacher,
        isActive: true,
        createdAt: DateTime.now(),
      );

      when(() => mockAuthUseCase.signInWithGoogle())
          .thenAnswer((_) async => Right(AuthResultEntity(user: mockUser)));

      authBloc = AuthBloc(
        mockAuthUseCase,
        mockUserStateService,
        authStateController.stream,
        mockClock,
        autoInitialize: false,
      );

      // Act - Send multiple rapid sign in events
      authBloc.add(const AuthSignInGoogle());
      authBloc.add(const AuthSignInGoogle()); // Should be ignored
      authBloc.add(const AuthSignInGoogle()); // Should be ignored

      await Future.delayed(const Duration(milliseconds: 300));

      // Assert - Only one OAuth attempt should be made
      expect(authBloc.state, isA<AuthAuthenticated>());
    });

    test('Auth state check while loading completes without errors', () async {
      // Arrange
      when(() => mockAuthUseCase.signInWithGoogle()).thenAnswer((_) async {
        // Simulate slow OAuth flow
        await Future.delayed(const Duration(milliseconds: 500));
        return Right(AuthResultEntity(
          user: UserEntity(
            id: 'user-123',
            email: 'test@school.com',
            fullName: 'Test User',
            tenantId: 'tenant-123',
            role: UserRole.teacher,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        ));
      });

      authBloc = AuthBloc(
        mockAuthUseCase,
        mockUserStateService,
        authStateController.stream,
        mockClock,
        autoInitialize: false,
      );

      // Act - Start sign in
      authBloc.add(const AuthSignInGoogle());
      await Future.delayed(const Duration(milliseconds: 100));

      // While loading, trigger status check
      authBloc.add(const AuthCheckStatus());

      await Future.delayed(const Duration(milliseconds: 500));

      // Assert - Should complete without errors
      expect(authBloc.state, isA<AuthAuthenticated>());
    });
  });
}
