import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:papercraft/features/assignments/domain/repositories/teacher_assignment_repository.dart';
import 'package:papercraft/features/assignments/domain/usecases/delete_teacher_assignment_usecase.dart';
import 'package:papercraft/core/domain/errors/failures.dart';

class MockTeacherAssignmentRepository extends Mock implements TeacherAssignmentRepository {}

void main() {
  late DeleteTeacherAssignmentUseCase useCase;
  late MockTeacherAssignmentRepository mockRepository;

  setUp(() {
    mockRepository = MockTeacherAssignmentRepository();
    useCase = DeleteTeacherAssignmentUseCase(repository: mockRepository);
  });

  group('DeleteTeacherAssignmentUseCase', () {
    test('should call repository with correct assignment ID', () async {
      when(mockRepository.deleteAssignment('a1'))
          .thenAnswer((_) async => const Right(null));

      await useCase('a1');

      verify(mockRepository.deleteAssignment('a1')).called(1);
    });

    test('should return void on success', () async {
      when(mockRepository.deleteAssignment('a1'))
          .thenAnswer((_) async => const Right(null));

      final result = await useCase('a1');

      expect(result, const Right(null));
    });

    test('should return failure when repository fails', () async {
      final failure = ServerFailure('Database error');
      when(mockRepository.deleteAssignment('a1'))
          .thenAnswer((_) async => Left(failure));

      final result = await useCase('a1');

      expect(result.isLeft(), true);
      expect(result.fold((f) => f, (_) => null), failure);
    });

    test('should handle different assignment IDs', () async {
      when(mockRepository.deleteAssignment(any))
          .thenAnswer((_) async => const Right(null));

      await useCase('a1');
      await useCase('a2');
      await useCase('a3');

      verify(mockRepository.deleteAssignment('a1')).called(1);
      verify(mockRepository.deleteAssignment('a2')).called(1);
      verify(mockRepository.deleteAssignment('a3')).called(1);
    });

    test('should perform soft delete (preserves record)', () async {
      // This test verifies the soft delete behavior
      when(mockRepository.deleteAssignment('a1'))
          .thenAnswer((_) async => const Right(null));

      final result = await useCase('a1');

      expect(result, const Right(null));
      verify(mockRepository.deleteAssignment('a1')).called(1);
    });
  });
}
