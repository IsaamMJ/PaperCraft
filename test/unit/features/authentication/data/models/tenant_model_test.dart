import 'package:flutter_test/flutter_test.dart';
import 'package:papercraft/features/authentication/data/models/tenant_model.dart';
import 'package:papercraft/features/authentication/domain/entities/tenant_entity.dart';

void main() {
  group('TenantModel', () {
    const testId = 'tenant-123';
    const testName = 'Example School';
    const testAddress = '123 Main St, City, State';
    const testDomain = 'example.com';
    const testIsActive = true;
    const testIsInitialized = true;
    const testAcademicYear = '2024-2025';
    final testCreatedAt = DateTime(2024, 1, 1, 8, 0);

    final validJson = {
      'id': testId,
      'name': testName,
      'address': testAddress,
      'domain': testDomain,
      'is_active': testIsActive,
      'is_initialized': testIsInitialized,
      'current_academic_year': testAcademicYear,
      'created_at': testCreatedAt.toIso8601String(),
    };

    group('fromJson', () {
      test('creates TenantModel from valid JSON', () {
        // Act
        final model = TenantModel.fromJson(validJson);

        // Assert
        expect(model.id, testId);
        expect(model.name, testName);
        expect(model.address, testAddress);
        expect(model.domain, testDomain);
        expect(model.isActive, testIsActive);
        expect(model.isInitialized, testIsInitialized);
        expect(model.currentAcademicYear, testAcademicYear);
        expect(model.createdAt, testCreatedAt);
      });

      test('handles null address', () {
        // Arrange
        final jsonWithoutAddress = Map<String, dynamic>.from(validJson)
          ..remove('address');

        // Act
        final model = TenantModel.fromJson(jsonWithoutAddress);

        // Assert
        expect(model.address, isNull);
        expect(model.id, testId);
        expect(model.name, testName);
      });

      test('handles null domain', () {
        // Arrange
        final jsonWithoutDomain = Map<String, dynamic>.from(validJson)
          ..remove('domain');

        // Act
        final model = TenantModel.fromJson(jsonWithoutDomain);

        // Assert
        expect(model.domain, isNull);
      });

      test('defaults isActive to true when missing', () {
        // Arrange
        final json = Map<String, dynamic>.from(validJson)
          ..remove('is_active');

        // Act
        final model = TenantModel.fromJson(json);

        // Assert
        expect(model.isActive, true);
      });

      test('defaults isInitialized to false when missing', () {
        // Arrange
        final json = Map<String, dynamic>.from(validJson)
          ..remove('is_initialized');

        // Act
        final model = TenantModel.fromJson(json);

        // Assert
        expect(model.isInitialized, false);
      });

      test('defaults currentAcademicYear to 2024-2025 when missing', () {
        // Arrange
        final json = Map<String, dynamic>.from(validJson)
          ..remove('current_academic_year');

        // Act
        final model = TenantModel.fromJson(json);

        // Assert
        expect(model.currentAcademicYear, '2024-2025');
      });

      test('parses isActive as true when explicitly set', () {
        // Arrange
        final json = Map<String, dynamic>.from(validJson)
          ..['is_active'] = true;

        // Act
        final model = TenantModel.fromJson(json);

        // Assert
        expect(model.isActive, true);
      });

      test('parses isActive as false when explicitly set', () {
        // Arrange
        final json = Map<String, dynamic>.from(validJson)
          ..['is_active'] = false;

        // Act
        final model = TenantModel.fromJson(json);

        // Assert
        expect(model.isActive, false);
      });

      test('parses isInitialized as true when explicitly set', () {
        // Arrange
        final json = Map<String, dynamic>.from(validJson)
          ..['is_initialized'] = true;

        // Act
        final model = TenantModel.fromJson(json);

        // Assert
        expect(model.isInitialized, true);
      });

      test('parses different academic year formats', () {
        // Arrange
        final academicYears = ['2023-2024', '2024-2025', '2025-2026'];

        for (final year in academicYears) {
          final json = Map<String, dynamic>.from(validJson)
            ..['current_academic_year'] = year;

          // Act
          final model = TenantModel.fromJson(json);

          // Assert
          expect(model.currentAcademicYear, year);
        }
      });

      test('parses ISO8601 datetime strings correctly', () {
        // Arrange
        final specificDate = DateTime(2024, 6, 15, 14, 30, 45, 123);
        final json = Map<String, dynamic>.from(validJson)
          ..['created_at'] = specificDate.toIso8601String();

        // Act
        final model = TenantModel.fromJson(json);

        // Assert
        expect(model.createdAt.year, specificDate.year);
        expect(model.createdAt.month, specificDate.month);
        expect(model.createdAt.day, specificDate.day);
      });
    });

    group('toJson', () {
      test('converts TenantModel to valid JSON', () {
        // Arrange
        final model = TenantModel(
          id: testId,
          name: testName,
          address: testAddress,
          domain: testDomain,
          isActive: testIsActive,
          isInitialized: testIsInitialized,
          currentAcademicYear: testAcademicYear,
          createdAt: testCreatedAt,
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['id'], testId);
        expect(json['name'], testName);
        expect(json['address'], testAddress);
        expect(json['domain'], testDomain);
        expect(json['is_active'], testIsActive);
        expect(json['is_initialized'], testIsInitialized);
        expect(json['current_academic_year'], testAcademicYear);
        expect(json['created_at'], testCreatedAt.toIso8601String());
      });

      test('handles null address in toJson', () {
        // Arrange
        final model = TenantModel(
          id: testId,
          name: testName,
          address: null,
          domain: testDomain,
          isActive: testIsActive,
          isInitialized: testIsInitialized,
          currentAcademicYear: testAcademicYear,
          createdAt: testCreatedAt,
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['address'], isNull);
      });

      test('handles null domain in toJson', () {
        // Arrange
        final model = TenantModel(
          id: testId,
          name: testName,
          domain: null,
          isActive: testIsActive,
          isInitialized: testIsInitialized,
          currentAcademicYear: testAcademicYear,
          createdAt: testCreatedAt,
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['domain'], isNull);
      });

      test('includes all boolean flags correctly', () {
        // Arrange
        final model = TenantModel(
          id: testId,
          name: testName,
          isActive: false,
          isInitialized: true,
          currentAcademicYear: testAcademicYear,
          createdAt: testCreatedAt,
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['is_active'], false);
        expect(json['is_initialized'], true);
      });
    });

    group('toEntity', () {
      test('converts TenantModel to TenantEntity correctly', () {
        // Arrange
        final model = TenantModel(
          id: testId,
          name: testName,
          address: testAddress,
          domain: testDomain,
          isActive: testIsActive,
          isInitialized: testIsInitialized,
          currentAcademicYear: testAcademicYear,
          createdAt: testCreatedAt,
        );

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity, isA<TenantEntity>());
        expect(entity.id, testId);
        expect(entity.name, testName);
        expect(entity.address, testAddress);
        expect(entity.domain, testDomain);
        expect(entity.isActive, testIsActive);
        expect(entity.isInitialized, testIsInitialized);
        expect(entity.currentAcademicYear, testAcademicYear);
        expect(entity.createdAt, testCreatedAt);
      });

      test('preserves null values when converting to entity', () {
        // Arrange
        final model = TenantModel(
          id: testId,
          name: testName,
          address: null,
          domain: null,
          isActive: testIsActive,
          isInitialized: testIsInitialized,
          currentAcademicYear: testAcademicYear,
          createdAt: testCreatedAt,
        );

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity.address, isNull);
        expect(entity.domain, isNull);
      });

      test('entity methods work correctly after conversion', () {
        // Arrange
        final model = TenantModel(
          id: testId,
          name: 'Very Long School Name That Exceeds Twenty Characters',
          isActive: testIsActive,
          isInitialized: testIsInitialized,
          currentAcademicYear: testAcademicYear,
          createdAt: testCreatedAt,
        );

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity.displayName, entity.name);
        expect(entity.shortName.length, lessThanOrEqualTo(20));
        expect(entity.shortName.endsWith('...'), true);
      });
    });

    group('fromEntity', () {
      test('creates TenantModel from TenantEntity', () {
        // Arrange
        final entity = TenantEntity(
          id: testId,
          name: testName,
          address: testAddress,
          domain: testDomain,
          isActive: testIsActive,
          isInitialized: testIsInitialized,
          currentAcademicYear: testAcademicYear,
          createdAt: testCreatedAt,
        );

        // Act
        final model = TenantModel.fromEntity(entity);

        // Assert
        expect(model.id, entity.id);
        expect(model.name, entity.name);
        expect(model.address, entity.address);
        expect(model.domain, entity.domain);
        expect(model.isActive, entity.isActive);
        expect(model.isInitialized, entity.isInitialized);
        expect(model.currentAcademicYear, entity.currentAcademicYear);
        expect(model.createdAt, entity.createdAt);
      });

      test('preserves null values from entity', () {
        // Arrange
        final entity = TenantEntity(
          id: testId,
          name: testName,
          address: null,
          domain: null,
          isActive: testIsActive,
          isInitialized: testIsInitialized,
          currentAcademicYear: testAcademicYear,
          createdAt: testCreatedAt,
        );

        // Act
        final model = TenantModel.fromEntity(entity);

        // Assert
        expect(model.address, isNull);
        expect(model.domain, isNull);
      });
    });

    group('Serialization round-trip', () {
      test('fromJson -> toJson produces same data', () {
        // Arrange
        final originalJson = validJson;

        // Act
        final model = TenantModel.fromJson(originalJson);
        final resultJson = model.toJson();

        // Assert
        expect(resultJson['id'], originalJson['id']);
        expect(resultJson['name'], originalJson['name']);
        expect(resultJson['address'], originalJson['address']);
        expect(resultJson['domain'], originalJson['domain']);
        expect(resultJson['is_active'], originalJson['is_active']);
        expect(resultJson['is_initialized'], originalJson['is_initialized']);
        expect(resultJson['current_academic_year'], originalJson['current_academic_year']);
        expect(resultJson['created_at'], originalJson['created_at']);
      });

      test('fromJson -> toEntity -> fromEntity -> toJson round-trip', () {
        // Arrange
        final originalJson = validJson;

        // Act
        final model1 = TenantModel.fromJson(originalJson);
        final entity = model1.toEntity();
        final model2 = TenantModel.fromEntity(entity);
        final resultJson = model2.toJson();

        // Assert - All data preserved
        expect(resultJson['id'], originalJson['id']);
        expect(resultJson['name'], originalJson['name']);
        expect(resultJson['address'], originalJson['address']);
        expect(resultJson['current_academic_year'], originalJson['current_academic_year']);
      });
    });

    group('Edge cases', () {
      test('handles very long tenant name', () {
        // Arrange
        final longName = 'A' * 200;
        final json = Map<String, dynamic>.from(validJson)
          ..['name'] = longName;

        // Act
        final model = TenantModel.fromJson(json);

        // Assert
        expect(model.name, longName);
        expect(model.name.length, 200);
      });

      test('handles special characters in name', () {
        // Arrange
        const specialName = "St. Mary's School & College (Est. 1990)";
        final json = Map<String, dynamic>.from(validJson)
          ..['name'] = specialName;

        // Act
        final model = TenantModel.fromJson(json);

        // Assert
        expect(model.name, specialName);
      });

      test('handles unicode characters in name', () {
        // Arrange
        const unicodeName = 'École Française à Tokyo 东京学校';
        final json = Map<String, dynamic>.from(validJson)
          ..['name'] = unicodeName;

        // Act
        final model = TenantModel.fromJson(json);

        // Assert
        expect(model.name, unicodeName);
      });

      test('handles very long address', () {
        // Arrange
        final longAddress = 'Building Name, Floor 5, ' * 10;
        final json = Map<String, dynamic>.from(validJson)
          ..['address'] = longAddress;

        // Act
        final model = TenantModel.fromJson(json);

        // Assert
        expect(model.address, longAddress);
      });

      test('handles domain with subdomain', () {
        // Arrange
        const subDomain = 'school.district.edu';
        final json = Map<String, dynamic>.from(validJson)
          ..['domain'] = subDomain;

        // Act
        final model = TenantModel.fromJson(json);

        // Assert
        expect(model.domain, subDomain);
      });

      test('handles future created_at dates', () {
        // Arrange
        final futureDate = DateTime(2030, 12, 31);
        final json = Map<String, dynamic>.from(validJson)
          ..['created_at'] = futureDate.toIso8601String();

        // Act
        final model = TenantModel.fromJson(json);

        // Assert
        expect(model.createdAt.isAfter(DateTime.now()), true);
      });

      test('handles old created_at dates', () {
        // Arrange
        final oldDate = DateTime(2000, 1, 1);
        final json = Map<String, dynamic>.from(validJson)
          ..['created_at'] = oldDate.toIso8601String();

        // Act
        final model = TenantModel.fromJson(json);

        // Assert
        expect(model.createdAt.year, 2000);
      });

      test('handles inactive tenant', () {
        // Arrange
        final json = Map<String, dynamic>.from(validJson)
          ..['is_active'] = false;

        // Act
        final model = TenantModel.fromJson(json);
        final entity = model.toEntity();

        // Assert
        expect(model.isActive, false);
        expect(entity.isActive, false);
      });

      test('handles uninitialized tenant', () {
        // Arrange
        final json = Map<String, dynamic>.from(validJson)
          ..['is_initialized'] = false;

        // Act
        final model = TenantModel.fromJson(json);
        final entity = model.toEntity();

        // Assert
        expect(model.isInitialized, false);
        expect(entity.isInitialized, false);
      });
    });

    group('TenantEntity business logic via model', () {
      test('displayName returns name correctly', () {
        // Arrange
        final model = TenantModel(
          id: testId,
          name: testName,
          isActive: testIsActive,
          isInitialized: testIsInitialized,
          currentAcademicYear: testAcademicYear,
          createdAt: testCreatedAt,
        );

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity.displayName, testName);
      });

      test('shortName truncates long names correctly', () {
        // Arrange
        const longName = 'This is a very long school name that should be truncated';
        final model = TenantModel(
          id: testId,
          name: longName,
          isActive: testIsActive,
          isInitialized: testIsInitialized,
          currentAcademicYear: testAcademicYear,
          createdAt: testCreatedAt,
        );

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity.shortName.length, lessThanOrEqualTo(20));
        expect(entity.shortName.endsWith('...'), true);
      });

      test('shortName does not truncate short names', () {
        // Arrange
        const shortName = 'Short School';
        final model = TenantModel(
          id: testId,
          name: shortName,
          isActive: testIsActive,
          isInitialized: testIsInitialized,
          currentAcademicYear: testAcademicYear,
          createdAt: testCreatedAt,
        );

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity.shortName, shortName);
        expect(entity.shortName.endsWith('...'), false);
      });
    });
  });
}