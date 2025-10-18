import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:papercraft/core/domain/interfaces/i_logger.dart';
import 'package:papercraft/features/authentication/domain/entities/auth_result_entity.dart';
import 'package:papercraft/features/authentication/domain/entities/user_entity.dart';
import 'package:papercraft/features/authentication/domain/entities/user_role.dart';
import 'package:papercraft/features/authentication/domain/failures/auth_failures.dart';
import 'package:papercraft/features/authentication/domain/repositories/auth_repository.dart';
import 'package:papercraft/features/authentication/domain/usecases/auth_usecase.dart';

// ============================================================================
// MOCKS
// ============================================================================

class MockAuthRepository extends Mock implements AuthRepository {}
class MockLogger extends Mock implements ILogger {}

// ============================================================================
// TEST HELPERS
// ============================================================================

UserEntity createMockUser({
  String id = 'user-123',
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
  late AuthUseCase authUseCase;
  late MockAuthRepository mockRepository;
  late MockLogger mockLogger;

  setUp(() {
    mockRepository = MockAuthRepository();
    mockLogger = MockLogger();
    authUseCase = AuthUseCase(mockRepository, mockLogger);

    // Default logger behavior
    when(() => mockLogger.debug(any(), category: any(named: 'category'), context: any(named: 'context')))
        .thenReturn(null);
    when(() => mockLogger.warning(any(), category: any(named: 'category'), context: any(named: 'context')))
        .thenReturn(null);
    when(() => mockLogger.error(any(), category: any(named: 'category'), error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'), context: any(named: 'context')))
        .thenReturn(null);
  });

  group('AuthUseCase - initialize', () {
    test('calls repository initialize method', () async {
      // Arrange
      final mockUser = createMockUser();
      when(() => mockRepository.initialize())
          .thenAnswer((_) async => Right(mockUser));

      // Act
      await authUseCase.initialize();

      // Assert
      verify(() => mockRepository.initialize()).called(1);
    });

    test('returns Right with user when initialization succeeds', () async {
      // Arrange
      final mockUser = createMockUser();
      when(() => mockRepository.initialize())
          .thenAnswer((_) async => Right(mockUser));

      // Act
      final result = await authUseCase.initialize();

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not return failure'),
            (user) {
          expect(user, mockUser);
          expect(user?.id, mockUser.id);
        },
      );
    });

    test('returns Right with null when no user exists', () async {
      // Arrange
      when(() => mockRepository.initialize())
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await authUseCase.initialize();

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not return failure'),
            (user) => expect(user, isNull),
      );
    });

    test('returns Left with failure when initialization fails', () async {
      // Arrange
      const failure = SessionExpiredFailure();
      when(() => mockRepository.initialize())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await authUseCase.initialize();

      // Assert
      expect(result.isLeft(), true);
      result.fold(
            (failure) => expect(failure, isA<SessionExpiredFailure>()),
            (user) => fail('Should not return user'),
      );
    });
  });

  group('AuthUseCase - signInWithGoogle', () {
    test('calls repository signInWithGoogle method', () async {
      // Arrange
      final mockAuthResult = createMockAuthResult();
      when(() => mockRepository.signInWithGoogle())
          .thenAnswer((_) async => Right(mockAuthResult));

      // Act
      await authUseCase.signInWithGoogle();

      // Assert
      verify(() => mockRepository.signInWithGoogle()).called(1);
    });

    test('returns Right with AuthResult when sign-in succeeds', () async {
      // Arrange
      final mockAuthResult = createMockAuthResult(isFirstLogin: false);
      when(() => mockRepository.signInWithGoogle())
          .thenAnswer((_) async => Right(mockAuthResult));

      // Act
      final result = await authUseCase.signInWithGoogle();

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not return failure'),
            (authResult) {
          expect(authResult.user, mockAuthResult.user);
          expect(authResult.isFirstLogin, false);
        },
      );
    });

    test('returns AuthResult with isFirstLogin=true for new users', () async {
      // Arrange
      final mockAuthResult = createMockAuthResult(isFirstLogin: true);
      when(() => mockRepository.signInWithGoogle())
          .thenAnswer((_) async => Right(mockAuthResult));

      // Act
      final result = await authUseCase.signInWithGoogle();

      // Assert
      result.fold(
            (failure) => fail('Should not return failure'),
            (authResult) => expect(authResult.isFirstLogin, true),
      );
    });

    test('returns Left with AuthFailure when sign-in fails', () async {
      // Arrange
      const failure = AuthFailure('Sign-in failed');
      when(() => mockRepository.signInWithGoogle())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await authUseCase.signInWithGoogle();

      // Assert
      expect(result.isLeft(), true);
      result.fold(
            (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, 'Sign-in failed');
        },
            (authResult) => fail('Should not return auth result'),
      );
    });

    test('returns Left with UnauthorizedDomainFailure for unauthorized domain', () async {
      // Arrange
      const failure = UnauthorizedDomainFailure('unauthorized.com');
      when(() => mockRepository.signInWithGoogle())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await authUseCase.signInWithGoogle();

      // Assert
      result.fold(
            (failure) => expect(failure, isA<UnauthorizedDomainFailure>()),
            (authResult) => fail('Should not return auth result'),
      );
    });

    test('returns Left with DeactivatedAccountFailure for deactivated account', () async {
      // Arrange
      const failure = DeactivatedAccountFailure();
      when(() => mockRepository.signInWithGoogle())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await authUseCase.signInWithGoogle();

      // Assert
      result.fold(
            (failure) => expect(failure, isA<DeactivatedAccountFailure>()),
            (authResult) => fail('Should not return auth result'),
      );
    });
  });

  group('AuthUseCase - getCurrentUser', () {
    test('calls repository getCurrentUser method', () async {
      // Arrange
      final mockUser = createMockUser();
      when(() => mockRepository.getCurrentUser())
          .thenAnswer((_) async => Right(mockUser));

      // Act
      await authUseCase.getCurrentUser();

      // Assert
      verify(() => mockRepository.getCurrentUser()).called(1);
    });

    test('returns Right with user when user exists', () async {
      // Arrange
      final mockUser = createMockUser();
      when(() => mockRepository.getCurrentUser())
          .thenAnswer((_) async => Right(mockUser));

      // Act
      final result = await authUseCase.getCurrentUser();

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not return failure'),
            (user) {
          expect(user, mockUser);
          expect(user?.id, mockUser.id);
        },
      );
    });

    test('returns Right with null when no user exists', () async {
      // Arrange
      when(() => mockRepository.getCurrentUser())
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await authUseCase.getCurrentUser();

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not return failure'),
            (user) => expect(user, isNull),
      );
    });

    test('returns Left with failure when getCurrentUser fails', () async {
      // Arrange
      const failure = SessionExpiredFailure();
      when(() => mockRepository.getCurrentUser())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await authUseCase.getCurrentUser();

      // Assert
      expect(result.isLeft(), true);
      result.fold(
            (failure) => expect(failure, isA<SessionExpiredFailure>()),
            (user) => fail('Should not return user'),
      );
    });
  });

  group('AuthUseCase - signOut', () {
    test('calls repository signOut method', () async {
      // Arrange
      when(() => mockRepository.signOut())
          .thenAnswer((_) async => const Right(null));

      // Act
      await authUseCase.signOut();

      // Assert
      verify(() => mockRepository.signOut()).called(1);
    });

    test('returns Right when sign-out succeeds', () async {
      // Arrange
      when(() => mockRepository.signOut())
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await authUseCase.signOut();

      // Assert
      expect(result.isRight(), true);
    });

    test('returns Left with failure when sign-out fails', () async {
      // Arrange
      const failure = AuthFailure('Sign-out failed');
      when(() => mockRepository.signOut())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await authUseCase.signOut();

      // Assert
      expect(result.isLeft(), true);
      result.fold(
            (failure) => expect(failure.message, 'Sign-out failed'),
            (_) => fail('Should not return success'),
      );
    });
  });

  group('AuthUseCase - getUserById', () {
    const testUserId = 'user-456';

    test('calls repository getUserById with correct userId', () async {
      // Arrange
      final mockUser = createMockUser(id: testUserId);
      when(() => mockRepository.getUserById(any()))
          .thenAnswer((_) async => Right(mockUser));

      // Act
      await authUseCase.getUserById(testUserId);

      // Assert
      verify(() => mockRepository.getUserById(testUserId)).called(1);
    });

    test('logs debug message when fetching user', () async {
      // Arrange
      final mockUser = createMockUser(id: testUserId);
      when(() => mockRepository.getUserById(any()))
          .thenAnswer((_) async => Right(mockUser));

      // Act
      await authUseCase.getUserById(testUserId);

      // Assert
      verify(() => mockLogger.debug(
        'Fetching user by ID',
        category: LogCategory.auth,
        context: {
          'targetUserId': testUserId,
          'operation': 'get_user_by_id',
        },
      )).called(1);
    });

    test('returns Right with user when user is found', () async {
      // Arrange
      final mockUser = createMockUser(id: testUserId);
      when(() => mockRepository.getUserById(testUserId))
          .thenAnswer((_) async => Right(mockUser));

      // Act
      final result = await authUseCase.getUserById(testUserId);

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not return failure'),
            (user) {
          expect(user, mockUser);
          expect(user?.id, testUserId);
        },
      );
    });

    test('logs success when user is found', () async {
      // Arrange
      final mockUser = createMockUser(id: testUserId, fullName: 'John Doe', role: UserRole.admin);
      when(() => mockRepository.getUserById(testUserId))
          .thenAnswer((_) async => Right(mockUser));

      // Act
      await authUseCase.getUserById(testUserId);

      // Assert
      verify(() => mockLogger.debug(
        'User found by ID',
        category: LogCategory.auth,
        context: {
          'targetUserId': testUserId,
          'userFullName': 'John Doe',
          'userRole': 'admin',
        },
      )).called(1);
    });

    test('returns Right with null when user not found', () async {
      // Arrange
      when(() => mockRepository.getUserById(testUserId))
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await authUseCase.getUserById(testUserId);

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not return failure'),
            (user) => expect(user, isNull),
      );
    });

    test('logs debug message when user not found', () async {
      // Arrange
      when(() => mockRepository.getUserById(testUserId))
          .thenAnswer((_) async => const Right(null));

      // Act
      await authUseCase.getUserById(testUserId);

      // Assert
      verify(() => mockLogger.debug(
        'User not found by ID',
        category: LogCategory.auth,
        context: {'targetUserId': testUserId},
      )).called(1);
    });

    test('returns Left with failure when repository fails', () async {
      // Arrange
      const failure = AuthFailure('User fetch failed');
      when(() => mockRepository.getUserById(testUserId))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await authUseCase.getUserById(testUserId);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
            (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, 'User fetch failed');
        },
            (user) => fail('Should not return user'),
      );
    });

    test('logs warning when fetching user fails', () async {
      // Arrange
      const failure = AuthFailure('Database error');
      when(() => mockRepository.getUserById(testUserId))
          .thenAnswer((_) async => const Left(failure));

      // Act
      await authUseCase.getUserById(testUserId);

      // Assert
      verify(() => mockLogger.warning(
        'Failed to fetch user by ID',
        category: LogCategory.auth,
        context: {
          'targetUserId': testUserId,
          'error': 'Database error',
        },
      )).called(1);
    });

    test('handles exceptions and returns Left with AuthFailure', () async {
      // Arrange
      when(() => mockRepository.getUserById(testUserId))
          .thenThrow(Exception('Unexpected error'));

      // Act
      final result = await authUseCase.getUserById(testUserId);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
            (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, contains('Failed to get user by ID'));
          expect(failure.message, contains('Exception: Unexpected error'));
        },
            (user) => fail('Should not return user'),
      );
    });

    test('logs error when exception occurs', () async {
      // Arrange
      final exception = Exception('Network timeout');
      when(() => mockRepository.getUserById(testUserId))
          .thenThrow(exception);

      // Act
      await authUseCase.getUserById(testUserId);

      // Assert
      verify(() => mockLogger.error(
        'Exception in getUserById',
        category: LogCategory.auth,
        error: exception,
        stackTrace: any(named: 'stackTrace'),
        context: {'targetUserId': testUserId},
      )).called(1);
    });
  });

  group('AuthUseCase - isAuthenticated getter', () {
    test('returns true when repository isAuthenticated is true', () {
      // Arrange
      when(() => mockRepository.isAuthenticated).thenReturn(true);

      // Act
      final result = authUseCase.isAuthenticated;

      // Assert
      expect(result, true);
      verify(() => mockRepository.isAuthenticated).called(1);
    });

    test('returns false when repository isAuthenticated is false', () {
      // Arrange
      when(() => mockRepository.isAuthenticated).thenReturn(false);

      // Act
      final result = authUseCase.isAuthenticated;

      // Assert
      expect(result, false);
      verify(() => mockRepository.isAuthenticated).called(1);
    });
  });

  group('AuthUseCase - Integration scenarios', () {
    test('complete sign-in flow with logging', () async {
      // Arrange
      final mockAuthResult = createMockAuthResult(
        user: createMockUser(id: 'new-user', fullName: 'New User'),
        isFirstLogin: true,
      );
      when(() => mockRepository.signInWithGoogle())
          .thenAnswer((_) async => Right(mockAuthResult));

      // Act
      final result = await authUseCase.signInWithGoogle();

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not fail'),
            (authResult) {
          expect(authResult.isFirstLogin, true);
          expect(authResult.user.id, 'new-user');
        },
      );
      verify(() => mockRepository.signInWithGoogle()).called(1);
    });

    test('getUserById after successful authentication', () async {
      // Arrange
      final user1 = createMockUser(id: 'user-1');
      final user2 = createMockUser(id: 'user-2');

      when(() => mockRepository.getCurrentUser())
          .thenAnswer((_) async => Right(user1));
      when(() => mockRepository.getUserById('user-2'))
          .thenAnswer((_) async => Right(user2));

      // Act
      final currentUserResult = await authUseCase.getCurrentUser();
      final otherUserResult = await authUseCase.getUserById('user-2');

      // Assert
      expect(currentUserResult.isRight(), true);
      expect(otherUserResult.isRight(), true);

      currentUserResult.fold(
            (_) => fail('Should not fail'),
            (user) => expect(user?.id, 'user-1'),
      );

      otherUserResult.fold(
            (_) => fail('Should not fail'),
            (user) => expect(user?.id, 'user-2'),
      );
    });
  });
}