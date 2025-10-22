import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/core/domain/interfaces/i_logger.dart';
import 'package:papercraft/features/authentication/data/datasources/user_data_source.dart';
import 'package:papercraft/features/authentication/data/repositories/user_repository_impl.dart';
import 'package:papercraft/features/authentication/domain/entities/user_entity.dart';
import 'package:papercraft/features/authentication/domain/entities/user_role.dart';
import 'package:papercraft/features/authentication/domain/repositories/user_repository.dart';

// ============================================================================
// MOCKS
// ============================================================================

class MockUserDataSource extends Mock implements UserDataSource {}

class MockLogger extends Mock implements ILogger {}

// ============================================================================
// TEST HELPERS
// ============================================================================

UserEntity createMockUserEntity({
  String id = 'user-123',
  String email = 'test@example.com',
  String fullName = 'Test User',
  String? tenantId = 'tenant-123',
  UserRole role = UserRole.teacher,
  bool isActive = true,
  DateTime? createdAt,
  DateTime? lastLoginAt,
}) {
  return UserEntity(
    id: id,
    email: email,
    fullName: fullName,
    tenantId: tenantId,
    role: role,
    isActive: isActive,
    createdAt: createdAt ?? DateTime(2024, 1, 1),
    lastLoginAt: lastLoginAt,
  );
}

// ============================================================================
// MAIN TEST SUITE
// ============================================================================

