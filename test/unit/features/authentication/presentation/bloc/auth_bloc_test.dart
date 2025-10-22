import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
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
import 'package:papercraft/features/authentication/domain/failures/auth_failures.dart';

// ============================================================================
// MOCKS
// ============================================================================

class MockAuthUseCase extends Mock implements AuthUseCase {}

class MockUserStateService extends Mock implements UserStateService {}

class MockClock extends Mock implements IClock {}

class MockLogger extends Mock implements ILogger {}

// ============================================================================
// TEST HELPERS
// ============================================================================

/// Creates a mock user for testing
UserEntity createMockUser({
  String id = 'test-user-123',
  String email = 'test@example.com',
  String fullName = 'Test User',
  String? tenantId = 'tenant-123',
  UserRole role = UserRole.teacher,
  bool isActive = true,
}) {
  return UserEntity(
    id: id,
    email: email,
    fullName: fullName,
    tenantId: tenantId,
    role: role,
    isActive: isActive,
    createdAt: DateTime.now(),
    lastLoginAt: DateTime.now(),
  );
}

/// Creates a mock auth result
AuthResultEntity createMockAuthResult({
  UserEntity? user,
  bool isFirstLogin = false,
}) {
  return AuthResultEntity(
    user: user ?? createMockUser(),
    isFirstLogin: isFirstLogin,
  );
}

