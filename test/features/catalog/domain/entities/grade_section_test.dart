import 'package:flutter_test/flutter_test.dart';
import 'package:papercraft/features/catalog/domain/entities/grade_section.dart';

void main() {
  group('GradeSection', () {
    final now = DateTime.now();

    final testGradeSection = GradeSection(
      id: 'test-id',
      tenantId: 'tenant-123',
      gradeId: 'Grade 5',
      sectionName: 'A',
      displayOrder: 1,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    test('should create GradeSection with correct properties', () {
      expect(testGradeSection.id, equals('test-id'));
      expect(testGradeSection.tenantId, equals('tenant-123'));
      expect(testGradeSection.gradeId, equals('Grade 5'));
      expect(testGradeSection.sectionName, equals('A'));
      expect(testGradeSection.displayOrder, equals(1));
      expect(testGradeSection.isActive, equals(true));
    });

    test('should serialize to JSON correctly', () {
      final json = testGradeSection.toJson();

      expect(json['id'], equals('test-id'));
      expect(json['tenant_id'], equals('tenant-123'));
      expect(json['grade_id'], equals('Grade 5'));
      expect(json['section_name'], equals('A'));
      expect(json['display_order'], equals(1));
      expect(json['is_active'], equals(true));
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'id': 'test-id',
        'tenant_id': 'tenant-123',
        'grade_id': 'Grade 5',
        'section_name': 'A',
        'display_order': 1,
        'is_active': true,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final section = GradeSection.fromJson(json);

      expect(section.id, equals('test-id'));
      expect(section.tenantId, equals('tenant-123'));
      expect(section.gradeId, equals('Grade 5'));
      expect(section.sectionName, equals('A'));
      expect(section.displayOrder, equals(1));
      expect(section.isActive, equals(true));
    });

    test('should support equality comparison', () {
      final section1 = GradeSection(
        id: 'test-id',
        tenantId: 'tenant-123',
        gradeId: 'Grade 5',
        sectionName: 'A',
        displayOrder: 1,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final section2 = GradeSection(
        id: 'test-id',
        tenantId: 'tenant-123',
        gradeId: 'Grade 5',
        sectionName: 'A',
        displayOrder: 1,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(section1, equals(section2));
    });

    test('should support copyWith', () {
      final updated = testGradeSection.copyWith(sectionName: 'B');

      expect(updated.sectionName, equals('B'));
      expect(updated.id, equals(testGradeSection.id));
      expect(updated.gradeId, equals(testGradeSection.gradeId));
    });

    test('should have correct toString representation', () {
      final string = testGradeSection.toString();

      expect(string, contains('GradeSection'));
      expect(string, contains('Grade 5'));
      expect(string, contains('A'));
    });
  });
}
