import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/features/exams/domain/entities/exam_timetable.dart';
import 'package:papercraft/features/exams/domain/repositories/exam_timetable_repository.dart';
import 'package:papercraft/features/exams/domain/usecases/publish_exam_timetable_usecase.dart';

import '../../../../test_helpers.dart';

@GenerateMocks([ExamTimetableRepository])
void main() {
  group('PublishExamTimetableUseCase', () {
    late MockExamTimetableRepository mockRepository;
    late PublishExamTimetableUseCase usecase;

    setUp(() {
      mockRepository = MockExamTimetableRepository();
      usecase = PublishExamTimetableUseCase(
        timetableRepository: mockRepository,
      );
    });

    test('should return failure when timetable not found', () async {
      // Arrange
      when(mockRepository.getTimetableById(any))
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await usecase(timetableId: 'timetable-1');

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, contains('not found'));
        },
        (_) => fail('Should have returned failure'),
      );
    });

    test('should return failure when timetable retrieval fails', () async {
      // Arrange
      final failure = ServerFailure('Database error');
      when(mockRepository.getTimetableById(any))
          .thenAnswer((_) async => Left(failure));

      // Act
      final result = await usecase(timetableId: 'timetable-1');

      // Assert
      expect(result.isLeft(), true);
    });

    test('should return failure when entries retrieval fails', () async {
      // Arrange
      final timetable = ExamTimetableBuilder().buildJson();
      when(mockRepository.getTimetableById(any)).thenAnswer(
        (_) async => Right(ExamTimetable.fromJson(timetable)),
      );

      final failure = ServerFailure('Database error');
      when(mockRepository.getTimetableEntries(any))
          .thenAnswer((_) async => Left(failure));

      // Act
      final result = await usecase(timetableId: 'timetable-1');

      // Assert
      expect(result.isLeft(), true);
    });

    test('should return failure when timetable has no entries', () async {
      // Arrange
      final timetable = ExamTimetableBuilder().buildJson();
      when(mockRepository.getTimetableById(any)).thenAnswer(
        (_) async => Right(ExamTimetable.fromJson(timetable)),
      );

      when(mockRepository.getTimetableEntries(any))
          .thenAnswer((_) async => const Right([]));

      // Act
      final result = await usecase(timetableId: 'timetable-1');

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(failure.message, contains('at least 1 entry'));
        },
        (_) => fail('Should have returned failure'),
      );
    });

    test('should publish timetable successfully when all validations pass',
        () async {
      // Arrange
      final timetable = ExamTimetableBuilder().buildJson();
      when(mockRepository.getTimetableById(any)).thenAnswer(
        (_) async => Right(ExamTimetable.fromJson(timetable)),
      );

      final entry = ExamTimetableEntryBuilder().buildJson();
      when(mockRepository.getTimetableEntries(any))
          .thenAnswer((_) async => Right([entry]));

      when(mockRepository.updateTimetableStatus(
        timetableId: anyNamed('timetableId'),
        status: anyNamed('status'),
        publishedAt: anyNamed('publishedAt'),
      )).thenAnswer((_) async => const Right(null));

      // Act
      final result = await usecase(timetableId: 'timetable-1');

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should have published timetable'),
        (_) {
          verify(mockRepository.getTimetableById('timetable-1')).called(1);
          verify(mockRepository.getTimetableEntries('timetable-1')).called(1);
          verify(mockRepository.updateTimetableStatus(
            timetableId: 'timetable-1',
            status: TimetableStatus.published,
            publishedAt: any,
          )).called(1);
        },
      );
    });

    test('should return failure when status update fails', () async {
      // Arrange
      final timetable = ExamTimetableBuilder().buildJson();
      when(mockRepository.getTimetableById(any)).thenAnswer(
        (_) async => Right(ExamTimetable.fromJson(timetable)),
      );

      final entry = ExamTimetableEntryBuilder().buildJson();
      when(mockRepository.getTimetableEntries(any))
          .thenAnswer((_) async => Right([entry]));

      final failure = ServerFailure('Failed to update status');
      when(mockRepository.updateTimetableStatus(
        timetableId: anyNamed('timetableId'),
        status: anyNamed('status'),
        publishedAt: anyNamed('publishedAt'),
      )).thenAnswer((_) async => Left(failure));

      // Act
      final result = await usecase(timetableId: 'timetable-1');

      // Assert
      expect(result.isLeft(), true);
    });

    test('should update status to published', () async {
      // Arrange
      final timetable = ExamTimetableBuilder().buildJson();
      when(mockRepository.getTimetableById(any)).thenAnswer(
        (_) async => Right(ExamTimetable.fromJson(timetable)),
      );

      final entry = ExamTimetableEntryBuilder().buildJson();
      when(mockRepository.getTimetableEntries(any))
          .thenAnswer((_) async => Right([entry]));

      when(mockRepository.updateTimetableStatus(
        timetableId: anyNamed('timetableId'),
        status: anyNamed('status'),
        publishedAt: anyNamed('publishedAt'),
      )).thenAnswer((_) async => const Right(null));

      // Act
      await usecase(timetableId: 'timetable-1');

      // Assert - verify status is set to published
      verify(mockRepository.updateTimetableStatus(
        timetableId: 'timetable-1',
        status: TimetableStatus.published,
        publishedAt: any,
      )).called(1);
    });

    test('should set publishedAt timestamp when publishing', () async {
      // Arrange
      final timetable = ExamTimetableBuilder().buildJson();
      when(mockRepository.getTimetableById(any)).thenAnswer(
        (_) async => Right(ExamTimetable.fromJson(timetable)),
      );

      final entry = ExamTimetableEntryBuilder().buildJson();
      when(mockRepository.getTimetableEntries(any))
          .thenAnswer((_) async => Right([entry]));

      when(mockRepository.updateTimetableStatus(
        timetableId: anyNamed('timetableId'),
        status: anyNamed('status'),
        publishedAt: anyNamed('publishedAt'),
      )).thenAnswer((_) async => const Right(null));

      // Act
      final beforeCall = DateTime.now();
      await usecase(timetableId: 'timetable-1');
      final afterCall = DateTime.now();

      // Assert
      final captured = verify(mockRepository.updateTimetableStatus(
        timetableId: 'timetable-1',
        status: TimetableStatus.published,
        publishedAt: captureAnyNamed('publishedAt'),
      )).captured;

      expect(captured.length, 1);
      final publishedAt = captured[0] as DateTime;
      expect(publishedAt.isAfter(beforeCall.subtract(Duration(seconds: 1))),
          true);
      expect(publishedAt.isBefore(afterCall.add(Duration(seconds: 1))), true);
    });

    test('should handle multiple entries correctly', () async {
      // Arrange
      final timetable = ExamTimetableBuilder().buildJson();
      when(mockRepository.getTimetableById(any)).thenAnswer(
        (_) async => Right(ExamTimetable.fromJson(timetable)),
      );

      final entry1 = ExamTimetableEntryBuilder().buildJson();
      final entry2 = ExamTimetableEntryBuilder()
          .withGradeSubjectSection('Grade 6', 'English', 'A')
          .buildJson();

      when(mockRepository.getTimetableEntries(any))
          .thenAnswer((_) async => Right([entry1, entry2]));

      when(mockRepository.updateTimetableStatus(
        timetableId: anyNamed('timetableId'),
        status: anyNamed('status'),
        publishedAt: anyNamed('publishedAt'),
      )).thenAnswer((_) async => const Right(null));

      // Act
      final result = await usecase(timetableId: 'timetable-1');

      // Assert
      expect(result.isRight(), true);
      verify(mockRepository.getTimetableEntries('timetable-1')).called(1);
    });
  });
}
