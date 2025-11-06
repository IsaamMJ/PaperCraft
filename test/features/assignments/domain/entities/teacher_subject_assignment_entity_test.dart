import 'package:flutter_test/flutter_test.dart';
import 'package:papercraft/features/assignments/domain/entities/teacher_subject_assignment_entity.dart';

void main() {
  group('TeacherSubjectAssignmentEntity', () {
    const testEntity = TeacherSubjectAssignmentEntity(
      id: 'assignment-1',
      tenantId: 'tenant-1',
      teacherId: 'teacher-1',
      gradeId: 'grade-9',
      subjectId: 'subject-1',
      teacherName: 'John Doe',
      teacherEmail: 'john@example.com',
      gradeNumber: 9,
      section: 'A',
      subjectName: 'Mathematics',
      academicYear: '2025-2026',
      startDate: null,
      endDate: null,
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 5),
    );

    group('copyWith', () {
      test('should create copy with modified id', () {
        final result = testEntity.copyWith(id: 'new-id');
        expect(result.id, 'new-id');
        expect(result.teacherId, testEntity.teacherId);
      });

      test('should create copy with modified gradeNumber', () {
        final result = testEntity.copyWith(gradeNumber: 10);
        expect(result.gradeNumber, 10);
      });

      test('should preserve other fields when copying', () {
        final result = testEntity.copyWith(section: 'B');
        expect(result.section, 'B');
        expect(result.teacherName, 'John Doe');
        expect(result.id, 'assignment-1');
      });
    });

    group('Getters', () {
      test('gradeSection returns grade:section composite key', () {
        expect(testEntity.gradeSection, '9:A');
      });

      test('isValid returns true with all required fields', () {
        expect(testEntity.isValid, true);
      });

      test('isValid returns false without gradeNumber', () {
        expect(testEntity.copyWith(gradeNumber: null).isValid, false);
      });

      test('isValid returns false without section', () {
        expect(testEntity.copyWith(section: null).isValid, false);
      });

      test('isValid returns false without subjectName', () {
        expect(testEntity.copyWith(subjectName: null).isValid, false);
      });
    });

    group('Equality', () {
      test('equal entities have same values', () {
        const entity1 = TeacherSubjectAssignmentEntity(
          id: 'a1', tenantId: 't1', teacherId: 'tr1', gradeId: 'g9',
          subjectId: 's1', teacherName: 'John', teacherEmail: 'john@test.com',
          gradeNumber: 9, section: 'A', subjectName: 'Math',
          academicYear: '2025-2026', startDate: null, endDate: null,
          isActive: true, createdAt: DateTime(2025, 1, 1), updatedAt: DateTime(2025, 1, 5),
        );

        const entity2 = TeacherSubjectAssignmentEntity(
          id: 'a1', tenantId: 't1', teacherId: 'tr1', gradeId: 'g9',
          subjectId: 's1', teacherName: 'John', teacherEmail: 'john@test.com',
          gradeNumber: 9, section: 'A', subjectName: 'Math',
          academicYear: '2025-2026', startDate: null, endDate: null,
          isActive: true, createdAt: DateTime(2025, 1, 1), updatedAt: DateTime(2025, 1, 5),
        );

        expect(entity1, entity2);
      });

      test('different entities are not equal', () {
        expect(testEntity != testEntity.copyWith(id: 'new-id'), true);
      });
    });

    test('toString includes key information', () {
      final str = testEntity.toString();
      expect(str, contains('John Doe'));
      expect(str, contains('Mathematics'));
    });
  });
}