void main() {
  late UserRepository userRepository;
  late MockUserDataSource mockUserDataSource;
  late MockLogger mockLogger;

  setUpAll(() {
    // Register fallback values
    registerFallbackValue(LogCategory.auth);
    registerFallbackValue(UserRole.teacher);
  });

  setUp(() {
    mockUserDataSource = MockUserDataSource();
    mockLogger = MockLogger();

    // Default logger behavior
    when(() => mockLogger.debug(any(), category: any(named: 'category'), context: any(named: 'context')))
        .thenReturn(null);
    when(() => mockLogger.info(any(), category: any(named: 'category'), context: any(named: 'context')))
        .thenReturn(null);
    when(() => mockLogger.warning(any(), category: any(named: 'category'), context: any(named: 'context')))
        .thenReturn(null);
    when(() => mockLogger.error(any(),
            category: any(named: 'category'),
            error: any(named: 'error'),
            stackTrace: any(named: 'stackTrace'),
            context: any(named: 'context')))
        .thenReturn(null);

    userRepository = UserRepositoryImpl(mockUserDataSource, mockLogger);
  });

  group('UserRepository - getTenantUsers', () {
    test('returns Right with list of users when successful', () async {
      // Arrange
      final mockUsers = [
        createMockUserEntity(id: 'user-1', fullName: 'Alice'),
        createMockUserEntity(id: 'user-2', fullName: 'Bob'),
      ];

      when(() => mockUserDataSource.getTenantUsers(any()))
          .thenAnswer((_) async => mockUsers);

      // Act
      final result = await userRepository.getTenantUsers('tenant-123');

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (users) {
          expect(users.length, 2);
          expect(users[0].fullName, 'Alice');
          expect(users[1].fullName, 'Bob');
        },
      );
      verify(() => mockUserDataSource.getTenantUsers('tenant-123')).called(1);
    });

    test('returns Right with empty list when no users found', () async {
      // Arrange
      when(() => mockUserDataSource.getTenantUsers(any()))
          .thenAnswer((_) async => []);

      // Act
      final result = await userRepository.getTenantUsers('tenant-123');

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (users) => expect(users, isEmpty),
      );
    });

    test('returns Left with ServerFailure when datasource throws exception', () async {
      // Arrange
      when(() => mockUserDataSource.getTenantUsers(any()))
          .thenThrow(Exception('Database error'));

      // Act
      final result = await userRepository.getTenantUsers('tenant-123');

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, contains('Failed to load users'));
        },
        (users) => fail('Should not return users'),
      );
      verify(() => mockLogger.error(any(),
          category: LogCategory.auth,
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'))).called(1);
    });

    test('logs error with correct context when exception occurs', () async {
      // Arrange
      when(() => mockUserDataSource.getTenantUsers(any()))
          .thenThrow(Exception('Connection timeout'));

      // Act
      await userRepository.getTenantUsers('tenant-123');

      // Assert
      verify(() => mockLogger.error(
            'Failed to get tenant users',
            category: LogCategory.auth,
            error: any(named: 'error'),
            stackTrace: any(named: 'stackTrace'),
          )).called(1);
    });
  });

  group('UserRepository - getUserById', () {
    test('returns Right with user when user exists', () async {
      // Arrange
      final mockUser = createMockUserEntity(id: 'user-123', fullName: 'John Doe');

      when(() => mockUserDataSource.getUserById(any()))
          .thenAnswer((_) async => mockUser);

      // Act
      final result = await userRepository.getUserById('user-123');

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (user) {
          expect(user, isNotNull);
          expect(user?.id, 'user-123');
          expect(user?.fullName, 'John Doe');
        },
      );
      verify(() => mockUserDataSource.getUserById('user-123')).called(1);
    });

    test('returns Right with null when user does not exist', () async {
      // Arrange
      when(() => mockUserDataSource.getUserById(any()))
          .thenAnswer((_) async => null);

      // Act
      final result = await userRepository.getUserById('user-999');

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (user) => expect(user, isNull),
      );
    });

    test('returns Left with ServerFailure when datasource throws exception', () async {
      // Arrange
      when(() => mockUserDataSource.getUserById(any()))
          .thenThrow(Exception('User fetch failed'));

      // Act
      final result = await userRepository.getUserById('user-123');

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, contains('Failed to load user'));
        },
        (user) => fail('Should not return user'),
      );
    });
  });

  group('UserRepository - updateUserRole', () {
    test('returns Right when role update succeeds', () async {
      // Arrange
      when(() => mockUserDataSource.updateUserRole(any(), any()))
          .thenAnswer((_) async => Future.value());

      // Act
      final result = await userRepository.updateUserRole('user-123', UserRole.admin);

      // Assert
      expect(result.isRight(), true);
      verify(() => mockUserDataSource.updateUserRole('user-123', UserRole.admin)).called(1);
    });

    test('updates user to all valid roles', () async {
      // Arrange
      when(() => mockUserDataSource.updateUserRole(any(), any()))
          .thenAnswer((_) async => Future.value());

      // Act & Assert - Test all roles
      var result = await userRepository.updateUserRole('user-1', UserRole.admin);
      expect(result.isRight(), true);
      verify(() => mockUserDataSource.updateUserRole('user-1', UserRole.admin)).called(1);

      result = await userRepository.updateUserRole('user-2', UserRole.teacher);
      expect(result.isRight(), true);
      verify(() => mockUserDataSource.updateUserRole('user-2', UserRole.teacher)).called(1);

      result = await userRepository.updateUserRole('user-3', UserRole.student);
      expect(result.isRight(), true);
      verify(() => mockUserDataSource.updateUserRole('user-3', UserRole.student)).called(1);
    });

    test('returns Left with ServerFailure when update fails', () async {
      // Arrange
      when(() => mockUserDataSource.updateUserRole(any(), any()))
          .thenThrow(Exception('Permission denied'));

      // Act
      final result = await userRepository.updateUserRole('user-123', UserRole.admin);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, contains('Failed to update user role'));
        },
        (_) => fail('Should not succeed'),
      );
      verify(() => mockLogger.error(any(),
          category: LogCategory.auth,
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'))).called(1);
    });
  });

  group('UserRepository - updateUserStatus', () {
    test('returns Right when status update succeeds (activate)', () async {
      // Arrange
      when(() => mockUserDataSource.updateUserStatus(any(), any()))
          .thenAnswer((_) async => Future.value());

      // Act
      final result = await userRepository.updateUserStatus('user-123', true);

      // Assert
      expect(result.isRight(), true);
      verify(() => mockUserDataSource.updateUserStatus('user-123', true)).called(1);
    });

    test('returns Right when status update succeeds (deactivate)', () async {
      // Arrange
      when(() => mockUserDataSource.updateUserStatus(any(), any()))
          .thenAnswer((_) async => Future.value());

      // Act
      final result = await userRepository.updateUserStatus('user-123', false);

      // Assert
      expect(result.isRight(), true);
      verify(() => mockUserDataSource.updateUserStatus('user-123', false)).called(1);
    });

    test('returns Left with ServerFailure when update fails', () async {
      // Arrange
      when(() => mockUserDataSource.updateUserStatus(any(), any()))
          .thenThrow(Exception('Update failed'));

      // Act
      final result = await userRepository.updateUserStatus('user-123', true);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, contains('Failed to update user status'));
        },
        (_) => fail('Should not succeed'),
      );
    });

    test('logs error when exception occurs', () async {
      // Arrange
      when(() => mockUserDataSource.updateUserStatus(any(), any()))
          .thenThrow(Exception('Network timeout'));

      // Act
      await userRepository.updateUserStatus('user-123', false);

      // Assert
      verify(() => mockLogger.error(
            'Failed to update user status',
            category: LogCategory.auth,
            error: any(named: 'error'),
            stackTrace: any(named: 'stackTrace'),
          )).called(1);
    });
  });

  group('UserRepository - Error Handling', () {
    test('handles network errors gracefully', () async {
      // Arrange
      when(() => mockUserDataSource.getTenantUsers(any()))
          .thenThrow(Exception('Network unavailable'));

      // Act
      final result = await userRepository.getTenantUsers('tenant-123');

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure.message, contains('Network unavailable')),
        (_) => fail('Should fail'),
      );
    });

    test('handles timeout errors gracefully', () async {
      // Arrange
      when(() => mockUserDataSource.getUserById(any()))
          .thenThrow(Exception('Request timeout'));

      // Act
      final result = await userRepository.getUserById('user-123');

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure.message, contains('Request timeout')),
        (_) => fail('Should fail'),
      );
    });
  });
}
