import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/core/domain/interfaces/i_logger.dart';
import 'package:papercraft/features/authentication/data/datasources/tenant_data_source.dart';
import 'package:papercraft/features/authentication/data/models/tenant_model.dart';
import 'package:papercraft/features/authentication/data/repositories/tenant_repository_impl.dart';
import 'package:papercraft/features/authentication/domain/entities/tenant_entity.dart';
import 'package:papercraft/features/authentication/domain/repositories/tenant_repository.dart';
import 'package:papercraft/features/authentication/domain/services/user_state_service.dart';

// ============================================================================
// MOCKS
// ============================================================================

class MockTenantDataSource extends Mock implements TenantDataSource {}

class MockLogger extends Mock implements ILogger {}

class MockUserStateService extends Mock implements UserStateService {}

// ============================================================================
// TEST HELPERS
// ============================================================================

TenantEntity createMockTenantEntity({
  String id = 'tenant-123',
  String name = 'Test School',
  String? address,
  String? domain,
  bool isActive = true,
  bool isInitialized = false,
  String currentAcademicYear = '2024-2025',
  DateTime? createdAt,
}) {
  return TenantEntity(
    id: id,
    name: name,
    address: address,
    domain: domain,
    isActive: isActive,
    isInitialized: isInitialized,
    createdAt: createdAt ?? DateTime(2024, 1, 1),
  );
}

TenantModel createMockTenantModel({
  String id = 'tenant-123',
  String name = 'Test School',
  String? address,
  String? domain,
  bool isActive = true,
  bool isInitialized = false,
  String currentAcademicYear = '2024-2025',
  DateTime? createdAt,
}) {
  return TenantModel(
    id: id,
    name: name,
    address: address,
    domain: domain,
    isActive: isActive,
    isInitialized: isInitialized,
    createdAt: createdAt ?? DateTime(2024, 1, 1),
  );
}

// ============================================================================
// MAIN TEST SUITE
// ============================================================================

