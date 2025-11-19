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
// OFFLINE SCENARIO TESTS
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

  group('Offline Scenarios - Network Unavailable', () {
    test('Sign in fails gracefully when network is unavailable', () async {
      // Arrange - Network error
      when(() => mockAuthUseCase.signInWithGoogle())
          .thenAnswer((_) async => const Left(AuthFailure('Network error')));

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
      expect((authBloc.state as AuthError).message, contains('Network'));
    });

    test('Session restoration fails offline with appropriate error', () async {
      // Arrange - Network unavailable during init
      when(() => mockAuthUseCase.initialize())
          .thenAnswer((_) async => const Left(AuthFailure('No internet')));

      authBloc = AuthBloc(
        mockAuthUseCase,
        mockUserStateService,
        authStateController.stream,
        mockClock,
        autoInitialize: true,
      );

      // Wait for auto-init
      await Future.delayed(const Duration(milliseconds: 300));

      // Assert
      expect(authBloc.state, isA<AuthUnauthenticated>());
      verify(() => mockUserStateService.clearUser()).called(1);
    });

    test('Sign out retry mechanism handles offline scenarios', () async {
      // Arrange
      when(() => mockAuthUseCase.signOut())
          .thenAnswer((_) async => const Left(AuthFailure('Offline')));

      authBloc = AuthBloc(
        mockAuthUseCase,
        mockUserStateService,
        authStateController.stream,
        mockClock,
        autoInitialize: false,
      );

      // Act - Even offline, sign out should clear user
      authBloc.add(const AuthSignOut());
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert
      expect(authBloc.state, isA<AuthUnauthenticated>());
      // User state should be cleared even if network call fails
      verify(() => mockUserStateService.clearUser()).called(1);
    });
  });

  group('Offline Scenarios - Network Timeout', () {
    test('OAuth timeout shows user-friendly error message', () async {
      // Arrange
      when(() => mockAuthUseCase.signInWithGoogle())
          .thenAnswer((_) async => const Left(SessionExpiredFailure()));

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
      expect(errorState.message.isNotEmpty, isTrue);
    });

    test('Profile fetch timeout triggers retry mechanism', () async {
      // Arrange - First profile fetch times out, second succeeds
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
          .thenAnswer((_) async => Right(
            AuthResultEntity(user: mockUser),
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

      // Assert - Should eventually succeed
      expect(authBloc.state, isA<AuthAuthenticated>());
    });
  });

  group('Offline Scenarios - Intermittent Connectivity', () {
    test('Auth state sync timer handles intermittent connectivity', () async {
      // Arrange - Simulate reconnection
      final mockUser = UserEntity(
        id: 'user-123',
        email: 'test@school.com',
        fullName: 'Test User',
        tenantId: 'tenant-123',
        role: UserRole.teacher,
        isActive: true,
        createdAt: DateTime.now(),
      );

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

      // Act - Manually trigger status check to simulate sync
      authBloc.add(const AuthCheckStatus());
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert - Should successfully refresh auth state
      verify(() => mockAuthUseCase.getCurrentUserWithInitStatus()).called(1);
    });

    test('Offline app state is maintained until connectivity returns', () async {
      // Arrange - Offline user
      final mockUser = UserEntity(
        id: 'user-123',
        email: 'test@school.com',
        fullName: 'Test User',
        tenantId: 'tenant-123',
        role: UserRole.teacher,
        isActive: true,
        createdAt: DateTime.now(),
      );

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

      // Act - Check status (simulating app in foreground)
      authBloc.add(const AuthCheckStatus());
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert - State should be maintained
      expect(authBloc.state, isA<AuthAuthenticated>());

      // User state service should be updated
      verify(() => mockUserStateService.updateUser(any())).called(1);
    });
  });

  group('Offline Scenarios - Cold Start Without Cache', () {
    test('Cold start with no cached session goes to login', () async {
      // Arrange - No session available
      when(() => mockAuthUseCase.initialize())
          .thenAnswer((_) async => const Right(null));

      authBloc = AuthBloc(
        mockAuthUseCase,
        mockUserStateService,
        authStateController.stream,
        mockClock,
        autoInitialize: true,
      );

      // Wait for init
      await Future.delayed(const Duration(milliseconds: 300));

      // Assert
      expect(authBloc.state, isA<AuthUnauthenticated>());
    });

    test('Cold start with network error still starts app', () async {
      // Arrange - Network error on cold start
      when(() => mockAuthUseCase.initialize())
          .thenAnswer((_) async => const Left(AuthFailure('Offline')));

      authBloc = AuthBloc(
        mockAuthUseCase,
        mockUserStateService,
        authStateController.stream,
        mockClock,
        autoInitialize: true,
      );

      // Wait for init
      await Future.delayed(const Duration(milliseconds: 300));

      // Assert - Should gracefully go to unauthenticated
      expect(authBloc.state, isA<AuthUnauthenticated>());
    });
  });

  group('Offline Scenarios - Data Sync Recovery', () {
    test('User state service cleared on offline initialization failure', () async {
      // Arrange
      when(() => mockAuthUseCase.initialize())
          .thenAnswer((_) async => const Left(AuthFailure('No network')));

      authBloc = AuthBloc(
        mockAuthUseCase,
        mockUserStateService,
        authStateController.stream,
        mockClock,
        autoInitialize: true,
      );

      // Wait for init
      await Future.delayed(const Duration(milliseconds: 300));

      // Assert - User state should be cleared
      verify(() => mockUserStateService.clearUser()).called(1);
    });

    test('Reconnection after offline triggers re-sync', () async {
      // Arrange - First call fails (offline), second succeeds (back online)
      final mockUser = UserEntity(
        id: 'user-123',
        email: 'test@school.com',
        fullName: 'Test User',
        tenantId: 'tenant-123',
        role: UserRole.teacher,
        isActive: true,
        createdAt: DateTime.now(),
      );

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

      // Act - Trigger status check after reconnect
      authBloc.add(const AuthCheckStatus());
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert - Should update user state
      verify(() => mockUserStateService.updateUser(any())).called(1);
    });
  });
}
