import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:papercraft/core/domain/interfaces/i_logger.dart';
import 'package:papercraft/features/authentication/data/datasources/auth_data_source.dart';
import 'package:papercraft/features/authentication/data/models/user_model.dart';
import 'package:papercraft/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:papercraft/features/authentication/domain/entities/user_entity.dart';
import 'package:papercraft/features/authentication/domain/entities/user_role.dart';
import 'package:papercraft/features/authentication/domain/failures/auth_failures.dart';



// ============================================================================
// MOCKS
// ============================================================================

class MockAuthDataSource extends Mock implements AuthDataSource {}
class MockLogger extends Mock implements ILogger {}



// ============================================================================
// TEST HELPERS
// ============================================================================

UserModel createMockUserModel({
  String id = 'user-123',
  String email = 'test@example.com',
  String fullName = 'Test User',
  String? tenantId = 'tenant-123',
  String role = 'teacher',
  bool isActive = true,
  DateTime? lastLoginAt,
  DateTime? createdAt,
}) {
  return UserModel(
    id: id,
    email: email,
    fullName: fullName,
    tenantId: tenantId,
    role: role,
    isActive: isActive,
    lastLoginAt: lastLoginAt,
    createdAt: createdAt ?? DateTime.now(),
  );
}

// ============================================================================
// MAIN TEST SUITE
// ============================================================================

