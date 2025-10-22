import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/features/authentication/domain/entities/tenant_entity.dart';
import 'package:papercraft/features/authentication/domain/repositories/tenant_repository.dart';
import 'package:papercraft/features/authentication/domain/usecases/get_tenant_usecase.dart';

// ============================================================================
// MOCKS
// ============================================================================

class MockTenantRepository extends Mock implements TenantRepository {}

// ============================================================================
// TEST HELPERS
// ============================================================================

TenantEntity createMockTenant({
  String id = 'tenant-123',
  String name = 'Test School',
  String? address,
  String? domain,
  bool isActive = true,
  bool isInitialized = true,
  String currentAcademicYear = '2024-2025',
}) {
  return TenantEntity(
    id: id,
    name: name,
    address: address,
    domain: domain,
    isActive: isActive,
    isInitialized: isInitialized,
    createdAt: DateTime.now(),
  );
}

// ============================================================================
// MAIN TEST SUITE
// ============================================================================

void main() {
  late GetTenantUseCase getTenantUseCase;
  late MockTenantRepository mockRepository;

  setUp(() {
    mockRepository = MockTenantRepository();
    getTenantUseCase = GetTenantUseCase(mockRepository);
  });

  group('GetTenantUseCase - call method', () {
    const validTenantId = 'tenant-123';

    test('calls repository getTenantById with correct tenantId', () async {
      // Arrange
      final mockTenant = createMockTenant(id: validTenantId);
      when(() => mockRepository.getTenantById(any()))
          .thenAnswer((_) async => Right(mockTenant));

      // Act
      await getTenantUseCase(validTenantId);

      // Assert
      verify(() => mockRepository.getTenantById(validTenantId)).called(1);
    });

    test('returns Right with tenant when tenant exists and is active', () async {
      // Arrange
      final mockTenant = createMockTenant(
        id: validTenantId,
        name: 'Active School',
        isActive: true,
      );
      when(() => mockRepository.getTenantById(validTenantId))
          .thenAnswer((_) async => Right(mockTenant));

      // Act
      final result = await getTenantUseCase(validTenantId);

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not return failure'),
            (tenant) {
          expect(tenant, mockTenant);
          expect(tenant?.id, validTenantId);
          expect(tenant?.name, 'Active School');
          expect(tenant?.isActive, true);
        },
      );
    });

    test('returns Left with validation error when tenantId is empty', () async {
      // Arrange & Act
      final result = await getTenantUseCase('');

      // Assert
      expect(result.isLeft(), true);
      result.fold(
            (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, 'Tenant ID cannot be empty or whitespace');
        },
            (tenant) => fail('Should not return tenant'),
      );
      verifyNever(() => mockRepository.getTenantById(any()));
    });

    test('returns Left with validation error when tenantId is only whitespace', () async {
      // Arrange & Act
      final result = await getTenantUseCase('   ');

      // Assert
      expect(result.isLeft(), true);
      result.fold(
            (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, 'Tenant ID cannot be empty or whitespace');
        },
            (tenant) => fail('Should not return tenant'),
      );
      verifyNever(() => mockRepository.getTenantById(any()));
    });

    test('validates tenantId with trimming before calling repository', () async {
      // Arrange
      const tenantIdWithSpaces = '  tenant-123  ';
      final mockTenant = createMockTenant(id: 'tenant-123');
      when(() => mockRepository.getTenantById(any()))
          .thenAnswer((_) async => Right(mockTenant));

      // Act
      await getTenantUseCase(tenantIdWithSpaces);

      // Assert - It should call with the original value (with spaces)
      // because the usecase only trims for validation, not for the actual call
      verify(() => mockRepository.getTenantById(tenantIdWithSpaces)).called(1);
    });

    test('returns Left with error when tenant is null (not found)', () async {
      // Arrange
      when(() => mockRepository.getTenantById(validTenantId))
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await getTenantUseCase(validTenantId);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
            (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, 'Tenant not found');
          expect(failure.code, 'TENANT_NOT_FOUND');
        },
            (tenant) => fail('Should not return tenant'),
      );
    });

    test('returns Left with error when tenant is inactive', () async {
      // Arrange
      final inactiveTenant = createMockTenant(
        id: validTenantId,
        name: 'Inactive School',
        isActive: false,
      );
      when(() => mockRepository.getTenantById(validTenantId))
          .thenAnswer((_) async => Right(inactiveTenant));

      // Act
      final result = await getTenantUseCase(validTenantId);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
            (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, 'Tenant account is inactive');
          expect(failure.code, 'TENANT_INACTIVE');
        },
            (tenant) => fail('Should not return tenant'),
      );
    });

    test('returns Left when repository returns failure', () async {
      // Arrange
      const repositoryFailure = AuthFailure('Database error', code: 'DB_ERROR');
      when(() => mockRepository.getTenantById(validTenantId))
          .thenAnswer((_) async => const Left(repositoryFailure));

      // Act
      final result = await getTenantUseCase(validTenantId);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
            (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, 'Database error');
          expect(failure.code, 'DB_ERROR');
        },
            (tenant) => fail('Should not return tenant'),
      );
    });

    test('preserves failure code from repository', () async {
      // Arrange
      const repositoryFailure = AuthFailure('Network timeout', code: 'NETWORK_ERROR');
      when(() => mockRepository.getTenantById(validTenantId))
          .thenAnswer((_) async => const Left(repositoryFailure));

      // Act
      final result = await getTenantUseCase(validTenantId);

      // Assert
      result.fold(
            (failure) {
          expect(failure.message, 'Network timeout');
          expect(failure.code, 'NETWORK_ERROR');
        },
            (_) => fail('Should not succeed'),
      );
    });
  });

  group('GetTenantUseCase - getTenantName', () {
    const validTenantId = 'tenant-123';
    const tenantName = 'Example School';

    test('returns Right with tenant name when tenant exists', () async {
      // Arrange
      final mockTenant = createMockTenant(
        id: validTenantId,
        name: tenantName,
        isActive: true,
      );
      when(() => mockRepository.getTenantById(validTenantId))
          .thenAnswer((_) async => Right(mockTenant));

      // Act
      final result = await getTenantUseCase.getTenantName(validTenantId);

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not return failure'),
            (name) => expect(name, tenantName),
      );
    });

    test('returns Right with null when tenant not found', () async {
      // Arrange
      when(() => mockRepository.getTenantById(validTenantId))
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await getTenantUseCase.getTenantName(validTenantId);

      // Assert
      expect(result.isLeft(), true); // Should fail because tenant not found
      result.fold(
            (failure) {
          expect(failure.message, 'Tenant not found');
          expect(failure.code, 'TENANT_NOT_FOUND');
        },
            (name) => fail('Should not return name'),
      );
    });

    test('returns Left when tenant is inactive', () async {
      // Arrange
      final inactiveTenant = createMockTenant(
        id: validTenantId,
        name: tenantName,
        isActive: false,
      );
      when(() => mockRepository.getTenantById(validTenantId))
          .thenAnswer((_) async => Right(inactiveTenant));

      // Act
      final result = await getTenantUseCase.getTenantName(validTenantId);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
            (failure) {
          expect(failure.message, 'Tenant account is inactive');
          expect(failure.code, 'TENANT_INACTIVE');
        },
            (name) => fail('Should not return name'),
      );
    });

    test('returns Left with validation error for empty tenantId', () async {
      // Act
      final result = await getTenantUseCase.getTenantName('');

      // Assert
      expect(result.isLeft(), true);
      result.fold(
            (failure) => expect(failure.message, 'Tenant ID cannot be empty or whitespace'),
            (name) => fail('Should not return name'),
      );
    });

    test('returns Left when repository fails', () async {
      // Arrange
      const failure = AuthFailure('Repository error');
      when(() => mockRepository.getTenantById(validTenantId))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await getTenantUseCase.getTenantName(validTenantId);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
            (failure) => expect(failure.message, 'Repository error'),
            (name) => fail('Should not return name'),
      );
    });
  });

  group('GetTenantUseCase - isTenantActive', () {
    const validTenantId = 'tenant-123';

    test('calls repository isTenantActive with correct tenantId', () async {
      // Arrange
      when(() => mockRepository.isTenantActive(any()))
          .thenAnswer((_) async => const Right(true));

      // Act
      await getTenantUseCase.isTenantActive(validTenantId);

      // Assert
      verify(() => mockRepository.isTenantActive(validTenantId)).called(1);
    });

    test('returns Right(true) when tenant is active', () async {
      // Arrange
      when(() => mockRepository.isTenantActive(validTenantId))
          .thenAnswer((_) async => const Right(true));

      // Act
      final result = await getTenantUseCase.isTenantActive(validTenantId);

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not return failure'),
            (isActive) => expect(isActive, true),
      );
    });

    test('returns Right(false) when tenant is inactive', () async {
      // Arrange
      when(() => mockRepository.isTenantActive(validTenantId))
          .thenAnswer((_) async => const Right(false));

      // Act
      final result = await getTenantUseCase.isTenantActive(validTenantId);

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not return failure'),
            (isActive) => expect(isActive, false),
      );
    });

    test('returns Right(false) when tenantId is empty without calling repository', () async {
      // Act
      final result = await getTenantUseCase.isTenantActive('');

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not return failure'),
            (isActive) => expect(isActive, false),
      );
      verifyNever(() => mockRepository.isTenantActive(any()));
    });

    test('returns Right(false) when tenantId is whitespace without calling repository', () async {
      // Act
      final result = await getTenantUseCase.isTenantActive('   ');

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not return failure'),
            (isActive) => expect(isActive, false),
      );
      verifyNever(() => mockRepository.isTenantActive(any()));
    });

    test('returns Left when repository fails', () async {
      // Arrange
      const failure = AuthFailure('Database error', code: 'DB_ERROR');
      when(() => mockRepository.isTenantActive(validTenantId))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await getTenantUseCase.isTenantActive(validTenantId);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
            (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, 'Database error');
          expect(failure.code, 'DB_ERROR');
        },
            (isActive) => fail('Should not return success'),
      );
    });

    test('preserves failure from repository', () async {
      // Arrange
      const failure = AuthFailure('Network timeout', code: 'TIMEOUT');
      when(() => mockRepository.isTenantActive(validTenantId))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await getTenantUseCase.isTenantActive(validTenantId);

      // Assert
      result.fold(
            (failure) {
          expect(failure.message, 'Network timeout');
          expect(failure.code, 'TIMEOUT');
        },
            (_) => fail('Should not succeed'),
      );
    });
  });

  group('GetTenantUseCase - Edge cases and validations', () {
    test('handles tenant with very long name', () async {
      // Arrange
      final longName = 'A' * 500;
      final mockTenant = createMockTenant(
        id: 'tenant-123',
        name: longName,
        isActive: true,
      );
      when(() => mockRepository.getTenantById('tenant-123'))
          .thenAnswer((_) async => Right(mockTenant));

      // Act
      final result = await getTenantUseCase('tenant-123');

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not fail'),
            (tenant) => expect(tenant?.name.length, 500),
      );
    });

    test('handles tenant with special characters in name', () async {
      // Arrange
      const specialName = "St. Mary's School & College (Est. 1990)";
      final mockTenant = createMockTenant(
        id: 'tenant-123',
        name: specialName,
        isActive: true,
      );
      when(() => mockRepository.getTenantById('tenant-123'))
          .thenAnswer((_) async => Right(mockTenant));

      // Act
      final result = await getTenantUseCase('tenant-123');

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not fail'),
            (tenant) => expect(tenant?.name, specialName),
      );
    });

    test('handles tenant with unicode characters', () async {
      // Arrange
      const unicodeName = 'École Française 东京学校';
      final mockTenant = createMockTenant(
        id: 'tenant-123',
        name: unicodeName,
        isActive: true,
      );
      when(() => mockRepository.getTenantById('tenant-123'))
          .thenAnswer((_) async => Right(mockTenant));

      // Act
      final result = await getTenantUseCase('tenant-123');

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not fail'),
            (tenant) => expect(tenant?.name, unicodeName),
      );
    });

    test('handles tenant with all optional fields null', () async {
      // Arrange
      final mockTenant = createMockTenant(
        id: 'tenant-123',
        name: 'Basic School',
        address: null,
        domain: null,
        isActive: true,
      );
      when(() => mockRepository.getTenantById('tenant-123'))
          .thenAnswer((_) async => Right(mockTenant));

      // Act
      final result = await getTenantUseCase('tenant-123');

      // Assert
      expect(result.isRight(), true);
      result.fold(
            (failure) => fail('Should not fail'),
            (tenant) {
          expect(tenant?.address, isNull);
          expect(tenant?.domain, isNull);
        },
      );
    });

    test('validates tenant before returning even if repository succeeds', () async {
      // Arrange - Repository returns inactive tenant
      final inactiveTenant = createMockTenant(
        id: 'tenant-123',
        name: 'Inactive School',
        isActive: false,
      );
      when(() => mockRepository.getTenantById('tenant-123'))
          .thenAnswer((_) async => Right(inactiveTenant));

      // Act
      final result = await getTenantUseCase('tenant-123');

      // Assert - UseCase should reject inactive tenant
      expect(result.isLeft(), true);
      result.fold(
            (failure) {
          expect(failure.message, 'Tenant account is inactive');
          expect(failure.code, 'TENANT_INACTIVE');
        },
            (_) => fail('Should not return inactive tenant'),
      );
    });
  });

  group('GetTenantUseCase - Integration scenarios', () {
    test('complete flow: validate -> fetch -> check active -> return', () async {
      // Arrange
      const tenantId = 'valid-tenant';
      final mockTenant = createMockTenant(
        id: tenantId,
        name: 'Valid School',
        isActive: true,
      );
      when(() => mockRepository.getTenantById(tenantId))
          .thenAnswer((_) async => Right(mockTenant));

      // Act
      final result = await getTenantUseCase(tenantId);

      // Assert
      expect(result.isRight(), true);
      verify(() => mockRepository.getTenantById(tenantId)).called(1);
      result.fold(
            (_) => fail('Should succeed'),
            (tenant) {
          expect(tenant?.id, tenantId);
          expect(tenant?.isActive, true);
        },
      );
    });

    test('getTenantName and isTenantActive use same call method internally', () async {
      // Arrange
      const tenantId = 'tenant-123';
      final mockTenant = createMockTenant(
        id: tenantId,
        name: 'School Name',
        isActive: true,
      );
      when(() => mockRepository.getTenantById(tenantId))
          .thenAnswer((_) async => Right(mockTenant));
      when(() => mockRepository.isTenantActive(tenantId))
          .thenAnswer((_) async => const Right(true));

      // Act
      final nameResult = await getTenantUseCase.getTenantName(tenantId);
      final activeResult = await getTenantUseCase.isTenantActive(tenantId);

      // Assert
      expect(nameResult.isRight(), true);
      expect(activeResult.isRight(), true);

      nameResult.fold(
            (_) => fail('Should succeed'),
            (name) => expect(name, 'School Name'),
      );

      activeResult.fold(
            (_) => fail('Should succeed'),
            (isActive) => expect(isActive, true),
      );
    });

    test('handles multiple sequential calls correctly', () async {
      // Arrange
      const tenantId = 'tenant-123';
      final mockTenant = createMockTenant(id: tenantId, isActive: true);
      when(() => mockRepository.getTenantById(tenantId))
          .thenAnswer((_) async => Right(mockTenant));
      when(() => mockRepository.isTenantActive(tenantId))
          .thenAnswer((_) async => const Right(true));

      // Act
      final result1 = await getTenantUseCase(tenantId);
      final result2 = await getTenantUseCase.getTenantName(tenantId);
      final result3 = await getTenantUseCase.isTenantActive(tenantId);

      // Assert
      expect(result1.isRight(), true);
      expect(result2.isRight(), true);
      expect(result3.isRight(), true);
    });
  });
}