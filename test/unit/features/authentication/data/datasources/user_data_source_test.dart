import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:papercraft/core/domain/interfaces/i_logger.dart';
import 'package:papercraft/core/infrastructure/network/api_client.dart';
import 'package:papercraft/core/infrastructure/network/models/api_response.dart';
import 'package:papercraft/features/authentication/data/datasources/user_data_source.dart';
import 'package:papercraft/features/authentication/data/models/user_model.dart';
import 'package:papercraft/features/authentication/domain/entities/user_entity.dart';
import 'package:papercraft/features/authentication/domain/entities/user_role.dart';

// ============================================================================
// MOCKS
// ============================================================================

class MockApiClient extends Mock implements ApiClient {}

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
  DateTime? createdAt,
  DateTime? lastLoginAt,
}) {
  return UserModel(
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
  late UserDataSource userDataSource;
  late MockApiClient mockApiClient;
  late MockLogger mockLogger;

  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(LogCategory.auth);
    registerFallbackValue(UserRole.teacher);
  });

  setUp(() {
    mockApiClient = MockApiClient();
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

    userDataSource = UserDataSourceImpl(mockApiClient, mockLogger);
  });

  group('UserDataSource - getTenantUsers', () {
    test('returns list of active users for tenant', () async {
      // Arrange
      final mockUsers = [
        createMockUserModel(id: 'user-1', fullName: 'Alice Teacher', role: 'teacher'),
        createMockUserModel(id: 'user-2', fullName: 'Bob Teacher', role: 'teacher'),
        createMockUserModel(id: 'user-3', fullName: 'Charlie Admin', role: 'admin'),
      ];

      when(() => mockApiClient.select<UserModel>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
        orderBy: any(named: 'orderBy'),
      )).thenAnswer((_) async => ApiResponse.success(data: mockUsers));

      // Act
      final result = await userDataSource.getTenantUsers('tenant-123');

      // Assert
      expect(result.length, 3);
      expect(result[0].fullName, 'Alice Teacher');
      expect(result[1].fullName, 'Bob Teacher');
      expect(result[2].fullName, 'Charlie Admin');
      verify(() => mockApiClient.select<UserModel>(
        table: 'profiles',
        fromJson: any(named: 'fromJson'),
        filters: {
          'tenant_id': 'tenant-123',
          'is_active': true,
        },
        orderBy: 'full_name',
      )).called(1);
    });

    test('returns empty list when no users found', () async {
      // Arrange
      when(() => mockApiClient.select<UserModel>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
        orderBy: any(named: 'orderBy'),
      )).thenAnswer((_) async => ApiResponse.success(data: []));

      // Act
      final result = await userDataSource.getTenantUsers('tenant-999');

      // Assert
      expect(result, isEmpty);
    });

    test('returns empty list when response data is null', () async {
      // Arrange
      when(() => mockApiClient.select<UserModel>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
        orderBy: any(named: 'orderBy'),
      )).thenAnswer((_) async => ApiResponse.success(data: <UserModel>[]));

      // Act
      final result = await userDataSource.getTenantUsers('tenant-123');

      // Assert
      expect(result, isEmpty);
    });

    test('throws exception when API call fails', () async {
      // Arrange
      when(() => mockApiClient.select<UserModel>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
        orderBy: any(named: 'orderBy'),
      )).thenAnswer((_) async => ApiResponse.error(message: 'Database error', type: ApiErrorType.server));

      // Act & Assert
      expect(
            () => userDataSource.getTenantUsers('tenant-123'),
        throwsA(isA<Exception>()),
      );
    });

    test('logs operation with correct context', () async {
      // Arrange
      final mockUsers = [createMockUserModel(), createMockUserModel(id: 'user-2')];

      when(() => mockApiClient.select<UserModel>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
        orderBy: any(named: 'orderBy'),
      )).thenAnswer((_) async => ApiResponse.success(data: mockUsers));

      // Act
      await userDataSource.getTenantUsers('tenant-123');

      // Assert
      verify(() => mockLogger.debug('Fetching users for tenant',
          category: LogCategory.auth,
          context: {'tenantId': 'tenant-123'})).called(1);

      verify(() => mockLogger.info('Users fetched successfully',
          category: LogCategory.auth,
          context: {
            'tenantId': 'tenant-123',
            'count': 2,
          })).called(1);
    });

    test('converts UserModel to UserEntity correctly', () async {
      // Arrange
      final mockUsers = [
        createMockUserModel(
          id: 'user-1',
          email: 'teacher@test.com',
          fullName: 'Test Teacher',
          role: 'teacher',
          tenantId: 'tenant-123',
        ),
      ];

      when(() => mockApiClient.select<UserModel>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
        orderBy: any(named: 'orderBy'),
      )).thenAnswer((_) async => ApiResponse.success(data: mockUsers));

      // Act
      final result = await userDataSource.getTenantUsers('tenant-123');

      // Assert
      expect(result.first, isA<UserEntity>());
      expect(result.first.id, 'user-1');
      expect(result.first.email, 'teacher@test.com');
      expect(result.first.fullName, 'Test Teacher');
      expect(result.first.role, UserRole.teacher);
      expect(result.first.tenantId, 'tenant-123');
    });
  });

  group('UserDataSource - getUserById', () {
    test('returns UserEntity when user exists', () async {
      // Arrange
      final mockUser = createMockUserModel(id: 'user-123', fullName: 'John Doe');

      when(() => mockApiClient.selectSingle<UserModel>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
      )).thenAnswer((_) async => ApiResponse.success(data: mockUser));

      // Act
      final result = await userDataSource.getUserById('user-123');

      // Assert
      expect(result, isNotNull);
      expect(result?.id, 'user-123');
      expect(result?.fullName, 'John Doe');
      verify(() => mockApiClient.selectSingle<UserModel>(
        table: 'profiles',
        fromJson: any(named: 'fromJson'),
        filters: {'id': 'user-123'},
      )).called(1);
    });

    test('returns null when user does not exist', () async {
      // Arrange
      when(() => mockApiClient.selectSingle<UserModel>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
      )).thenAnswer((_) async => ApiResponse.success(data: null));

      // Act
      final result = await userDataSource.getUserById('user-999');

      // Assert
      expect(result, isNull);
      verify(() => mockLogger.warning('User not found',
          category: LogCategory.auth, context: any(named: 'context'))).called(1);
    });

    test('returns null when API call fails', () async {
      // Arrange
      when(() => mockApiClient.selectSingle<UserModel>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
      )).thenAnswer((_) async => ApiResponse.error(message: 'User not found', type: ApiErrorType.notFound));

      // Act
      final result = await userDataSource.getUserById('user-123');

      // Assert
      expect(result, isNull);
    });

    test('throws exception on unexpected errors', () async {
      // Arrange
      when(() => mockApiClient.selectSingle<UserModel>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
      )).thenThrow(Exception('Network error'));

      // Act & Assert
      expect(
            () => userDataSource.getUserById('user-123'),
        throwsA(isA<Exception>()),
      );
    });

    test('logs operation with correct context', () async {
      // Arrange
      final mockUser = createMockUserModel();

      when(() => mockApiClient.selectSingle<UserModel>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
      )).thenAnswer((_) async => ApiResponse.success(data: mockUser));

      // Act
      await userDataSource.getUserById('user-123');

      // Assert
      verify(() => mockLogger.debug('Fetching user by ID',
          category: LogCategory.auth,
          context: {'userId': 'user-123'})).called(1);
    });
  });

  group('UserDataSource - updateUserRole', () {
    test('successfully updates user role', () async {
      // Arrange
      when(() => mockApiClient.update<Map<String, dynamic>>(
        table: any(named: 'table'),
        data: any(named: 'data'),
        filters: any(named: 'filters'),
        fromJson: any(named: 'fromJson'),
      )).thenAnswer((_) async => ApiResponse<Map<String, dynamic>>.success(data: {}));

      // Act
      await userDataSource.updateUserRole('user-123', UserRole.admin);

      // Assert
      verify(() => mockApiClient.update<Map<String, dynamic>>(
        table: 'profiles',
        data: {'role': 'admin'},
        filters: {'id': 'user-123'},
        fromJson: any(named: 'fromJson'),
      )).called(1);
    });

    test('throws exception when update fails', () async {
      // Arrange
      when(() => mockApiClient.update<Map<String, dynamic>>(
        table: any(named: 'table'),
        data: any(named: 'data'),
        filters: any(named: 'filters'),
        fromJson: any(named: 'fromJson'),
      )).thenAnswer((_) async => ApiResponse<Map<String, dynamic>>.error(message: 'Update failed', type: ApiErrorType.server));

      // Act & Assert
      expect(
            () => userDataSource.updateUserRole('user-123', UserRole.teacher),
        throwsA(isA<Exception>()),
      );
    });

    test('handles all user roles correctly', () async {
      // Arrange
      when(() => mockApiClient.update<Map<String, dynamic>>(
        table: any(named: 'table'),
        data: any(named: 'data'),
        filters: any(named: 'filters'),
        fromJson: any(named: 'fromJson'),
      )).thenAnswer((_) async => ApiResponse<Map<String, dynamic>>.success(data: {}));

      // Act & Assert - Test all role types
      await userDataSource.updateUserRole('user-1', UserRole.admin);
      verify(() => mockApiClient.update<Map<String, dynamic>>(
        table: 'profiles',
        data: {'role': 'admin'},
        filters: {'id': 'user-1'},
        fromJson: any(named: 'fromJson'),
      )).called(1);

      await userDataSource.updateUserRole('user-2', UserRole.teacher);
      verify(() => mockApiClient.update<Map<String, dynamic>>(
        table: 'profiles',
        data: {'role': 'teacher'},
        filters: {'id': 'user-2'},
        fromJson: any(named: 'fromJson'),
      )).called(1);

      await userDataSource.updateUserRole('user-3', UserRole.student);
      verify(() => mockApiClient.update<Map<String, dynamic>>(
        table: 'profiles',
        data: {'role': 'student'},
        filters: {'id': 'user-3'},
        fromJson: any(named: 'fromJson'),
      )).called(1);
    });

    test('logs role update with correct context', () async {
      // Arrange
      when(() => mockApiClient.update<Map<String, dynamic>>(
        table: any(named: 'table'),
        data: any(named: 'data'),
        filters: any(named: 'filters'),
        fromJson: any(named: 'fromJson'),
      )).thenAnswer((_) async => ApiResponse<Map<String, dynamic>>.success(data: {}));

      // Act
      await userDataSource.updateUserRole('user-123', UserRole.admin);

      // Assert
      verify(() => mockLogger.info('Updating user role',
          category: LogCategory.auth,
          context: {
            'userId': 'user-123',
            'newRole': 'admin',
          })).called(1);

      verify(() => mockLogger.info('User role updated successfully',
          category: LogCategory.auth,
          context: {'userId': 'user-123'})).called(1);
    });

    test('handles network errors during role update', () async {
      // Arrange
      when(() => mockApiClient.update<Map<String, dynamic>>(
        table: any(named: 'table'),
        data: any(named: 'data'),
        filters: any(named: 'filters'),
        fromJson: any(named: 'fromJson'),
      )).thenThrow(Exception('Network timeout'));

      // Act & Assert
      expect(
            () => userDataSource.updateUserRole('user-123', UserRole.teacher),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('UserDataSource - updateUserStatus', () {
    test('successfully activates user', () async {
      // Arrange
      when(() => mockApiClient.update<Map<String, dynamic>>(
        table: any(named: 'table'),
        data: any(named: 'data'),
        filters: any(named: 'filters'),
        fromJson: any(named: 'fromJson'),
      )).thenAnswer((_) async => ApiResponse<Map<String, dynamic>>.success(data: {}));

      // Act
      await userDataSource.updateUserStatus('user-123', true);

      // Assert
      verify(() => mockApiClient.update<Map<String, dynamic>>(
        table: 'profiles',
        data: {'is_active': true},
        filters: {'id': 'user-123'},
        fromJson: any(named: 'fromJson'),
      )).called(1);
    });

    test('successfully deactivates user', () async {
      // Arrange
      when(() => mockApiClient.update<Map<String, dynamic>>(
        table: any(named: 'table'),
        data: any(named: 'data'),
        filters: any(named: 'filters'),
        fromJson: any(named: 'fromJson'),
      )).thenAnswer((_) async => ApiResponse<Map<String, dynamic>>.success(data: {}));

      // Act
      await userDataSource.updateUserStatus('user-123', false);

      // Assert
      verify(() => mockApiClient.update<Map<String, dynamic>>(
        table: 'profiles',
        data: {'is_active': false},
        filters: {'id': 'user-123'},
        fromJson: any(named: 'fromJson'),
      )).called(1);
    });

    test('throws exception when update fails', () async {
      // Arrange
      when(() => mockApiClient.update<Map<String, dynamic>>(
        table: any(named: 'table'),
        data: any(named: 'data'),
        filters: any(named: 'filters'),
        fromJson: any(named: 'fromJson'),
      )).thenAnswer((_) async => ApiResponse<Map<String, dynamic>>.error(message: 'Update failed', type: ApiErrorType.server));

      // Act & Assert
      expect(
            () => userDataSource.updateUserStatus('user-123', true),
        throwsA(isA<Exception>()),
      );
    });

    test('logs status update with correct context', () async {
      // Arrange
      when(() => mockApiClient.update<Map<String, dynamic>>(
        table: any(named: 'table'),
        data: any(named: 'data'),
        filters: any(named: 'filters'),
        fromJson: any(named: 'fromJson'),
      )).thenAnswer((_) async => ApiResponse<Map<String, dynamic>>.success(data: {}));

      // Act
      await userDataSource.updateUserStatus('user-123', false);

      // Assert
      verify(() => mockLogger.info('Updating user status',
          category: LogCategory.auth,
          context: {
            'userId': 'user-123',
            'isActive': false,
          })).called(1);

      verify(() => mockLogger.info('User status updated successfully',
          category: LogCategory.auth,
          context: {'userId': 'user-123'})).called(1);
    });

    test('handles network errors during status update', () async {
      // Arrange
      when(() => mockApiClient.update<Map<String, dynamic>>(
        table: any(named: 'table'),
        data: any(named: 'data'),
        filters: any(named: 'filters'),
        fromJson: any(named: 'fromJson'),
      )).thenThrow(Exception('Connection refused'));

      // Act & Assert
      expect(
            () => userDataSource.updateUserStatus('user-123', true),
        throwsA(isA<Exception>()),
      );
    });

    test('handles both active and inactive status correctly', () async {
      // Arrange
      when(() => mockApiClient.update<Map<String, dynamic>>(
        table: any(named: 'table'),
        data: any(named: 'data'),
        filters: any(named: 'filters'),
        fromJson: any(named: 'fromJson'),
      )).thenAnswer((_) async => ApiResponse<Map<String, dynamic>>.success(data: {}));

      // Act - Activate
      await userDataSource.updateUserStatus('user-1', true);
      verify(() => mockApiClient.update<Map<String, dynamic>>(
        table: 'profiles',
        data: {'is_active': true},
        filters: {'id': 'user-1'},
        fromJson: any(named: 'fromJson'),
      )).called(1);

      // Act - Deactivate
      await userDataSource.updateUserStatus('user-2', false);
      verify(() => mockApiClient.update<Map<String, dynamic>>(
        table: 'profiles',
        data: {'is_active': false},
        filters: {'id': 'user-2'},
        fromJson: any(named: 'fromJson'),
      )).called(1);
    });
  });

  group('UserDataSource - Error Handling', () {
    test('rethrows exceptions from getTenantUsers', () async {
      // Arrange
      when(() => mockApiClient.select<UserModel>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
        orderBy: any(named: 'orderBy'),
      )).thenThrow(Exception('Database connection lost'));

      // Act & Assert
      expect(
            () => userDataSource.getTenantUsers('tenant-123'),
        throwsA(isA<Exception>()),
      );
    });

    test('rethrows exceptions from getUserById', () async {
      // Arrange
      when(() => mockApiClient.selectSingle<UserModel>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
      )).thenThrow(Exception('Timeout'));

      // Act & Assert
      expect(
            () => userDataSource.getUserById('user-123'),
        throwsA(isA<Exception>()),
      );
    });

    test('rethrows exceptions from updateUserRole', () async {
      // Arrange
      when(() => mockApiClient.update<Map<String, dynamic>>(
        table: any(named: 'table'),
        data: any(named: 'data'),
        filters: any(named: 'filters'),
        fromJson: any(named: 'fromJson'),
      )).thenThrow(Exception('Permission denied'));

      // Act & Assert
      expect(
            () => userDataSource.updateUserRole('user-123', UserRole.admin),
        throwsA(isA<Exception>()),
      );
    });

    test('rethrows exceptions from updateUserStatus', () async {
      // Arrange
      when(() => mockApiClient.update<Map<String, dynamic>>(
        table: any(named: 'table'),
        data: any(named: 'data'),
        filters: any(named: 'filters'),
        fromJson: any(named: 'fromJson'),
      )).thenThrow(Exception('Server error'));

      // Act & Assert
      expect(
            () => userDataSource.updateUserStatus('user-123', true),
        throwsA(isA<Exception>()),
      );
    });
  });
}