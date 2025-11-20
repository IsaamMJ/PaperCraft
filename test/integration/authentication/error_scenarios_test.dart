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
// ERROR SIMULATION & RECOVERY TESTS
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

  group('Error Simulation - OAuth Failures', () {
    test('OAuth provider not responding error', () async {
      // Arrange
      when(() => mockAuthUseCase.signInWithGoogle())
          .thenAnswer((_) async => const Left(
            AuthFailure('OAuth provider not responding. Please try again.'),
          ));

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
      expect((authBloc.state as AuthError).message, contains('OAuth'));
    });

    test('OAuth scope denied error', () async {
      // Arrange
      when(() => mockAuthUseCase.signInWithGoogle())
          .thenAnswer((_) async => const Left(
            AuthFailure('User denied required permissions'),
          ));

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

    test('OAuth cancelled by user', () async {
      // Arrange
      when(() => mockAuthUseCase.signInWithGoogle())
          .thenAnswer((_) async => const Left(
            AuthFailure('Authentication was cancelled or failed'),
          ));

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

  group('Error Simulation - Account Issues', () {
    test('Account disabled/suspended error', () async {
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

    test('Unauthorized domain/email error', () async {
      // Arrange
      when(() => mockAuthUseCase.signInWithGoogle())
          .thenAnswer((_) async => const Left(UnauthorizedDomainFailure('example.com')));

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

    test('User not found after OAuth success', () async {
      // Arrange - OAuth succeeds but user profile missing
      when(() => mockAuthUseCase.signInWithGoogle())
          .thenAnswer((_) async => const Left(
            AuthFailure('Profile creation failed - please contact administrator'),
          ));

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

  group('Error Simulation - Server/API Errors', () {
    test('Server 500 error handling', () async {
      // Arrange
      when(() => mockAuthUseCase.signInWithGoogle())
          .thenAnswer((_) async => const Left(
            AuthFailure('Server error. Please try again later.'),
          ));

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

    test('Database connection error', () async {
      // Arrange
      when(() => mockAuthUseCase.signInWithGoogle())
          .thenAnswer((_) async => const Left(
            AuthFailure('Database error. Please try again.'),
          ));

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

  group('Error Recovery - Retry Mechanisms', () {
    test('User can retry after transient error', () async {
      // Arrange - First attempt fails transiently
      when(() => mockAuthUseCase.signInWithGoogle())
          .thenAnswer((_) async => const Left(
            AuthFailure('Network timeout'),
          ));

      authBloc = AuthBloc(
        mockAuthUseCase,
        mockUserStateService,
        authStateController.stream,
        mockClock,
        autoInitialize: false,
      );

      // Act - First attempt
      authBloc.add(const AuthSignInGoogle());
      await Future.delayed(const Duration(milliseconds: 200));
      expect(authBloc.state, isA<AuthError>());

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
          .thenAnswer((_) async => Right(AuthResultEntity(user: mockUser, isFirstLogin: false)));

      // Act - Retry
      authBloc.add(const AuthSignInGoogle());
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert - Should succeed
      expect(authBloc.state, isA<AuthAuthenticated>());
    });

    test('Error state provides actionable feedback', () async {
      // Arrange
      when(() => mockAuthUseCase.signInWithGoogle())
          .thenAnswer((_) async => const Left(
            AuthFailure('Check your internet connection and try again'),
          ));

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
      final errorState = authBloc.state as AuthError;
      expect(errorState.message, isNotEmpty);
      expect(errorState.message.toLowerCase(), contains('internet'));
    });
  });

  group('Error Recovery - State Cleanup', () {
    test('Error state clears user data on auth failure', () async {
      // Arrange
      when(() => mockAuthUseCase.signInWithGoogle())
          .thenAnswer((_) async => const Left(AuthFailure('Auth failed')));

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

    test('Sign out on account deactivation clears state', () async {
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

      // Assert - User state cleared
      verify(() => mockUserStateService.clearUser()).called(1);
    });
  });

  group('Error Simulation - Edge Cases', () {
    test('Malformed error response handled gracefully', () async {
      // Arrange
      when(() => mockAuthUseCase.signInWithGoogle())
          .thenThrow(Exception('Unexpected error format'));

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

    test('Empty error message handled', () async {
      // Arrange
      when(() => mockAuthUseCase.signInWithGoogle())
          .thenAnswer((_) async => const Left(AuthFailure('')));

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
      // Should still be in error state even with empty message
    });

    test('Multiple errors in sequence handled correctly', () async {
      // Arrange - First error
      when(() => mockAuthUseCase.signInWithGoogle())
          .thenAnswer((_) async => const Left(
            AuthFailure('Error 1'),
          ));

      authBloc = AuthBloc(
        mockAuthUseCase,
        mockUserStateService,
        authStateController.stream,
        mockClock,
        autoInitialize: false,
      );

      // Act - First attempt
      authBloc.add(const AuthSignInGoogle());
      await Future.delayed(const Duration(milliseconds: 100));
      expect(authBloc.state, isA<AuthError>());

      // Arrange - Different error
      when(() => mockAuthUseCase.signInWithGoogle())
          .thenAnswer((_) async => const Left(
            AuthFailure('Error 2'),
          ));

      // Act - Second attempt
      authBloc.add(const AuthSignInGoogle());
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert - Should show latest error
      expect(authBloc.state, isA<AuthError>());
      expect((authBloc.state as AuthError).message, contains('Error 2'));
    });
  });
}