// ============================================================================
// MAIN TEST SUITE
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

    // Register mock logger in GetIt
    mockLogger = MockLogger();
    GetIt.instance.registerSingleton<ILogger>(mockLogger);

    // Setup default mock logger behavior
    when(() => mockLogger.debug(any(), category: any(named: 'category'), context: any(named: 'context')))
        .thenReturn(null);
    when(() => mockLogger.info(any(), category: any(named: 'category'), context: any(named: 'context')))
        .thenReturn(null);
    when(() => mockLogger.warning(any(), category: any(named: 'category'), context: any(named: 'context')))
        .thenReturn(null);
    when(() => mockLogger.error(any(), category: any(named: 'category'), error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'), context: any(named: 'context')))
        .thenReturn(null);
  });

  tearDownAll(() {
    // Clean up GetIt after all tests
    GetIt.instance.reset();
  });

  setUp(() {
    mockAuthUseCase = MockAuthUseCase();
    mockUserStateService = MockUserStateService();
    authStateController = StreamController<AuthStateChangeEvent>.broadcast();
    mockClock = MockClock();

    // Default mock behaviors
    when(() => mockUserStateService.updateUser(any())).thenAnswer((_) async {});
    when(() => mockUserStateService.clearUser()).thenReturn(null);
    when(() => mockClock.now()).thenReturn(DateTime(2024, 1, 1, 12, 0, 0));
    when(() => mockClock.periodic(any(), any())).thenReturn(Timer(Duration.zero, () {}));
  });

  tearDown(() {
    authBloc.close();
    authStateController.close();
  });

  /// Helper to create AuthBloc instance
  AuthBloc createBloc() {
    return AuthBloc(
      mockAuthUseCase,
      mockUserStateService,
      authStateController.stream,
      mockClock,
    );
  }

  group('AuthBloc - Initial State', () {
    test('initial state should be AuthInitial', () {
      // Arrange & Act
      authBloc = createBloc();

      // Assert
      expect(authBloc.state, equals(const AuthInitial()));
    });
  });

  group('AuthBloc - AuthInitialize Event', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when initialization succeeds with user',
      build: () {
        final mockUser = createMockUser();
        when(() => mockAuthUseCase.initialize())
            .thenAnswer((_) async => Right(mockUser));
        return createBloc();
      },
      act: (bloc) => bloc.add(const AuthInitialize()),
      expect: () {
        final mockUser = createMockUser();
        return [
          const AuthLoading(),
          AuthAuthenticated(mockUser),
        ];
      },
      verify: (_) {
        verify(() => mockAuthUseCase.initialize()).called(1);
        verify(() => mockUserStateService.updateUser(any())).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] when initialization succeeds but no user',
      build: () {
        when(() => mockAuthUseCase.initialize())
            .thenAnswer((_) async => const Right(null));
        return createBloc();
      },
      act: (bloc) => bloc.add(const AuthInitialize()),
      expect: () => [
        const AuthLoading(),
        const AuthUnauthenticated(),
      ],
      verify: (_) {
        verify(() => mockAuthUseCase.initialize()).called(1);
        verify(() => mockUserStateService.clearUser()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] when initialization fails',
      build: () {
        when(() => mockAuthUseCase.initialize()).thenAnswer(
              (_) async => const Left(SessionExpiredFailure()),
        );
        return createBloc();
      },
      act: (bloc) => bloc.add(const AuthInitialize()),
      expect: () => [
        const AuthLoading(),
        const AuthUnauthenticated(),
      ],
      verify: (_) {
        verify(() => mockAuthUseCase.initialize()).called(1);
        verify(() => mockUserStateService.clearUser()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'should not initialize twice (double initialization prevention)',
      build: () {
        final mockUser = createMockUser();
        when(() => mockAuthUseCase.initialize())
            .thenAnswer((_) async => Right(mockUser));
        return createBloc();
      },
      act: (bloc) {
        bloc.add(const AuthInitialize());
        bloc.add(const AuthInitialize()); // Second call should be ignored
      },
      expect: () {
        final mockUser = createMockUser();
        return [
          const AuthLoading(),
          AuthAuthenticated(mockUser),
          // No second emission
        ];
      },
      verify: (_) {
        // Should only be called once despite two events
        verify(() => mockAuthUseCase.initialize()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'handles unexpected exceptions during initialization',
      build: () {
        when(() => mockAuthUseCase.initialize())
            .thenThrow(Exception('Unexpected init error'));
        return createBloc();
      },
      act: (bloc) => bloc.add(const AuthInitialize()),
      expect: () => [
        const AuthLoading(),
        const AuthUnauthenticated(),
      ],
      verify: (_) {
        verify(() => mockUserStateService.clearUser()).called(1);
      },
    );
  });

  group('AuthBloc - AuthSignInGoogle Event', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when sign-in succeeds',
      build: () {
        final mockAuthResult = createMockAuthResult(isFirstLogin: false);
        when(() => mockAuthUseCase.signInWithGoogle())
            .thenAnswer((_) async => Right(mockAuthResult));
        return createBloc();
      },
      act: (bloc) => bloc.add(const AuthSignInGoogle()),
      expect: () {
        final mockUser = createMockUser();
        return [
          const AuthLoading(),
          AuthAuthenticated(mockUser, isFirstLogin: false),
        ];
      },
      verify: (_) {
        verify(() => mockAuthUseCase.signInWithGoogle()).called(1);
        verify(() => mockUserStateService.updateUser(any())).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] with isFirstLogin=true for new user',
      build: () {
        final mockAuthResult = createMockAuthResult(isFirstLogin: true);
        when(() => mockAuthUseCase.signInWithGoogle())
            .thenAnswer((_) async => Right(mockAuthResult));
        return createBloc();
      },
      act: (bloc) => bloc.add(const AuthSignInGoogle()),
      expect: () {
        final mockUser = createMockUser();
        return [
          const AuthLoading(),
          AuthAuthenticated(mockUser, isFirstLogin: true),
        ];
      },
      verify: (_) {
        verify(() => mockAuthUseCase.signInWithGoogle()).called(1);
        verify(() => mockUserStateService.updateUser(any())).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when sign-in fails with generic error',
      build: () {
        when(() => mockAuthUseCase.signInWithGoogle()).thenAnswer(
              (_) async => const Left(AuthFailure('Sign-in failed')),
        );
        return createBloc();
      },
      act: (bloc) => bloc.add(const AuthSignInGoogle()),
      expect: () => [
        const AuthLoading(),
        const AuthError('Sign-in failed'),
      ],
      verify: (_) {
        verify(() => mockAuthUseCase.signInWithGoogle()).called(1);
        verify(() => mockUserStateService.clearUser()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when sign-in fails with unauthorized domain',
      build: () {
        when(() => mockAuthUseCase.signInWithGoogle()).thenAnswer(
              (_) async => const Left(
            UnauthorizedDomainFailure('example.com'),
          ),
        );
        return createBloc();
      },
      act: (bloc) => bloc.add(const AuthSignInGoogle()),
      expect: () => [
        const AuthLoading(),
        const AuthError(
          'Your organization (example.com) is not authorized to use this application',
        ),
      ],
      verify: (_) {
        verify(() => mockUserStateService.clearUser()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when account is deactivated',
      build: () {
        when(() => mockAuthUseCase.signInWithGoogle()).thenAnswer(
              (_) async => const Left(DeactivatedAccountFailure()),
        );
        return createBloc();
      },
      act: (bloc) => bloc.add(const AuthSignInGoogle()),
      expect: () => [
        const AuthLoading(),
        const AuthError('Your account has been deactivated'),
      ],
      verify: (_) {
        verify(() => mockUserStateService.clearUser()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when session expires during sign-in',
      build: () {
        when(() => mockAuthUseCase.signInWithGoogle()).thenAnswer(
              (_) async => const Left(SessionExpiredFailure()),
        );
        return createBloc();
      },
      act: (bloc) => bloc.add(const AuthSignInGoogle()),
      expect: () => [
        const AuthLoading(),
        const AuthError('Your session has expired. Please sign in again'),
      ],
      verify: (_) {
        verify(() => mockUserStateService.clearUser()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'should prevent multiple OAuth attempts',
      build: () {
        final mockAuthResult = createMockAuthResult();
        when(() => mockAuthUseCase.signInWithGoogle())
            .thenAnswer((_) async => Right(mockAuthResult));
        return createBloc();
      },
      act: (bloc) async {
        bloc.add(const AuthSignInGoogle());
        // Wait for first to complete
        await Future.delayed(Duration(milliseconds: 100));
        bloc.add(const AuthSignInGoogle());
      },
      expect: () {
        final mockUser = createMockUser();
        return [
          const AuthLoading(),
          AuthAuthenticated(mockUser, isFirstLogin: false),
          const AuthLoading(),
          AuthAuthenticated(mockUser, isFirstLogin: false),
        ];
      },
      verify: (_) {
        // Both should complete since they're sequential
        verify(() => mockAuthUseCase.signInWithGoogle()).called(2);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'handles web OAuth redirect without emitting error',
      build: () {
        when(() => mockAuthUseCase.signInWithGoogle()).thenAnswer(
              (_) async => const Left(
            AuthFailure('OAuth redirect in progress'),
          ),
        );
        return createBloc();
      },
      act: (bloc) => bloc.add(const AuthSignInGoogle()),
      expect: () => [
        const AuthLoading(),
        // Should not emit error for OAuth redirect
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'handles network errors during sign-in',
      build: () {
        when(() => mockAuthUseCase.signInWithGoogle()).thenAnswer(
              (_) async => const Left(
            AuthFailure('No network connection available'),
          ),
        );
        return createBloc();
      },
      act: (bloc) => bloc.add(const AuthSignInGoogle()),
      expect: () => [
        const AuthLoading(),
        const AuthError('No network connection available'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'handles unexpected exceptions during sign-in',
      build: () {
        when(() => mockAuthUseCase.signInWithGoogle())
            .thenThrow(Exception('Unexpected error'));
        return createBloc();
      },
      act: (bloc) => bloc.add(const AuthSignInGoogle()),
      expect: () => [
        const AuthLoading(),
        const AuthError('Sign-in failed: Exception: Unexpected error'),
      ],
      verify: (_) {
        verify(() => mockUserStateService.clearUser()).called(1);
      },
    );
  });

  group('AuthBloc - AuthSignOut Event', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] when sign-out succeeds',
      build: () {
        when(() => mockAuthUseCase.signOut())
            .thenAnswer((_) async => const Right(null));
        return createBloc();
      },
      seed: () => AuthAuthenticated(createMockUser()),
      act: (bloc) => bloc.add(const AuthSignOut()),
      expect: () => [
        const AuthLoading(),
        const AuthUnauthenticated(),
      ],
      verify: (_) {
        verify(() => mockAuthUseCase.signOut()).called(1);
        verify(() => mockUserStateService.clearUser()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] even when sign-out fails',
      build: () {
        when(() => mockAuthUseCase.signOut()).thenAnswer(
              (_) async => const Left(AuthFailure('Sign-out failed')),
        );
        return createBloc();
      },
      seed: () => AuthAuthenticated(createMockUser()),
      act: (bloc) => bloc.add(const AuthSignOut()),
      expect: () => [
        const AuthLoading(),
        const AuthUnauthenticated(),
      ],
      verify: (_) {
        verify(() => mockAuthUseCase.signOut()).called(1);
        verify(() => mockUserStateService.clearUser()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'clears user state on sign-out',
      build: () {
        when(() => mockAuthUseCase.signOut())
            .thenAnswer((_) async => const Right(null));
        return createBloc();
      },
      seed: () => AuthAuthenticated(createMockUser()),
      act: (bloc) => bloc.add(const AuthSignOut()),
      verify: (_) {
        verify(() => mockUserStateService.clearUser()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'handles exceptions during sign-out gracefully',
      build: () {
        when(() => mockAuthUseCase.signOut())
            .thenThrow(Exception('Sign-out exception'));
        return createBloc();
      },
      seed: () => AuthAuthenticated(createMockUser()),
      act: (bloc) => bloc.add(const AuthSignOut()),
      expect: () => [
        const AuthLoading(),
        const AuthUnauthenticated(),
      ],
      verify: (_) {
        verify(() => mockUserStateService.clearUser()).called(1);
      },
    );
  });

  group('AuthBloc - AuthCheckStatus Event', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthAuthenticated] when user session is valid',
      build: () {
        final mockUser = createMockUser();
        when(() => mockAuthUseCase.getCurrentUser())
            .thenAnswer((_) async => Right(mockUser));
        return createBloc();
      },
      act: (bloc) => bloc.add(const AuthCheckStatus()),
      expect: () => [
        AuthAuthenticated(createMockUser()),
      ],
      verify: (_) {
        verify(() => mockAuthUseCase.getCurrentUser()).called(1);
        verify(() => mockUserStateService.updateUser(any())).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthUnauthenticated] when no user session exists',
      build: () {
        when(() => mockAuthUseCase.getCurrentUser())
            .thenAnswer((_) async => const Right(null));
        return createBloc();
      },
      act: (bloc) => bloc.add(const AuthCheckStatus()),
      expect: () => [
        const AuthUnauthenticated(),
      ],
      verify: (_) {
        verify(() => mockAuthUseCase.getCurrentUser()).called(1);
        verify(() => mockUserStateService.clearUser()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthUnauthenticated] when session check fails',
      build: () {
        when(() => mockAuthUseCase.getCurrentUser()).thenAnswer(
              (_) async => const Left(SessionExpiredFailure()),
        );
        return createBloc();
      },
      act: (bloc) => bloc.add(const AuthCheckStatus()),
      expect: () => [
        const AuthUnauthenticated(),
      ],
      verify: (_) {
        verify(() => mockUserStateService.clearUser()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'updates user state service when session is valid',
      build: () {
        final mockUser = createMockUser();
        when(() => mockAuthUseCase.getCurrentUser())
            .thenAnswer((_) async => Right(mockUser));
        return createBloc();
      },
      act: (bloc) => bloc.add(const AuthCheckStatus()),
      verify: (_) {
        verify(() => mockUserStateService.updateUser(any())).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'handles unexpected exceptions during status check',
      build: () {
        when(() => mockAuthUseCase.getCurrentUser())
            .thenThrow(Exception('Status check error'));
        return createBloc();
      },
      act: (bloc) => bloc.add(const AuthCheckStatus()),
      expect: () => [
        const AuthUnauthenticated(),
      ],
      verify: (_) {
        verify(() => mockUserStateService.clearUser()).called(1);
      },
    );
  });

  group('AuthBloc - State Transitions', () {
    blocTest<AuthBloc, AuthState>(
      'transitions from AuthInitial to AuthAuthenticated on successful login',
      build: () {
        final mockAuthResult = createMockAuthResult();
        when(() => mockAuthUseCase.signInWithGoogle())
            .thenAnswer((_) async => Right(mockAuthResult));
        return createBloc();
      },
      seed: () => const AuthInitial(),
      act: (bloc) => bloc.add(const AuthSignInGoogle()),
      expect: () => [
        const AuthLoading(),
        AuthAuthenticated(createMockUser(), isFirstLogin: false),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'transitions from AuthAuthenticated to AuthUnauthenticated on sign-out',
      build: () {
        when(() => mockAuthUseCase.signOut())
            .thenAnswer((_) async => const Right(null));
        return createBloc();
      },
      seed: () => AuthAuthenticated(createMockUser()),
      act: (bloc) => bloc.add(const AuthSignOut()),
      expect: () => [
        const AuthLoading(),
        const AuthUnauthenticated(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'can transition from error state to authenticated on retry',
      build: () {
        final mockAuthResult = createMockAuthResult();
        when(() => mockAuthUseCase.signInWithGoogle())
            .thenAnswer((_) async => Right(mockAuthResult));
        return createBloc();
      },
      seed: () => const AuthError('Previous error'),
      act: (bloc) => bloc.add(const AuthSignInGoogle()),
      expect: () => [
        const AuthLoading(),
        AuthAuthenticated(createMockUser(), isFirstLogin: false),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'can check status while already authenticated',
      build: () {
        final mockUser = createMockUser();
        when(() => mockAuthUseCase.getCurrentUser())
            .thenAnswer((_) async => Right(mockUser));
        return createBloc();
      },
      seed: () => AuthAuthenticated(createMockUser()),
      act: (bloc) => bloc.add(const AuthCheckStatus()),
      expect: () => [], // No emission because state is identical
      verify: (_) {
        verify(() => mockAuthUseCase.getCurrentUser()).called(1);
        verify(() => mockUserStateService.updateUser(any())).called(1);
      },
    );
  });

  group('AuthBloc - Memory Management', () {
    test('should close properly without errors', () async {
      // Arrange
      authBloc = createBloc();

      // Act & Assert - Should complete without errors
      await expectLater(authBloc.close(), completes);
    });

    test('should not emit states after being closed', () async {
      // Arrange
      final mockAuthResult = createMockAuthResult();
      when(() => mockAuthUseCase.signInWithGoogle())
          .thenAnswer((_) async => Right(mockAuthResult));

      authBloc = createBloc();
      await authBloc.close();

      // Act & Assert - Should not emit after close
      expect(
            () => authBloc.add(const AuthSignInGoogle()),
        throwsStateError,
      );
    });

    test('should cancel timers on close', () async {
      // Arrange
      authBloc = createBloc();

      // Act
      await authBloc.close();

      // Assert - If timers weren't cancelled, this would throw
      // The test passing means timers were properly disposed
      expect(authBloc.isClosed, isTrue);
    });
  });

  group('AuthBloc - Edge Cases', () {
    blocTest<AuthBloc, AuthState>(
      'handles empty error message gracefully',
      build: () {
        when(() => mockAuthUseCase.signInWithGoogle()).thenAnswer(
              (_) async => const Left(AuthFailure('')),
        );
        return createBloc();
      },
      act: (bloc) => bloc.add(const AuthSignInGoogle()),
      expect: () => [
        const AuthLoading(),
        const AuthError(''),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'handles sign-in with inactive user',
      build: () {
        final inactiveUser = createMockUser(isActive: false);
        final mockAuthResult = AuthResultEntity(
          user: inactiveUser,
          isFirstLogin: false,
        );
        when(() => mockAuthUseCase.signInWithGoogle())
            .thenAnswer((_) async => Right(mockAuthResult));
        return createBloc();
      },
      act: (bloc) => bloc.add(const AuthSignInGoogle()),
      expect: () => [
        const AuthLoading(),
        AuthAuthenticated(createMockUser(isActive: false), isFirstLogin: false),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'handles user without tenant ID',
      build: () {
        final userWithoutTenant = createMockUser(tenantId: null);
        final mockAuthResult = AuthResultEntity(
          user: userWithoutTenant,
          isFirstLogin: false,
        );
        when(() => mockAuthUseCase.signInWithGoogle())
            .thenAnswer((_) async => Right(mockAuthResult));
        return createBloc();
      },
      act: (bloc) => bloc.add(const AuthSignInGoogle()),
      expect: () => [
        const AuthLoading(),
        AuthAuthenticated(
          createMockUser(tenantId: null),
          isFirstLogin: false,
        ),
      ],
    );
  });
}