import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:papercraft/features/assignments/domain/entities/teacher_subject_assignment_entity.dart';
import 'package:papercraft/features/assignments/domain/repositories/teacher_assignment_repository.dart';
import 'package:papercraft/features/assignments/domain/usecases/save_teacher_assignment_usecase.dart';
import 'package:papercraft/core/domain/errors/failures.dart';

class MockTeacherAssignmentRepository extends Mock implements TeacherAssignmentRepository {}

void main() {
  late SaveTeacherAssignmentUseCase useCase;
  late MockTeacherAssignmentRepository mockRepository;

  setUp(() {
    mockRepository = MockTeacherAssignmentRepository();
    useCase = SaveTeacherAssignmentUseCase(repository: mockRepository);
  });

  const testAssignment = TeacherSubjectAssignmentEntity(
    id: 'a1', tenantId: 't1', teacherId: 'tr1', gradeId: 'g9',
    subjectId: 's1', teacherName: 'John', teacherEmail: 'john@test.com',
    gradeNumber: 9, section: 'A', subjectName: 'Math',
    academicYear: '2025-2026', startDate: null, endDate: null,
    isActive: true, createdAt: DateTime(2025, 1, 1), updatedAt: null,
  );

  group('SaveTeacherAssignmentUseCase', () {
    test('should call repository with assignment', () async {
      when(mockRepository.saveAssignment(testAssignment))
          .thenAnswer((_) async => const Right(null));

      await useCase(testAssignment);

      verify(mockRepository.saveAssignment(testAssignment)).called(1);
    });

    test('should return void on success', () async {
      when(mockRepository.saveAssignment(testAssignment))
          .thenAnswer((_) async => const Right(null));

      final result = await useCase(testAssignment);

      expect(result, const Right(null));
    });

    test('should return failure when repository fails', () async {
      final failure = ServerFailure('Database error');
      when(mockRepository.saveAssignment(testAssignment))
          .thenAnswer((_) async => Left(failure));

      final result = await useCase(testAssignment);

      expect(result.isLeft(), true);
    });

    test('should handle inactive assignments', () async {
      final inactiveAssignment = testAssignment.copyWith(isActive: false);
      when(mockRepository.saveAssignment(inactiveAssignment))
          .thenAnswer((_) async => const Right(null));

      final result = await useCase(inactiveAssignment);

      expect(result, const Right(null));
      verify(mockRepository.saveAssignment(inactiveAssignment)).called(1);
    });

    test('should handle update to existing assignment', () async {
      final updatedAssignment = testAssignment.copyWith(
        gradeNumber: 10,
        section: 'B',
        updatedAt: DateTime(2025, 2, 1),
      );
      when(mockRepository.saveAssignment(updatedAssignment))
          .thenAnswer((_) async => const Right(null));

      final result = await useCase(updatedAssignment);

      expect(result, const Right(null));
    });
  });
}
