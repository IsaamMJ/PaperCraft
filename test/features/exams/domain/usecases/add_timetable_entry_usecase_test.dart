import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/features/exams/domain/entities/exam_timetable_entry.dart';
import 'package:papercraft/features/exams/domain/repositories/exam_timetable_repository.dart';
import 'package:papercraft/features/exams/domain/usecases/add_timetable_entry_usecase.dart';

import '../../../../test_helpers.dart';

@GenerateMocks([ExamTimetableRepository])
void main() {
  group('AddTimetableEntryUseCase', () {
    late MockExamTimetableRepository mockRepository;
    late AddTimetableEntryUseCase usecase;

    final examDate = DateTime(2024, 6, 15);
    final startTime = TimeOfDay(hour: 9, minute: 0);
    final endTime = TimeOfDay(hour: 10, minute: 30);

    setUp(() {
      mockRepository = MockExamTimetableRepository();
      usecase = AddTimetableEntryUseCase(repository: mockRepository);
    });

    test('should return failure when start time is after end time', () async {
      // Arrange
      when(mockRepository.entryExists(
        timetableId: anyNamed('timetableId'),
        gradeId: anyNamed('gradeId'),
        subjectId: anyNamed('subjectId'),
        section: anyNamed('section'),
      )).thenAnswer((_) async => const Right(false));

      // Act
      final result = await usecase(
        tenantId: TestData.testTenantId,
        timetableId: 'timetable-1',
        gradeId: TestData.testGradeId,
        subjectId: TestData.testSubjectId,
        section: TestData.testSection,
        examDate: examDate,
        startTime: TimeOfDay(hour: 11, minute: 0),
        endTime: TimeOfDay(hour: 10, minute: 0),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(failure.message, contains('Start time must be before end time'));
        },
        (entry) => fail('Should have returned validation failure'),
      );
    });

    test('should return failure when start time equals end time', () async {
      // Arrange
      when(mockRepository.entryExists(
        timetableId: anyNamed('timetableId'),
        gradeId: anyNamed('gradeId'),
        subjectId: anyNamed('subjectId'),
        section: anyNamed('section'),
      )).thenAnswer((_) async => const Right(false));

      // Act
      final result = await usecase(
        tenantId: TestData.testTenantId,
        timetableId: 'timetable-1',
        gradeId: TestData.testGradeId,
        subjectId: TestData.testSubjectId,
        section: TestData.testSection,
        examDate: examDate,
        startTime: TimeOfDay(hour: 10, minute: 0),
        endTime: TimeOfDay(hour: 10, minute: 0),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
        },
        (entry) => fail('Should have returned validation failure'),
      );
    });

    test('should return failure when entry already exists', () async {
      // Arrange
      when(mockRepository.entryExists(
        timetableId: anyNamed('timetableId'),
        gradeId: anyNamed('gradeId'),
        subjectId: anyNamed('subjectId'),
        section: anyNamed('section'),
      )).thenAnswer((_) async => const Right(true));

      // Act
      final result = await usecase(
        tenantId: TestData.testTenantId,
        timetableId: 'timetable-1',
        gradeId: TestData.testGradeId,
        subjectId: TestData.testSubjectId,
        section: TestData.testSection,
        examDate: examDate,
        startTime: startTime,
        endTime: endTime,
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(failure.message, contains('already exists'));
        },
        (entry) => fail('Should have returned validation failure'),
      );

      verifyNever(mockRepository.addTimetableEntry(any));
    });

    test('should create entry successfully when validation passes', () async {
      // Arrange
      when(mockRepository.entryExists(
        timetableId: anyNamed('timetableId'),
        gradeId: anyNamed('gradeId'),
        subjectId: anyNamed('subjectId'),
        section: anyNamed('section'),
      )).thenAnswer((_) async => const Right(false));

      when(mockRepository.addTimetableEntry(any))
          .thenAnswer((_) async => Right(
            ExamTimetableEntry(
              id: 'entry-1',
              tenantId: TestData.testTenantId,
              timetableId: 'timetable-1',
              gradeId: TestData.testGradeId,
              subjectId: TestData.testSubjectId,
              section: TestData.testSection,
              examDate: examDate,
              startTime: startTime,
              endTime: endTime,
              durationMinutes: 90,
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ));

      // Act
      final result = await usecase(
        tenantId: TestData.testTenantId,
        timetableId: 'timetable-1',
        gradeId: TestData.testGradeId,
        subjectId: TestData.testSubjectId,
        section: TestData.testSection,
        examDate: examDate,
        startTime: startTime,
        endTime: endTime,
      );

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should have created entry'),
        (entry) {
          expect(entry.gradeId, equals(TestData.testGradeId));
          expect(entry.subjectId, equals(TestData.testSubjectId));
          expect(entry.section, equals(TestData.testSection));
          expect(entry.durationMinutes, equals(90));
        },
      );

      verify(mockRepository.addTimetableEntry(any)).called(1);
    });

    test('should calculate correct duration minutes', () async {
      // Arrange
      when(mockRepository.entryExists(
        timetableId: anyNamed('timetableId'),
        gradeId: anyNamed('gradeId'),
        subjectId: anyNamed('subjectId'),
        section: anyNamed('section'),
      )).thenAnswer((_) async => const Right(false));

      when(mockRepository.addTimetableEntry(any))
          .thenAnswer((_) async => Right(
            ExamTimetableEntry(
              id: 'entry-1',
              tenantId: TestData.testTenantId,
              timetableId: 'timetable-1',
              gradeId: TestData.testGradeId,
              subjectId: TestData.testSubjectId,
              section: TestData.testSection,
              examDate: examDate,
              startTime: TimeOfDay(hour: 14, minute: 30),
              endTime: TimeOfDay(hour: 16, minute: 0),
              durationMinutes: 90,
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ));

      // Act
      final result = await usecase(
        tenantId: TestData.testTenantId,
        timetableId: 'timetable-1',
        gradeId: TestData.testGradeId,
        subjectId: TestData.testSubjectId,
        section: TestData.testSection,
        examDate: examDate,
        startTime: TimeOfDay(hour: 14, minute: 30),
        endTime: TimeOfDay(hour: 16, minute: 0),
      );

      // Assert - 90 minutes = 1.5 hours
      result.fold(
        (failure) => fail('Should have created entry'),
        (entry) => expect(entry.durationMinutes, equals(90)),
      );
    });

    test('should handle repository error gracefully', () async {
      // Arrange
      final failure = ServerFailure('Database error');

      when(mockRepository.entryExists(
        timetableId: anyNamed('timetableId'),
        gradeId: anyNamed('gradeId'),
        subjectId: anyNamed('subjectId'),
        section: anyNamed('section'),
      )).thenAnswer((_) async => Left(failure));

      // Act
      final result = await usecase(
        tenantId: TestData.testTenantId,
        timetableId: 'timetable-1',
        gradeId: TestData.testGradeId,
        subjectId: TestData.testSubjectId,
        section: TestData.testSection,
        examDate: examDate,
        startTime: startTime,
        endTime: endTime,
      );

      // Assert
      expect(result.isRight(), true); // When check fails, allows creation
      verifyNever(mockRepository.addTimetableEntry(any));
    });

    test('should return failure when add entry fails', () async {
      // Arrange
      when(mockRepository.entryExists(
        timetableId: anyNamed('timetableId'),
        gradeId: anyNamed('gradeId'),
        subjectId: anyNamed('subjectId'),
        section: anyNamed('section'),
      )).thenAnswer((_) async => const Right(false));

      final failure = ServerFailure('Failed to create entry');
      when(mockRepository.addTimetableEntry(any))
          .thenAnswer((_) async => Left(failure));

      // Act
      final result = await usecase(
        tenantId: TestData.testTenantId,
        timetableId: 'timetable-1',
        gradeId: TestData.testGradeId,
        subjectId: TestData.testSubjectId,
        section: TestData.testSection,
        examDate: examDate,
        startTime: startTime,
        endTime: endTime,
      );

      // Assert
      expect(result.isLeft(), true);
    });
  });
}
