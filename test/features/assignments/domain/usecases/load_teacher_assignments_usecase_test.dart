import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:papercraft/features/assignments/domain/entities/teacher_subject_assignment_entity.dart';
import 'package:papercraft/features/assignments/domain/repositories/teacher_assignment_repository.dart';
import 'package:papercraft/features/assignments/domain/usecases/load_teacher_assignments_usecase.dart';
import 'package:papercraft/core/domain/errors/failures.dart';

class MockTeacherAssignmentRepository extends Mock implements TeacherAssignmentRepository {}

void main() {
  late LoadTeacherAssignmentsUseCase useCase;
  late MockTeacherAssignmentRepository mockRepository;

  setUp(() {
    mockRepository = MockTeacherAssignmentRepository();
    useCase = LoadTeacherAssignmentsUseCase(repository: mockRepository);
  });

  final testAssignments = [
    const TeacherSubjectAssignmentEntity(
      id: 'a1', tenantId: 't1', teacherId: 'tr1', gradeId: 'g9',
      subjectId: 's1', teacherName: 'John', teacherEmail: 'john@test.com',
      gradeNumber: 9, section: 'A', subjectName: 'Math',
      academicYear: '2025-2026', startDate: null, endDate: null,
      isActive: true, createdAt: DateTime(2025, 1, 1), updatedAt: null,
    ),
  ];

  group('LoadTeacherAssignmentsUseCase', () {
    test('should call repository with correct parameters', () async {
      when(mockRepository.getTeacherAssignments(
        tenantId: 't1',
        teacherId: null,
        academicYear: '2025-2026',
        activeOnly: true,
      )).thenAnswer((_) async => Right(testAssignments));

      await useCase(tenantId: 't1');

      verify(mockRepository.getTeacherAssignments(
        tenantId: 't1',
        teacherId: null,
        academicYear: '2025-2026',
        activeOnly: true,
      )).called(1);
    });

    test('should return assignments when successful', () async {
      when(mockRepository.getTeacherAssignments(
        tenantId: 't1',
        teacherId: null,
        academicYear: '2025-2026',
        activeOnly: true,
      )).thenAnswer((_) async => Right(testAssignments));

      final result = await useCase(tenantId: 't1');

      expect(result, Right(testAssignments));
    });

    test('should support filtering by teacherId', () async {
      when(mockRepository.getTeacherAssignments(
        tenantId: 't1',
        teacherId: 'tr1',
        academicYear: '2025-2026',
        activeOnly: true,
      )).thenAnswer((_) async => Right(testAssignments));

      await useCase(tenantId: 't1', teacherId: 'tr1');

      verify(mockRepository.getTeacherAssignments(
        tenantId: 't1',
        teacherId: 'tr1',
        academicYear: '2025-2026',
        activeOnly: true,
      )).called(1);
    });

    test('should support different academic year', () async {
      when(mockRepository.getTeacherAssignments(
        tenantId: 't1',
        teacherId: null,
        academicYear: '2026-2027',
        activeOnly: true,
      )).thenAnswer((_) async => Right(testAssignments));

      await useCase(tenantId: 't1', academicYear: '2026-2027');

      verify(mockRepository.getTeacherAssignments(
        tenantId: 't1',
        teacherId: null,
        academicYear: '2026-2027',
        activeOnly: true,
      )).called(1);
    });

    test('should support activeOnly parameter', () async {
      when(mockRepository.getTeacherAssignments(
        tenantId: 't1',
        teacherId: null,
        academicYear: '2025-2026',
        activeOnly: false,
      )).thenAnswer((_) async => Right(testAssignments));

      await useCase(tenantId: 't1', activeOnly: false);

      verify(mockRepository.getTeacherAssignments(
        tenantId: 't1',
        teacherId: null,
        academicYear: '2025-2026',
        activeOnly: false,
      )).called(1);
    });

    test('should return failure when repository fails', () async {
      final failure = ServerFailure('Database error');
      when(mockRepository.getTeacherAssignments(
        tenantId: 't1',
        teacherId: null,
        academicYear: '2025-2026',
        activeOnly: true,
      )).thenAnswer((_) async => Left(failure));

      final result = await useCase(tenantId: 't1');

      expect(result.isLeft(), true);
      expect(result.fold((f) => f, (_) => null), failure);
    });

    test('should return empty list when no assignments exist', () async {
      when(mockRepository.getTeacherAssignments(
        tenantId: 't1',
        teacherId: null,
        academicYear: '2025-2026',
        activeOnly: true,
      )).thenAnswer((_) async => const Right([]));

      final result = await useCase(tenantId: 't1');

      expect(result, const Right([]));
    });
  });
}