void main() {
  late AuthRepositoryImpl repository;
  late MockAuthDataSource mockDataSource;
  late MockLogger mockLogger;
  setUpAll(() {
    registerFallbackValue(LogCategory.auth);
  });

  setUp(() {
    mockDataSource = MockAuthDataSource();
    mockLogger = MockLogger();

    // Setup mocks BEFORE creating repository (constructor logs immediately)
    when(() => mockLogger.info(any(), category: any(named: 'category'), context: any(named: 'context')))
        .thenReturn(null);
    when(() => mockLogger.debug(any(), category: any(named: 'category'), context: any(named: 'context')))
        .thenReturn(null);
    when(() => mockLogger.authEvent(any(), any(), context: any(named: 'context')))
        .thenReturn(null);
    when(() => mockLogger.authError(any(), any(), context: any(named: 'context')))
        .thenReturn(null);
    when(() => mockLogger.error(any(), category: any(named: 'category'), error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'), context: any(named: 'context')))
        .thenReturn(null);

    // NOW create repository (after mocks are set up)
    repository = AuthRepositoryImpl(mockDataSource, mockLogger);
  });

  group('AuthRepositoryImpl - Construction', () {
    test('logs initialization message on construction', () {
      // Assert
      verify(() => mockLogger.info(
        'AuthRepository initialized',
        category: LogCategory.auth,
        context: any(named: 'context'),
      )).called(1);
    });
  });

  group('AuthRepositoryImpl - initialize', () {
    test('calls data source initialize method', () async {
      // Arrange
      when(() => mockDataSource.initialize())
          .thenAnswer((_) async => const Right(null));

      // Act
      await repository.initialize();

      // Assert
      verify(() => mockDataSource.initialize()).called(1);
    });

    test('returns Right with UserEntity when user model is returned', () async {
      // Arrange
      final userModel = createMockUserModel();
      when(() => mockDataSource.initialize())
          .thenAnswer((_) async => Right(userModel));

      // Act
      final result = await repository.initialize();

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not return failure'),
            (user) {
          expect(user, isA<UserEntity>());
          expect(user?.id, userModel.id);
          expect(user?.email, userModel.email);
          expect(user?.role, UserRole.fromString(userModel.role));
        },
      );
    });

    test('logs success event when user is found', () async {
      // Arrange
      final userModel = createMockUserModel(
        id: 'user-123',
        fullName: 'John Doe',
        role: 'admin',
        tenantId: 'tenant-456',
      );
      when(() => mockDataSource.initialize())
          .thenAnswer((_) async => Right(userModel));

      // Act
      await repository.initialize();

      // Assert
      verify(() => mockLogger.authEvent(
        'app_initialization_success',
        'user-123',
        context: any(named: 'context'),
      )).called(1);
    });

    test('returns Right with null when no user exists', () async {
      // Arrange
      when(() => mockDataSource.initialize())
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await repository.initialize();

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not return failure'),
            (user) => expect(user, isNull),
      );
    });

    test('logs no user event when session does not exist', () async {
      // Arrange
      when(() => mockDataSource.initialize())
          .thenAnswer((_) async => const Right(null));

      // Act
      await repository.initialize();

      // Assert
      verify(() => mockLogger.authEvent(
        'app_initialization_no_user',
        'system',
        context: any(named: 'context'),
      )).called(1);
    });

    test('returns Left with failure when data source fails', () async {
      // Arrange
      const failure = SessionExpiredFailure();
      when(() => mockDataSource.initialize())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await repository.initialize();

      // Assert
      expect(result.isLeft(), true);
      result.fold(
            (failure) => expect(failure, isA<SessionExpiredFailure>()),
            (user) => fail('Should not return user'),
      );
    });

    test('logs error when initialization fails', () async {
      // Arrange
      const failure = AuthFailure('Init failed');
      when(() => mockDataSource.initialize())
          .thenAnswer((_) async => const Left(failure));

      // Act
      await repository.initialize();

      // Assert
      verify(() => mockLogger.authError(
        'App initialization failed',
        failure,
        context: any(named: 'context'),
      )).called(1);
    });
  });

  group('AuthRepositoryImpl - signInWithGoogle', () {
    test('calls data source signInWithGoogle method', () async {
      // Arrange
      final userModel = createMockUserModel();
      when(() => mockDataSource.signInWithGoogle())
          .thenAnswer((_) async => Right(userModel));

      // Act
      await repository.signInWithGoogle();

      // Assert
      verify(() => mockDataSource.signInWithGoogle()).called(1);
    });

    test('returns AuthResultEntity with isFirstLogin=true for new users', () async {
      // Arrange
      final now = DateTime.now();
      final userModel = createMockUserModel(
        createdAt: now,
        lastLoginAt: null, // New user - no previous login
      );
      when(() => mockDataSource.signInWithGoogle())
          .thenAnswer((_) async => Right(userModel));

      // Act
      final result = await repository.signInWithGoogle();

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not return failure'),
            (authResult) {
          expect(authResult.user.id, userModel.id);
          expect(authResult.isFirstLogin, true);
        },
      );
    });

    test('returns AuthResultEntity with isFirstLogin=true when created within 5 minutes', () async {
      // Arrange
      final now = DateTime.now();
      final userModel = createMockUserModel(
        createdAt: now.subtract(const Duration(minutes: 3)),
        lastLoginAt: now.subtract(const Duration(minutes: 2)),
      );
      when(() => mockDataSource.signInWithGoogle())
          .thenAnswer((_) async => Right(userModel));

      // Act
      final result = await repository.signInWithGoogle();

      // Assert
      result.fold(
            (failure) => fail('Should not return failure'),
            (authResult) => expect(authResult.isFirstLogin, true),
      );
    });

    test('returns AuthResultEntity with isFirstLogin=false for existing users', () async {
      // Arrange
      final now = DateTime.now();
      final userModel = createMockUserModel(
        createdAt: now.subtract(const Duration(days: 30)),
        lastLoginAt: now.subtract(const Duration(hours: 1)),
      );
      when(() => mockDataSource.signInWithGoogle())
          .thenAnswer((_) async => Right(userModel));

      // Act
      final result = await repository.signInWithGoogle();

      // Assert
      result.fold(
            (failure) => fail('Should not return failure'),
            (authResult) => expect(authResult.isFirstLogin, false),
      );
    });

    test('logs sign-in success with correct context', () async {
      // Arrange
      final userModel = createMockUserModel(
        id: 'user-789',
        fullName: 'Jane Smith',
        role: 'teacher',
      );
      when(() => mockDataSource.signInWithGoogle())
          .thenAnswer((_) async => Right(userModel));

      // Act
      await repository.signInWithGoogle();

      // Assert
      verify(() => mockLogger.authEvent(
        'google_signin_repository_success',
        'user-789',
        context: any(named: 'context'),
      )).called(1);
    });

    test('returns Left when data source fails', () async {
      // Arrange
      const failure = UnauthorizedDomainFailure('example.com');
      when(() => mockDataSource.signInWithGoogle())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await repository.signInWithGoogle();

      // Assert
      expect(result.isLeft(), true);
      result.fold(
            (failure) => expect(failure, isA<UnauthorizedDomainFailure>()),
            (authResult) => fail('Should not return auth result'),
      );
    });

    test('logs error when sign-in fails', () async {
      // Arrange
      const failure = AuthFailure('Network error');
      when(() => mockDataSource.signInWithGoogle())
          .thenAnswer((_) async => const Left(failure));

      // Act
      await repository.signInWithGoogle();

      // Assert
      verify(() => mockLogger.authError(
        'Google sign-in repository failed',
        failure,
        context: any(named: 'context'),
      )).called(1);
    });
  });

  group('AuthRepositoryImpl - getCurrentUser', () {
    test('calls data source getCurrentUser method', () async {
      // Arrange
      final userModel = createMockUserModel();
      when(() => mockDataSource.getCurrentUser())
          .thenAnswer((_) async => Right(userModel));

      // Act
      await repository.getCurrentUser();

      // Assert
      verify(() => mockDataSource.getCurrentUser()).called(1);
    });

    test('returns Right with UserEntity when user exists', () async {
      // Arrange
      final userModel = createMockUserModel();
      when(() => mockDataSource.getCurrentUser())
          .thenAnswer((_) async => Right(userModel));

      // Act
      final result = await repository.getCurrentUser();

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not return failure'),
            (user) {
          expect(user, isA<UserEntity>());
          expect(user?.id, userModel.id);
        },
      );
    });

    test('returns Right with null when no user exists', () async {
      // Arrange
      when(() => mockDataSource.getCurrentUser())
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await repository.getCurrentUser();

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not return failure'),
            (user) => expect(user, isNull),
      );
    });

    test('returns Left when data source fails', () async {
      // Arrange
      const failure = SessionExpiredFailure();
      when(() => mockDataSource.getCurrentUser())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await repository.getCurrentUser();

      // Assert
      expect(result.isLeft(), true);
      result.fold(
            (failure) => expect(failure, isA<SessionExpiredFailure>()),
            (user) => fail('Should not return user'),
      );
    });

    test('converts UserModel to UserEntity correctly', () async {
      // Arrange
      final userModel = createMockUserModel(
        id: 'user-999',
        email: 'convert@test.com',
        fullName: 'Convert Test',
        role: 'admin',
        isActive: true,
      );
      when(() => mockDataSource.getCurrentUser())
          .thenAnswer((_) async => Right(userModel));

      // Act
      final result = await repository.getCurrentUser();

      // Assert
      result.fold(
            (failure) => fail('Should not fail'),
            (user) {
          expect(user?.id, 'user-999');
          expect(user?.email, 'convert@test.com');
          expect(user?.fullName, 'Convert Test');
          expect(user?.role, UserRole.admin);
          expect(user?.isActive, true);
        },
      );
    });
  });

  group('AuthRepositoryImpl - getUserById', () {
    const testUserId = 'user-456';

    test('calls data source getUserProfileById with correct userId', () async {
      // Arrange
      final userModel = createMockUserModel(id: testUserId);
      when(() => mockDataSource.getUserProfileById(any()))
          .thenAnswer((_) async => Right(userModel));

      // Act
      await repository.getUserById(testUserId);

      // Assert
      verify(() => mockDataSource.getUserProfileById(testUserId)).called(1);
    });

    test('logs debug message when fetching user', () async {
      // Arrange
      final userModel = createMockUserModel(id: testUserId);
      when(() => mockDataSource.getUserProfileById(testUserId))
          .thenAnswer((_) async => Right(userModel));

      // Act
      await repository.getUserById(testUserId);

      // Assert
      verify(() => mockLogger.debug(
        'Repository: Getting user by ID',
        category: LogCategory.auth,
        context: {'targetUserId': testUserId},
      )).called(1);
    });

    test('returns Right with UserEntity when user is found', () async {
      // Arrange
      final userModel = createMockUserModel(id: testUserId);
      when(() => mockDataSource.getUserProfileById(testUserId))
          .thenAnswer((_) async => Right(userModel));

      // Act
      final result = await repository.getUserById(testUserId);

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not return failure'),
            (user) {
          expect(user, isA<UserEntity>());
          expect(user?.id, testUserId);
        },
      );
    });

    test('returns Right with null when user not found', () async {
      // Arrange
      when(() => mockDataSource.getUserProfileById(testUserId))
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await repository.getUserById(testUserId);

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not return failure'),
            (user) => expect(user, isNull),
      );
    });

    test('returns Left when data source fails', () async {
      // Arrange
      const failure = AuthFailure('User not found');
      when(() => mockDataSource.getUserProfileById(testUserId))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await repository.getUserById(testUserId);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
            (failure) => expect(failure.message, 'User not found'),
            (user) => fail('Should not return user'),
      );
    });

    test('handles exceptions and returns Left with AuthFailure', () async {
      // Arrange
      when(() => mockDataSource.getUserProfileById(testUserId))
          .thenThrow(Exception('Network error'));

      // Act
      final result = await repository.getUserById(testUserId);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
            (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, contains('Repository error getting user by ID'));
        },
            (user) => fail('Should not return user'),
      );
    });

    test('logs error when exception occurs', () async {
      // Arrange
      final exception = Exception('Database timeout');
      when(() => mockDataSource.getUserProfileById(testUserId))
          .thenThrow(exception);

      // Act
      await repository.getUserById(testUserId);

      // Assert
      verify(() => mockLogger.error(
        'Repository: Exception getting user by ID',
        category: LogCategory.auth,
        error: exception,
        stackTrace: any(named: 'stackTrace'),
        context: {'targetUserId': testUserId},
      )).called(1);
    });
  });

  group('AuthRepositoryImpl - signOut', () {
    test('calls data source signOut method', () async {
      // Arrange
      when(() => mockDataSource.signOut())
          .thenAnswer((_) async => const Right(null));

      // Act
      await repository.signOut();

      // Assert
      verify(() => mockDataSource.signOut()).called(1);
    });

    test('returns Right when sign-out succeeds', () async {
      // Arrange
      when(() => mockDataSource.signOut())
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await repository.signOut();

      // Assert
      expect(result.isRight(), true);
    });

    test('returns Left when data source fails', () async {
      // Arrange
      const failure = AuthFailure('Sign-out failed');
      when(() => mockDataSource.signOut())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await repository.signOut();

      // Assert
      expect(result.isLeft(), true);
    });
  });

  group('AuthRepositoryImpl - isAuthenticated getter', () {
    test('returns true when data source isAuthenticated is true', () {
      // Arrange
      when(() => mockDataSource.isAuthenticated).thenReturn(true);

      // Act
      final result = repository.isAuthenticated;

      // Assert
      expect(result, true);
      verify(() => mockDataSource.isAuthenticated).called(1);
    });

    test('returns false when data source isAuthenticated is false', () {
      // Arrange
      when(() => mockDataSource.isAuthenticated).thenReturn(false);

      // Act
      final result = repository.isAuthenticated;

      // Assert
      expect(result, false);
    });
  });
}