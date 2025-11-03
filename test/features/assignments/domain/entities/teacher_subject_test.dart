import 'package:flutter_test/flutter_test.dart';
import 'package:papercraft/features/assignments/domain/entities/teacher_subject.dart';

void main() {
  group('TeacherSubject', () {
    final now = DateTime.now();

    final testTeacherSubject = TeacherSubject(
      id: 'teacher-subject-1',
      tenantId: 'tenant-123',
      teacherId: 'teacher-1',
      gradeId: 'Grade 5',
      subjectId: 'Maths',
      section: 'A',
      academicYear: '2024-2025',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    test('should create TeacherSubject with correct properties', () {
      expect(testTeacherSubject.id, equals('teacher-subject-1'));
      expect(testTeacherSubject.tenantId, equals('tenant-123'));
      expect(testTeacherSubject.teacherId, equals('teacher-1'));
      expect(testTeacherSubject.gradeId, equals('Grade 5'));
      expect(testTeacherSubject.subjectId, equals('Maths'));
      expect(testTeacherSubject.section, equals('A'));
      expect(testTeacherSubject.academicYear, equals('2024-2025'));
      expect(testTeacherSubject.isActive, equals(true));
    });

    test('should compute displayName correctly', () {
      expect(testTeacherSubject.displayName, equals('Grade 5-A Maths'));
    });

    test('should compute displayName with different section', () {
      final subject = testTeacherSubject.copyWith(section: 'C');
      expect(subject.displayName, equals('Grade 5-C Maths'));
    });

    test('should serialize to JSON correctly', () {
      final json = testTeacherSubject.toJson();

      expect(json['id'], equals('teacher-subject-1'));
      expect(json['tenant_id'], equals('tenant-123'));
      expect(json['teacher_id'], equals('teacher-1'));
      expect(json['grade_id'], equals('Grade 5'));
      expect(json['subject_id'], equals('Maths'));
      expect(json['section'], equals('A'));
      expect(json['academic_year'], equals('2024-2025'));
      expect(json['is_active'], equals(true));
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'id': 'teacher-subject-1',
        'tenant_id': 'tenant-123',
        'teacher_id': 'teacher-1',
        'grade_id': 'Grade 5',
        'subject_id': 'Maths',
        'section': 'A',
        'academic_year': '2024-2025',
        'is_active': true,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final subject = TeacherSubject.fromJson(json);

      expect(subject.id, equals('teacher-subject-1'));
      expect(subject.teacherId, equals('teacher-1'));
      expect(subject.gradeId, equals('Grade 5'));
      expect(subject.subjectId, equals('Maths'));
      expect(subject.section, equals('A'));
      expect(subject.academicYear, equals('2024-2025'));
    });

    test('should handle JSON round-trip serialization', () {
      final json = testTeacherSubject.toJson();
      final subject = TeacherSubject.fromJson(json);

      expect(subject, equals(testTeacherSubject));
    });

    test('should support equality comparison', () {
      final subject1 = TeacherSubject(
        id: 'teacher-subject-1',
        tenantId: 'tenant-123',
        teacherId: 'teacher-1',
        gradeId: 'Grade 5',
        subjectId: 'Maths',
        section: 'A',
        academicYear: '2024-2025',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final subject2 = TeacherSubject(
        id: 'teacher-subject-1',
        tenantId: 'tenant-123',
        teacherId: 'teacher-1',
        gradeId: 'Grade 5',
        subjectId: 'Maths',
        section: 'A',
        academicYear: '2024-2025',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(subject1, equals(subject2));
    });

    test('should support copyWith', () {
      final updated = testTeacherSubject.copyWith(
        subjectId: 'English',
        section: 'B',
      );

      expect(updated.subjectId, equals('English'));
      expect(updated.section, equals('B'));
      expect(updated.teacherId, equals(testTeacherSubject.teacherId));
      expect(updated.gradeId, equals(testTeacherSubject.gradeId));
    });

    test('should have correct toString representation', () {
      final string = testTeacherSubject.toString();

      expect(string, contains('TeacherSubject'));
      expect(string, contains('teacher-1'));
      expect(string, contains('Grade 5-A Maths'));
      expect(string, contains('2024-2025'));
    });

    test('should handle deactivation via copyWith', () {
      final inactive = testTeacherSubject.copyWith(isActive: false);

      expect(inactive.isActive, equals(false));
      expect(inactive.id, equals(testTeacherSubject.id));
    });
  });
}
