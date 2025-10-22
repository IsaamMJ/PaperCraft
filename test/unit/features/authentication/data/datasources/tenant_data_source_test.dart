import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:papercraft/core/domain/interfaces/i_logger.dart';
import 'package:papercraft/core/infrastructure/network/api_client.dart';
import 'package:papercraft/core/infrastructure/network/models/api_response.dart';
import 'package:papercraft/features/authentication/data/datasources/tenant_data_source.dart';
import 'package:papercraft/features/authentication/data/models/tenant_model.dart';

// ============================================================================
// MOCKS
// ============================================================================

class MockApiClient extends Mock implements ApiClient {}

class MockLogger extends Mock implements ILogger {}

// ============================================================================
// TEST HELPERS
// ============================================================================

TenantModel createMockTenantModel({
  String id = 'tenant-123',
  String name = 'Test School',
  bool isActive = true,
  bool isInitialized = false,
  DateTime? createdAt,
}) {
  return TenantModel(
    id: id,
    name: name,
    isActive: isActive,
    isInitialized: isInitialized,
    createdAt: createdAt ?? DateTime(2024, 1, 1),
  );
}

// ============================================================================
// MAIN TEST SUITE
// ============================================================================

void main() {
  late TenantDataSource tenantDataSource;
  late MockApiClient mockApiClient;
  late MockLogger mockLogger;

  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(LogCategory.auth);
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

    tenantDataSource = TenantDataSourceImpl(mockApiClient, mockLogger);
  });

  group('TenantDataSource - getTenantById', () {
    test('returns TenantModel when tenant exists', () async {
      // Arrange
      final mockTenant = createMockTenantModel();

      when(() => mockApiClient.selectSingle<TenantModel>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
      )).thenAnswer((_) async => ApiResponse.success(data: mockTenant));

      // Act
      final result = await tenantDataSource.getTenantById('tenant-123');

      // Assert
      expect(result, isNotNull);
      expect(result?.id, 'tenant-123');
      expect(result?.name, 'Test School');
      verify(() => mockApiClient.selectSingle<TenantModel>(
        table: 'tenants',
        fromJson: any(named: 'fromJson'),
        filters: {'id': 'tenant-123'},
      )).called(1);
    });

    test('returns null when tenant does not exist', () async {
      // Arrange
      when(() => mockApiClient.selectSingle<TenantModel>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
      )).thenAnswer((_) async => ApiResponse.success(data: null));

      // Act
      final result = await tenantDataSource.getTenantById('tenant-999');

      // Assert
      expect(result, isNull);
      verify(() => mockLogger.debug('Tenant not found',
          category: LogCategory.auth, context: any(named: 'context'))).called(1);
    });

    test('throws exception when API call fails', () async {
      // Arrange
      when(() => mockApiClient.selectSingle<TenantModel>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
      )).thenAnswer((_) async => ApiResponse.error(message: 'Database error', type: ApiErrorType.server));

      // Act & Assert
      expect(
            () => tenantDataSource.getTenantById('tenant-123'),
        throwsA(isA<Exception>()),
      );
    });

    test('logs correct context when fetching tenant', () async {
      // Arrange
      final mockTenant = createMockTenantModel();

      when(() => mockApiClient.selectSingle<TenantModel>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
      )).thenAnswer((_) async => ApiResponse.success(data: mockTenant));

      // Act
      await tenantDataSource.getTenantById('tenant-123');

      // Assert
      verify(() => mockLogger.debug('Fetching tenant by ID',
          category: LogCategory.auth,
          context: {
            'tenantId': 'tenant-123',
            'operation': 'get_tenant_by_id',
          })).called(1);

      verify(() => mockLogger.debug('Tenant found',
          category: LogCategory.auth,
          context: {
            'tenantId': 'tenant-123',
            'tenantName': 'Test School',
            'operation': 'get_tenant_by_id',
          })).called(1);
    });
  });

  group('TenantDataSource - updateTenant', () {
    test('successfully updates tenant and returns updated model', () async {
      // Arrange
      final mockTenant = createMockTenantModel();
      final updatedTenant = createMockTenantModel(name: 'Updated School');

      when(() => mockApiClient.update<TenantModel>(
        table: any(named: 'table'),
        data: any(named: 'data'),
        filters: any(named: 'filters'),
        fromJson: any(named: 'fromJson'),
      )).thenAnswer((_) async => ApiResponse.success(data: updatedTenant));

      // Act
      final result = await tenantDataSource.updateTenant(mockTenant);

      // Assert
      expect(result.name, 'Updated School');
      verify(() => mockApiClient.update<TenantModel>(
        table: 'tenants',
        data: mockTenant.toJson(),
        filters: {'id': 'tenant-123'},
        fromJson: any(named: 'fromJson'),
      )).called(1);
    });

    test('throws exception when update fails', () async {
      // Arrange
      final mockTenant = createMockTenantModel();

      when(() => mockApiClient.update<TenantModel>(
        table: any(named: 'table'),
        data: any(named: 'data'),
        filters: any(named: 'filters'),
        fromJson: any(named: 'fromJson'),
      )).thenAnswer((_) async => ApiResponse.error(message: 'Update failed', type: ApiErrorType.server));

      // Act & Assert
      expect(
            () => tenantDataSource.updateTenant(mockTenant),
        throwsA(isA<Exception>()),
      );
    });

    test('logs update operation with correct context', () async {
      // Arrange
      final mockTenant = createMockTenantModel();

      when(() => mockApiClient.update<TenantModel>(
        table: any(named: 'table'),
        data: any(named: 'data'),
        filters: any(named: 'filters'),
        fromJson: any(named: 'fromJson'),
      )).thenAnswer((_) async => ApiResponse.success(data: mockTenant));

      // Act
      await tenantDataSource.updateTenant(mockTenant);

      // Assert
      verify(() => mockLogger.info('Updating tenant',
          category: LogCategory.auth,
          context: {
            'tenantId': 'tenant-123',
            'tenantName': 'Test School',
            'operation': 'update_tenant',
          })).called(1);

      verify(() => mockLogger.info('Tenant updated successfully',
          category: LogCategory.auth,
          context: {
            'tenantId': 'tenant-123',
            'tenantName': 'Test School',
            'operation': 'update_tenant',
          })).called(1);
    });
  });

  group('TenantDataSource - getActiveTenants', () {
    test('returns list of active tenants', () async {
      // Arrange
      final mockTenants = [
        createMockTenantModel(id: 'tenant-1', name: 'School A', isActive: true),
        createMockTenantModel(id: 'tenant-2', name: 'School B', isActive: true),
        createMockTenantModel(id: 'tenant-3', name: 'School C', isActive: true),
      ];

      when(() => mockApiClient.select<TenantModel>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
        orderBy: any(named: 'orderBy'),
        ascending: any(named: 'ascending'),
      )).thenAnswer((_) async => ApiResponse.success(data: mockTenants));

      // Act
      final result = await tenantDataSource.getActiveTenants();

      // Assert
      expect(result.length, 3);
      expect(result[0].name, 'School A');
      expect(result[1].name, 'School B');
      expect(result[2].name, 'School C');
      verify(() => mockApiClient.select<TenantModel>(
        table: 'tenants',
        fromJson: any(named: 'fromJson'),
        filters: {'is_active': true},
        orderBy: 'name',
        ascending: true,
      )).called(1);
    });

    test('returns empty list when no active tenants', () async {
      // Arrange
      when(() => mockApiClient.select<TenantModel>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
        orderBy: any(named: 'orderBy'),
        ascending: any(named: 'ascending'),
      )).thenAnswer((_) async => ApiResponse.success(data: []));

      // Act
      final result = await tenantDataSource.getActiveTenants();

      // Assert
      expect(result, isEmpty);
    });

    test('throws exception when fetching active tenants fails', () async {
      // Arrange
      when(() => mockApiClient.select<TenantModel>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
        orderBy: any(named: 'orderBy'),
        ascending: any(named: 'ascending'),
      )).thenAnswer((_) async => ApiResponse.error(message: 'Database error', type: ApiErrorType.server));

      // Act & Assert
      expect(
            () => tenantDataSource.getActiveTenants(),
        throwsA(isA<Exception>()),
      );
    });

    test('logs tenant count when fetched successfully', () async {
      // Arrange
      final mockTenants = [
        createMockTenantModel(id: 'tenant-1', isActive: true),
        createMockTenantModel(id: 'tenant-2', isActive: true),
      ];

      when(() => mockApiClient.select<TenantModel>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
        orderBy: any(named: 'orderBy'),
        ascending: any(named: 'ascending'),
      )).thenAnswer((_) async => ApiResponse.success(data: mockTenants));

      // Act
      await tenantDataSource.getActiveTenants();

      // Assert
      verify(() => mockLogger.debug('Active tenants fetched',
          category: LogCategory.auth,
          context: {
            'count': 2,
            'operation': 'get_active_tenants',
          })).called(1);
    });
  });

  group('TenantDataSource - isTenantActive', () {
    test('returns true when tenant is active', () async {
      // Arrange
      when(() => mockApiClient.selectSingle<Map<String, dynamic>>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
      )).thenAnswer((_) async => ApiResponse.success(data: {'is_active': true}));

      // Act
      final result = await tenantDataSource.isTenantActive('tenant-123');

      // Assert
      expect(result, true);
      verify(() => mockApiClient.selectSingle<Map<String, dynamic>>(
        table: 'tenants',
        fromJson: any(named: 'fromJson'),
        filters: {'id': 'tenant-123'},
      )).called(1);
    });

    test('returns false when tenant is inactive', () async {
      // Arrange
      when(() => mockApiClient.selectSingle<Map<String, dynamic>>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
      )).thenAnswer((_) async => ApiResponse.success(data: {'is_active': false}));

      // Act
      final result = await tenantDataSource.isTenantActive('tenant-123');

      // Assert
      expect(result, false);
    });

    test('returns false when tenant does not exist', () async {
      // Arrange
      when(() => mockApiClient.selectSingle<Map<String, dynamic>>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
      )).thenAnswer((_) async => ApiResponse.success(data: null));

      // Act
      final result = await tenantDataSource.isTenantActive('tenant-999');

      // Assert
      expect(result, false);
      verify(() => mockLogger.debug('Tenant not found when checking status',
          category: LogCategory.auth, context: any(named: 'context'))).called(1);
    });

    test('throws exception when status check fails', () async {
      // Arrange
      when(() => mockApiClient.selectSingle<Map<String, dynamic>>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
      )).thenThrow(Exception('Database error'));

      // Act & Assert
      expect(
            () => tenantDataSource.isTenantActive('tenant-123'),
        throwsA(isA<Exception>()),
      );
    });

    test('logs status check with correct context', () async {
      // Arrange
      when(() => mockApiClient.selectSingle<Map<String, dynamic>>(
        table: any(named: 'table'),
        fromJson: any(named: 'fromJson'),
        filters: any(named: 'filters'),
      )).thenAnswer((_) async => ApiResponse.success(data: {'is_active': true}));

      // Act
      await tenantDataSource.isTenantActive('tenant-123');

      // Assert
      verify(() => mockLogger.debug('Checking tenant active status',
          category: LogCategory.auth,
          context: {
            'tenantId': 'tenant-123',
            'operation': 'is_tenant_active',
          })).called(1);

      verify(() => mockLogger.debug('Tenant active status checked',
          category: LogCategory.auth,
          context: {
            'tenantId': 'tenant-123',
            'isActive': true,
            'operation': 'is_tenant_active',
          })).called(1);
    });
  });

  group('TenantDataSource - markAsInitialized', () {
    test('successfully marks tenant as initialized', () async {
      // Arrange
      when(() => mockApiClient.update<Map<String, dynamic>>(
        table: any(named: 'table'),
        data: any(named: 'data'),
        filters: any(named: 'filters'),
        fromJson: any(named: 'fromJson'),
      )).thenAnswer((_) async => ApiResponse.success(data: {}));

      // Act
      await tenantDataSource.markAsInitialized('tenant-123');

      // Assert
      verify(() => mockApiClient.update<Map<String, dynamic>>(
        table: 'tenants',
        data: {'is_initialized': true},
        filters: {'id': 'tenant-123'},
        fromJson: any(named: 'fromJson'),
      )).called(1);
    });

    test('throws exception when marking as initialized fails', () async {
      // Arrange
      when(() => mockApiClient.update<Map<String, dynamic>>(
        table: any(named: 'table'),
        data: any(named: 'data'),
        filters: any(named: 'filters'),
        fromJson: any(named: 'fromJson'),
      )).thenAnswer((_) async => ApiResponse.error(message: 'Update failed', type: ApiErrorType.server));

      // Act & Assert
      expect(
            () => tenantDataSource.markAsInitialized('tenant-123'),
        throwsA(isA<Exception>()),
      );
    });

    test('logs initialization with correct context', () async {
      // Arrange
      when(() => mockApiClient.update<Map<String, dynamic>>(
        table: any(named: 'table'),
        data: any(named: 'data'),
        filters: any(named: 'filters'),
        fromJson: any(named: 'fromJson'),
      )).thenAnswer((_) async => ApiResponse.success(data: {}));

      // Act
      await tenantDataSource.markAsInitialized('tenant-123');

      // Assert
      verify(() => mockLogger.info('Marking tenant as initialized in database',
          category: LogCategory.auth,
          context: {'tenantId': 'tenant-123'})).called(1);

      verify(() => mockLogger.info('Tenant marked as initialized in database',
          category: LogCategory.auth,
          context: {'tenantId': 'tenant-123'})).called(1);
    });

    test('handles exception during initialization', () async {
      // Arrange
      when(() => mockApiClient.update<Map<String, dynamic>>(
        table: any(named: 'table'),
        data: any(named: 'data'),
        filters: any(named: 'filters'),
        fromJson: any(named: 'fromJson'),
      )).thenThrow(Exception('Network error'));

      // Act & Assert
      expect(
            () => tenantDataSource.markAsInitialized('tenant-123'),
        throwsA(isA<Exception>()),
      );
    });
  });
}