void main() {
  late TenantRepository tenantRepository;
  late MockTenantDataSource mockTenantDataSource;
  late MockLogger mockLogger;
  late MockUserStateService mockUserStateService;

  setUpAll(() {
    // Register fallback values
    registerFallbackValue(LogCategory.auth);
    registerFallbackValue(createMockTenantModel());
  });

  setUp(() {
    mockTenantDataSource = MockTenantDataSource();
    mockLogger = MockLogger();
    mockUserStateService = MockUserStateService();

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

    tenantRepository = TenantRepositoryImpl(
      mockTenantDataSource,
      mockLogger,
    );
  });

  group('TenantRepository - getTenantById', () {
    test('returns Right with tenant when tenant exists', () async {
      // Arrange
      final mockTenant = createMockTenantModel(id: 'tenant-123', name: 'Test School');

      when(() => mockTenantDataSource.getTenantById(any()))
          .thenAnswer((_) async => mockTenant);

      // Act
      final result = await tenantRepository.getTenantById('tenant-123');

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (tenant) {
          expect(tenant, isNotNull);
          expect(tenant?.id, 'tenant-123');
          expect(tenant?.name, 'Test School');
        },
      );
      verify(() => mockTenantDataSource.getTenantById('tenant-123')).called(1);
    });

    test('returns Right with null when tenant does not exist', () async {
      // Arrange
      when(() => mockTenantDataSource.getTenantById(any()))
          .thenAnswer((_) async => null);

      // Act
      final result = await tenantRepository.getTenantById('tenant-999');

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (tenant) => expect(tenant, isNull),
      );
    });

    test('returns Left with ServerFailure when datasource throws exception', () async {
      // Arrange
      when(() => mockTenantDataSource.getTenantById(any()))
          .thenThrow(Exception('Database error'));

      // Act
      final result = await tenantRepository.getTenantById('tenant-123');

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, contains('Failed to get tenant'));
        },
        (tenant) => fail('Should not return tenant'),
      );
      verify(() => mockLogger.error(any(),
          category: LogCategory.auth,
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'))).called(1);
    });
  });

  group('TenantRepository - updateTenant', () {
    test('successfully updates tenant', () async {
      // Arrange
      final mockTenant = createMockTenantEntity(name: 'Updated School');
      final updatedModel = createMockTenantModel(name: 'Updated School');

      when(() => mockTenantDataSource.updateTenant(any()))
          .thenAnswer((_) async => updatedModel);

      // Act
      final result = await tenantRepository.updateTenant(mockTenant);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (tenant) => expect(tenant.name, 'Updated School'),
      );
      verify(() => mockTenantDataSource.updateTenant(any())).called(1);
    });

    test('returns Left with ServerFailure when update fails', () async {
      // Arrange
      final mockTenant = createMockTenantEntity();

      when(() => mockTenantDataSource.updateTenant(any()))
          .thenThrow(Exception('Database error'));

      // Act
      final result = await tenantRepository.updateTenant(mockTenant);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, contains('Failed to update tenant'));
        },
        (tenant) => fail('Should not return tenant'),
      );
      verify(() => mockTenantDataSource.updateTenant(any())).called(1);
    });
  });

  group('TenantRepository - getActiveTenants', () {
    test('returns Right with list of active tenants', () async {
      // Arrange
      final mockTenants = [
        createMockTenantModel(id: 'tenant-1', name: 'School A', isActive: true),
        createMockTenantModel(id: 'tenant-2', name: 'School B', isActive: true),
      ];

      when(() => mockTenantDataSource.getActiveTenants())
          .thenAnswer((_) async => mockTenants);

      // Act
      final result = await tenantRepository.getActiveTenants();

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (tenants) {
          expect(tenants.length, 2);
          expect(tenants[0].name, 'School A');
          expect(tenants[1].name, 'School B');
        },
      );
      verify(() => mockTenantDataSource.getActiveTenants()).called(1);
    });

    test('returns Right with empty list when no active tenants', () async {
      // Arrange
      when(() => mockTenantDataSource.getActiveTenants())
          .thenAnswer((_) async => []);

      // Act
      final result = await tenantRepository.getActiveTenants();

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (tenants) => expect(tenants, isEmpty),
      );
    });

    test('returns Left with ServerFailure when datasource throws exception', () async {
      // Arrange
      when(() => mockTenantDataSource.getActiveTenants())
          .thenThrow(Exception('Connection failed'));

      // Act
      final result = await tenantRepository.getActiveTenants();

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, contains('Failed to get active tenants'));
        },
        (tenants) => fail('Should not return tenants'),
      );
    });
  });

  group('TenantRepository - isTenantActive', () {
    test('returns Right with true when tenant is active', () async {
      // Arrange
      when(() => mockTenantDataSource.isTenantActive(any()))
          .thenAnswer((_) async => true);

      // Act
      final result = await tenantRepository.isTenantActive('tenant-123');

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (isActive) => expect(isActive, true),
      );
      verify(() => mockTenantDataSource.isTenantActive('tenant-123')).called(1);
    });

    test('returns Right with false when tenant is inactive', () async {
      // Arrange
      when(() => mockTenantDataSource.isTenantActive(any()))
          .thenAnswer((_) async => false);

      // Act
      final result = await tenantRepository.isTenantActive('tenant-123');

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (isActive) => expect(isActive, false),
      );
    });

    test('returns Left with ServerFailure when check fails', () async {
      // Arrange
      when(() => mockTenantDataSource.isTenantActive(any()))
          .thenThrow(Exception('Status check failed'));

      // Act
      final result = await tenantRepository.isTenantActive('tenant-123');

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, contains('Failed to check tenant status'));
        },
        (isActive) => fail('Should not return status'),
      );
    });
  });

  group('TenantRepository - markAsInitialized', () {
    test('returns Right when marking as initialized succeeds', () async {
      // Arrange
      when(() => mockTenantDataSource.markAsInitialized(any()))
          .thenAnswer((_) async => Future.value());

      // Act
      final result = await tenantRepository.markAsInitialized('tenant-123');

      // Assert
      expect(result.isRight(), true);
      verify(() => mockTenantDataSource.markAsInitialized('tenant-123')).called(1);
      verify(() => mockLogger.info('Marking tenant as initialized',
          category: LogCategory.auth, context: any(named: 'context'))).called(1);
      verify(() => mockLogger.info('Tenant marked as initialized successfully',
          category: LogCategory.auth, context: any(named: 'context'))).called(1);
    });

    test('returns Left with ServerFailure when marking fails', () async {
      // Arrange
      when(() => mockTenantDataSource.markAsInitialized(any()))
          .thenThrow(Exception('Update failed'));

      // Act
      final result = await tenantRepository.markAsInitialized('tenant-123');

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, contains('Failed to mark tenant as initialized'));
        },
        (_) => fail('Should not succeed'),
      );
      verify(() => mockLogger.error(any(),
          category: LogCategory.auth,
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
          context: any(named: 'context'))).called(1);
    });

    test('logs operation with correct context', () async {
      // Arrange
      when(() => mockTenantDataSource.markAsInitialized(any()))
          .thenAnswer((_) async => Future.value());

      // Act
      await tenantRepository.markAsInitialized('tenant-456');

      // Assert
      verify(() => mockLogger.info('Marking tenant as initialized',
          category: LogCategory.auth,
          context: {
            'tenantId': 'tenant-456',
            'operation': 'mark_initialized',
          })).called(1);

      verify(() => mockLogger.info('Tenant marked as initialized successfully',
          category: LogCategory.auth,
          context: {'tenantId': 'tenant-456'})).called(1);
    });
  });

  group('TenantRepository - Error Handling', () {
    test('handles network errors gracefully in getTenantById', () async {
      // Arrange
      when(() => mockTenantDataSource.getTenantById(any()))
          .thenThrow(Exception('Network timeout'));

      // Act
      final result = await tenantRepository.getTenantById('tenant-123');

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure.message, contains('Network timeout')),
        (_) => fail('Should fail'),
      );
    });

    test('handles server errors correctly in updateTenant', () async {
      // Arrange
      final mockTenant = createMockTenantEntity();

      when(() => mockTenantDataSource.updateTenant(any()))
          .thenThrow(Exception('Network error'));

      // Act
      final result = await tenantRepository.updateTenant(mockTenant);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Should fail'),
      );
    });

    test('logs all errors with proper context', () async {
      // Arrange
      when(() => mockTenantDataSource.getActiveTenants())
          .thenThrow(Exception('Database connection lost'));

      // Act
      await tenantRepository.getActiveTenants();

      // Assert
      verify(() => mockLogger.error(
            'Failed to get active tenants',
            category: LogCategory.auth,
            error: any(named: 'error'),
            stackTrace: any(named: 'stackTrace'),
          )).called(1);
    });
  });
}
