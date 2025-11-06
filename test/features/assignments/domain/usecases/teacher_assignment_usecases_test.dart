import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/features/assignments/domain/entities/teacher_subject_assignment_entity.dart';
import 'package:papercraft/features/assignments/domain/repositories/teacher_assignment_repository.dart';
import 'package:papercraft/features/assignments/domain/usecases/delete_teacher_assignment_usecase.dart';
import 'package:papercraft/features/assignments/domain/usecases/get_assignment_stats_usecase.dart';
import 'package:papercraft/features/assignments/domain/usecases/load_teacher_assignments_usecase.dart';
import 'package:papercraft/features/assignments/domain/usecases/save_teacher_assignment_usecase.dart';

class MockTeacherAssignmentRepository extends Mock
    implements TeacherAssignmentRepository {}

class FakeTeacherSubjectAssignmentEntity extends Fake
    implements TeacherSubjectAssignmentEntity {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeTeacherSubjectAssignmentEntity());
  });

  final now = DateTime(2025, 1, 15, 10, 30, 0);

  final testAssignment = TeacherSubjectAssignmentEntity(
    id: 'assign-123',
    tenantId: 'tenant-456',
    teacherId: 'teacher-789',
    gradeId: 'grade-101',
    subjectId: 'subject-202',
    teacherName: 'John Doe',
    teacherEmail: 'john@school.com',
    gradeNumber: 2,
    section: 'A',
    subjectName: 'Mathematics',
    academicYear: '2025-2026',
    isActive: true,
    createdAt: now,
  );

  group('LoadTeacherAssignmentsUseCase', () {
    test('returns assignments when repository succeeds', () async {
      final mock = MockTeacherAssignmentRepository();
      final useCase = LoadTeacherAssignmentsUseCase(repository: mock);

      when(() => mock.getTeacherAssignments(
        tenantId: 'tenant-456',
        teacherId: null,
        academicYear: '2025-2026',
        activeOnly: true,
      )).thenAnswer((_) async => Right([testAssignment]));

      final result = await useCase(tenantId: 'tenant-456');

      expect(result.isRight(), true);
      expect(result.fold((f) => -1, (a) => a.length), 1);
    });

    test('filters by teacherId when provided', () async {
      final mock = MockTeacherAssignmentRepository();
      final useCase = LoadTeacherAssignmentsUseCase(repository: mock);

      when(() => mock.getTeacherAssignments(
        tenantId: 'tenant-456',
        teacherId: 'specific-teacher',
        academicYear: '2025-2026',
        activeOnly: true,
      )).thenAnswer((_) async => Right([testAssignment]));

      final result = await useCase(
        tenantId: 'tenant-456',
        teacherId: 'specific-teacher',
      );

      expect(result.isRight(), true);
      verify(() => mock.getTeacherAssignments(
        tenantId: 'tenant-456',
        teacherId: 'specific-teacher',
        academicYear: '2025-2026',
        activeOnly: true,
      )).called(1);
    });

    test('uses provided academicYear', () async {
      final mock = MockTeacherAssignmentRepository();
      final useCase = LoadTeacherAssignmentsUseCase(repository: mock);

      when(() => mock.getTeacherAssignments(
        tenantId: 'tenant-456',
        teacherId: null,
        academicYear: '2026-2027',
        activeOnly: true,
      )).thenAnswer((_) async => const Right([]));

      await useCase(
        tenantId: 'tenant-456',
        academicYear: '2026-2027',
      );

      verify(() => mock.getTeacherAssignments(
        tenantId: 'tenant-456',
        teacherId: null,
        academicYear: '2026-2027',
        activeOnly: true,
      )).called(1);
    });

    test('returns failure when repository fails', () async {
      final mock = MockTeacherAssignmentRepository();
      final useCase = LoadTeacherAssignmentsUseCase(repository: mock);

      when(() => mock.getTeacherAssignments(
        tenantId: 'tenant-456',
        teacherId: null,
        academicYear: '2025-2026',
        activeOnly: true,
      )).thenAnswer((_) async => Left(ServerFailure('Database error')));

      final result = await useCase(tenantId: 'tenant-456');

      expect(result.isLeft(), true);
      expect(result.fold((f) => f.runtimeType, (a) => null), ServerFailure);
    });

    test('returns empty list when no assignments', () async {
      final mock = MockTeacherAssignmentRepository();
      final useCase = LoadTeacherAssignmentsUseCase(repository: mock);

      when(() => mock.getTeacherAssignments(
        tenantId: 'tenant-456',
        teacherId: null,
        academicYear: '2025-2026',
        activeOnly: true,
      )).thenAnswer((_) async => const Right([]));

      final result = await useCase(tenantId: 'tenant-456');

      expect(result.isRight(), true);
      expect(result.fold((f) => -1, (a) => a.length), 0);
    });
  });

  group('SaveTeacherAssignmentUseCase', () {
    test('saves assignment when repository succeeds', () async {
      final mock = MockTeacherAssignmentRepository();
      final useCase = SaveTeacherAssignmentUseCase(repository: mock);

      when(() => mock.saveAssignment(testAssignment))
          .thenAnswer((_) async => const Right(null));

      final result = await useCase(testAssignment);

      expect(result.isRight(), true);
      verify(() => mock.saveAssignment(testAssignment)).called(1);
    });

    test('passes assignment to repository', () async {
      final mock = MockTeacherAssignmentRepository();
      final useCase = SaveTeacherAssignmentUseCase(repository: mock);

      final updatedAssignment = testAssignment.copyWith(
        subjectName: 'Science',
      );

      when(() => mock.saveAssignment(any()))
          .thenAnswer((_) async => const Right(null));

      await useCase(updatedAssignment);

      verify(() => mock.saveAssignment(updatedAssignment)).called(1);
    });

    test('returns failure when repository fails', () async {
      final mock = MockTeacherAssignmentRepository();
      final useCase = SaveTeacherAssignmentUseCase(repository: mock);

      when(() => mock.saveAssignment(any())).thenAnswer((_) async =>
          Left(ValidationFailure('Assignment validation failed')));

      final result = await useCase(testAssignment);

      expect(result.isLeft(), true);
      expect(result.fold((f) => f.runtimeType, (u) => null), ValidationFailure);
    });

    test('handles server errors from repository', () async {
      final mock = MockTeacherAssignmentRepository();
      final useCase = SaveTeacherAssignmentUseCase(repository: mock);

      when(() => mock.saveAssignment(any())).thenAnswer((_) async =>
          Left(ServerFailure('Database connection error')));

      final result = await useCase(testAssignment);

      expect(result.isLeft(), true);
      expect(result.fold((f) => f.runtimeType, (u) => null), ServerFailure);
    });
  });

  group('DeleteTeacherAssignmentUseCase', () {
    test('deletes assignment when repository succeeds', () async {
      final mock = MockTeacherAssignmentRepository();
      final useCase = DeleteTeacherAssignmentUseCase(repository: mock);

      when(() => mock.deleteAssignment('assign-123'))
          .thenAnswer((_) async => const Right(null));

      final result = await useCase('assign-123');

      expect(result.isRight(), true);
      verify(() => mock.deleteAssignment('assign-123')).called(1);
    });

    test('passes assignmentId to repository', () async {
      final mock = MockTeacherAssignmentRepository();
      final useCase = DeleteTeacherAssignmentUseCase(repository: mock);

      when(() => mock.deleteAssignment(any()))
          .thenAnswer((_) async => const Right(null));

      await useCase('specific-assignment-id');

      verify(() => mock.deleteAssignment('specific-assignment-id')).called(1);
    });

    test('returns failure when repository fails', () async {
      final mock = MockTeacherAssignmentRepository();
      final useCase = DeleteTeacherAssignmentUseCase(repository: mock);

      when(() => mock.deleteAssignment(any())).thenAnswer((_) async =>
          Left(ServerFailure('Delete failed')));

      final result = await useCase('assign-123');

      expect(result.isLeft(), true);
      expect(result.fold((f) => f.runtimeType, (u) => null), ServerFailure);
    });

    test('handles not found errors', () async {
      final mock = MockTeacherAssignmentRepository();
      final useCase = DeleteTeacherAssignmentUseCase(repository: mock);

      when(() => mock.deleteAssignment(any())).thenAnswer((_) async =>
          Left(NotFoundFailure('Assignment not found')));

      final result = await useCase('nonexistent-id');

      expect(result.isLeft(), true);
      expect(result.fold((f) => f.runtimeType, (u) => null), NotFoundFailure);
    });
  });

  group('GetAssignmentStatsUseCase', () {
    test('returns stats when repository succeeds', () async {
      final mock = MockTeacherAssignmentRepository();
      final useCase = GetAssignmentStatsUseCase(repository: mock);

      final stats = {'2:A': 3, '2:B': 2, '5:A': 1};

      when(() => mock.getAssignmentStats(
        tenantId: 'tenant-456',
        academicYear: '2025-2026',
      )).thenAnswer((_) async => Right(stats));

      final result = await useCase(tenantId: 'tenant-456');

      expect(result.isRight(), true);
      expect(result.fold((f) => null, (s) => s.length), 3);
    });

    test('returns empty stats when no assignments', () async {
      final mock = MockTeacherAssignmentRepository();
      final useCase = GetAssignmentStatsUseCase(repository: mock);

      when(() => mock.getAssignmentStats(
        tenantId: 'tenant-456',
        academicYear: '2025-2026',
      )).thenAnswer((_) async => const Right({}));

      final result = await useCase(tenantId: 'tenant-456');

      expect(result.isRight(), true);
      expect(result.fold((f) => -1, (s) => s.length), 0);
    });

    test('uses provided academicYear', () async {
      final mock = MockTeacherAssignmentRepository();
      final useCase = GetAssignmentStatsUseCase(repository: mock);

      when(() => mock.getAssignmentStats(
        tenantId: 'tenant-456',
        academicYear: '2026-2027',
      )).thenAnswer((_) async => const Right({}));

      await useCase(
        tenantId: 'tenant-456',
        academicYear: '2026-2027',
      );

      verify(() => mock.getAssignmentStats(
        tenantId: 'tenant-456',
        academicYear: '2026-2027',
      )).called(1);
    });

    test('returns failure when repository fails', () async {
      final mock = MockTeacherAssignmentRepository();
      final useCase = GetAssignmentStatsUseCase(repository: mock);

      when(() => mock.getAssignmentStats(
        tenantId: 'tenant-456',
        academicYear: '2025-2026',
      )).thenAnswer((_) async =>
          Left(ServerFailure('Failed to fetch stats')));

      final result = await useCase(tenantId: 'tenant-456');

      expect(result.isLeft(), true);
      expect(result.fold((f) => f.runtimeType, (s) => null), ServerFailure);
    });

    test('correctly interprets stats data structure', () async {
      final mock = MockTeacherAssignmentRepository();
      final useCase = GetAssignmentStatsUseCase(repository: mock);

      final complexStats = {
        '2:A': 5,
        '2:B': 3,
        '2:C': 2,
        '5:A': 4,
        '5:B': 6,
        '8:A': 1,
      };

      when(() => mock.getAssignmentStats(
        tenantId: 'tenant-456',
        academicYear: '2025-2026',
      )).thenAnswer((_) async => Right(complexStats));

      final result = await useCase(tenantId: 'tenant-456');

      expect(result.isRight(), true);
      result.fold(
        (f) => fail('Should be right'),
        (stats) {
          expect(stats['2:A'], 5);
          expect(stats['5:B'], 6);
          expect(stats.length, 6);
        },
      );
    });
  });

  group('Use cases integration scenarios', () {
    test('load, save, delete workflow', () async {
      final mock = MockTeacherAssignmentRepository();

      final loadUseCase = LoadTeacherAssignmentsUseCase(repository: mock);
      final saveUseCase = SaveTeacherAssignmentUseCase(repository: mock);
      final deleteUseCase = DeleteTeacherAssignmentUseCase(repository: mock);

      // Load
      when(() => mock.getTeacherAssignments(
        tenantId: 'tenant-456',
        teacherId: 'teacher-789',
        academicYear: '2025-2026',
        activeOnly: true,
      )).thenAnswer((_) async => Right([testAssignment]));

      var loadResult = await loadUseCase(
        tenantId: 'tenant-456',
        teacherId: 'teacher-789',
      );
      expect(loadResult.isRight(), true);

      // Save
      final updated = testAssignment.copyWith(subjectName: 'Science');
      when(() => mock.saveAssignment(any()))
          .thenAnswer((_) async => const Right(null));

      var saveResult = await saveUseCase(updated);
      expect(saveResult.isRight(), true);

      // Delete
      when(() => mock.deleteAssignment(any()))
          .thenAnswer((_) async => const Right(null));

      var deleteResult = await deleteUseCase(testAssignment.id);
      expect(deleteResult.isRight(), true);
    });

    test('get stats for multiple grades', () async {
      final mock = MockTeacherAssignmentRepository();
      final useCase = GetAssignmentStatsUseCase(repository: mock);

      final stats = {
        '2:A': 2,
        '2:B': 3,
        '2:C': 1,
        '5:A': 4,
        '5:B': 2,
      };

      when(() => mock.getAssignmentStats(
        tenantId: 'tenant-456',
        academicYear: '2025-2026',
      )).thenAnswer((_) async => Right(stats));

      final result = await useCase(tenantId: 'tenant-456');

      expect(result.isRight(), true);
      result.fold(
        (f) => fail('Should be right'),
        (returnedStats) {
          // Verify we get correct counts
          expect(returnedStats['2:A'], 2);
          expect(returnedStats['5:B'], 2);

          // Verify total assignments
          final totalAssignments = returnedStats.values.fold<int>(0, (sum, e) => sum + e);
          expect(totalAssignments, 12);
        },
      );
    });
  });
}
