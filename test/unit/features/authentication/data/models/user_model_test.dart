import 'package:flutter_test/flutter_test.dart';
import 'package:papercraft/features/authentication/data/models/user_model.dart';
import 'package:papercraft/features/authentication/domain/entities/user_entity.dart';
import 'package:papercraft/features/authentication/domain/entities/user_role.dart';

// Test file location: test/unit/features/authentication/data/models/user_model_test.dart

void main() {
  group('UserModel', () {
    const testId = 'test-user-123';
    const testEmail = 'test@example.com';
    const testFullName = 'Test User';
    const testTenantId = 'tenant-123';
    const testRole = 'teacher';
    const testIsActive = true;
    final testLastLoginAt = DateTime(2024, 1, 15, 10, 30);
    final testCreatedAt = DateTime(2024, 1, 1, 8, 0);

    final validJson = {
      'id': testId,
      'email': testEmail,
      'full_name': testFullName,
      'tenant_id': testTenantId,
      'role': testRole,
      'is_active': testIsActive,
      'last_login_at': testLastLoginAt.toIso8601String(),
      'created_at': testCreatedAt.toIso8601String(),
    };

    group('fromJson', () {
      test('creates UserModel from valid JSON', () {
        // Act
        final model = UserModel.fromJson(validJson);

        // Assert
        expect(model.id, testId);
        expect(model.email, testEmail);
        expect(model.fullName, testFullName);
        expect(model.tenantId, testTenantId);
        expect(model.role, testRole);
        expect(model.isActive, testIsActive);
        expect(model.lastLoginAt, testLastLoginAt);
        expect(model.createdAt, testCreatedAt);
      });

      test('handles null lastLoginAt', () {
        // Arrange
        final jsonWithoutLastLogin = Map<String, dynamic>.from(validJson)
          ..remove('last_login_at');

        // Act
        final model = UserModel.fromJson(jsonWithoutLastLogin);

        // Assert
        expect(model.lastLoginAt, isNull);
        expect(model.id, testId);
        expect(model.email, testEmail);
      });

      test('handles null tenantId', () {
        // Arrange
        final jsonWithoutTenant = Map<String, dynamic>.from(validJson)
          ..remove('tenant_id');

        // Act
        final model = UserModel.fromJson(jsonWithoutTenant);

        // Assert
        expect(model.tenantId, isNull);
        expect(model.id, testId);
      });

      test('handles empty full_name with fallback', () {
        // Arrange
        final jsonWithEmptyName = Map<String, dynamic>.from(validJson)
          ..['full_name'] = null;

        // Act
        final model = UserModel.fromJson(jsonWithEmptyName);

        // Assert
        expect(model.fullName, '');
      });

      test('parses isActive as true when present', () {
        // Arrange
        final json = Map<String, dynamic>.from(validJson)..['is_active'] = true;

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.isActive, true);
      });

      test('parses isActive as false when present', () {
        // Arrange
        final json = Map<String, dynamic>.from(validJson)..['is_active'] = false;

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.isActive, false);
      });

      test('handles different role values', () {
        // Arrange
        final roles = ['admin', 'teacher', 'blocked'];

        for (final role in roles) {
          final json = Map<String, dynamic>.from(validJson)..['role'] = role;

          // Act
          final model = UserModel.fromJson(json);

          // Assert
          expect(model.role, role, reason: 'Failed for role: $role');
        }
      });

      test('parses ISO8601 datetime strings correctly', () {
        // Arrange
        final specificDate = DateTime(2024, 6, 15, 14, 30, 45, 123);
        final json = Map<String, dynamic>.from(validJson)
          ..['created_at'] = specificDate.toIso8601String()
          ..['last_login_at'] = specificDate.toIso8601String();

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.createdAt.year, specificDate.year);
        expect(model.createdAt.month, specificDate.month);
        expect(model.createdAt.day, specificDate.day);
        expect(model.lastLoginAt?.year, specificDate.year);
      });
    });

    group('toJson', () {
      test('converts UserModel to valid JSON', () {
        // Arrange
        final model = UserModel(
          id: testId,
          email: testEmail,
          fullName: testFullName,
          tenantId: testTenantId,
          role: testRole,
          isActive: testIsActive,
          lastLoginAt: testLastLoginAt,
          createdAt: testCreatedAt,
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['id'], testId);
        expect(json['email'], testEmail);
        expect(json['full_name'], testFullName);
        expect(json['tenant_id'], testTenantId);
        expect(json['role'], testRole);
        expect(json['is_active'], testIsActive);
        expect(json['last_login_at'], testLastLoginAt.toIso8601String());
        expect(json['created_at'], testCreatedAt.toIso8601String());
      });

      test('handles null lastLoginAt in toJson', () {
        // Arrange
        final model = UserModel(
          id: testId,
          email: testEmail,
          fullName: testFullName,
          tenantId: testTenantId,
          role: testRole,
          isActive: testIsActive,
          lastLoginAt: null,
          createdAt: testCreatedAt,
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['last_login_at'], isNull);
      });

      test('handles null tenantId in toJson', () {
        // Arrange
        final model = UserModel(
          id: testId,
          email: testEmail,
          fullName: testFullName,
          tenantId: null,
          role: testRole,
          isActive: testIsActive,
          createdAt: testCreatedAt,
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['tenant_id'], isNull);
      });
    });

    group('toEntity', () {
      test('converts UserModel to UserEntity correctly', () {
        // Arrange
        final model = UserModel(
          id: testId,
          email: testEmail,
          fullName: testFullName,
          tenantId: testTenantId,
          role: testRole,
          isActive: testIsActive,
          lastLoginAt: testLastLoginAt,
          createdAt: testCreatedAt,
        );

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity, isA<UserEntity>());
        expect(entity.id, testId);
        expect(entity.email, testEmail);
        expect(entity.fullName, testFullName);
        expect(entity.tenantId, testTenantId);
        expect(entity.role, UserRole.fromString(testRole));
        expect(entity.isActive, testIsActive);
        expect(entity.lastLoginAt, testLastLoginAt);
        expect(entity.createdAt, testCreatedAt);
      });

      test('converts role string to UserRole enum correctly', () {
        // Arrange
        final adminModel = UserModel(
          id: testId,
          email: testEmail,
          fullName: testFullName,
          role: 'admin',
          isActive: true,
          createdAt: testCreatedAt,
        );

        // Act
        final entity = adminModel.toEntity();

        // Assert
        expect(entity.role, UserRole.admin);
        expect(entity.isAdmin, true);
      });

      test('preserves null values when converting to entity', () {
        // Arrange
        final model = UserModel(
          id: testId,
          email: testEmail,
          fullName: testFullName,
          tenantId: null,
          role: testRole,
          isActive: testIsActive,
          lastLoginAt: null,
          createdAt: testCreatedAt,
        );

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity.tenantId, isNull);
        expect(entity.lastLoginAt, isNull);
      });
    });

    group('Serialization round-trip', () {
      test('fromJson -> toJson produces same data', () {
        // Arrange
        final originalJson = validJson;

        // Act
        final model = UserModel.fromJson(originalJson);
        final resultJson = model.toJson();

        // Assert
        expect(resultJson['id'], originalJson['id']);
        expect(resultJson['email'], originalJson['email']);
        expect(resultJson['full_name'], originalJson['full_name']);
        expect(resultJson['tenant_id'], originalJson['tenant_id']);
        expect(resultJson['role'], originalJson['role']);
        expect(resultJson['is_active'], originalJson['is_active']);
        expect(resultJson['created_at'], originalJson['created_at']);
        expect(resultJson['last_login_at'], originalJson['last_login_at']);
      });

      test('fromJson -> toEntity -> business logic works', () {
        // Arrange
        final teacherJson = Map<String, dynamic>.from(validJson)
          ..['role'] = 'teacher'
          ..['is_active'] = true;

        // Act
        final model = UserModel.fromJson(teacherJson);
        final entity = model.toEntity();

        // Assert
        expect(entity.canCreatePapers, true);
        expect(entity.canManageUsers, false);
        expect(entity.isValid, true);
      });
    });

    group('Edge cases', () {
      test('handles user with empty email gracefully', () {
        // Arrange
        final json = Map<String, dynamic>.from(validJson)..['email'] = '';

        // Act
        final model = UserModel.fromJson(json);
        final entity = model.toEntity();

        // Assert
        expect(model.email, '');
        expect(entity.email, '');
      });

      test('handles very long fullName', () {
        // Arrange
        final longName = 'A' * 200;
        final json = Map<String, dynamic>.from(validJson)
          ..['full_name'] = longName;

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.fullName, longName);
        expect(model.fullName.length, 200);
      });

      test('handles special characters in fullName', () {
        // Arrange
        final specialName = "O'Brien-Smith (Jr.) & Co.";
        final json = Map<String, dynamic>.from(validJson)
          ..['full_name'] = specialName;

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.fullName, specialName);
      });

      test('handles future dates correctly', () {
        // Arrange
        final futureDate = DateTime(2030, 12, 31);
        final json = Map<String, dynamic>.from(validJson)
          ..['created_at'] = futureDate.toIso8601String();

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.createdAt.isAfter(DateTime.now()), true);
      });

      test('handles old dates correctly', () {
        // Arrange
        final oldDate = DateTime(2000, 1, 1);
        final json = Map<String, dynamic>.from(validJson)
          ..['created_at'] = oldDate.toIso8601String();

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.createdAt.year, 2000);
      });
    });
  });
}