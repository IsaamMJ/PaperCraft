import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papercraft/features/exams/data/services/timetable_validation_service_impl.dart';
import 'package:papercraft/features/exams/domain/entities/exam_timetable_entry.dart';
import 'package:papercraft/features/exams/domain/services/timetable_validation_service.dart';

import '../../../../test_helpers.dart';

void main() {
  group('TimetableValidationService', () {
    late TimetableValidationService validationService;

    setUp(() {
      validationService = TimetableValidationServiceImpl();
    });

    group('validateEntries', () {
      test('should return error when entries list is empty', () async {
        // Act
        final result = await validationService.validateEntries([]);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should return right'),
          (errors) {
            expect(errors.isNotEmpty, true);
            expect(
              errors.any((e) => e.message.contains('at least 1 entry')),
              true,
            );
          },
        );
      });

      test('should return error when exam date is in the past', () async {
        // Arrange
        final pastDate = DateTime.now().subtract(Duration(days: 1));
        final entry = ExamTimetableEntry(
          id: 'entry-1',
          tenantId: TestData.testTenantId,
          timetableId: 'timetable-1',
          gradeId: TestData.testGradeId,
          subjectId: TestData.testSubjectId,
          section: TestData.testSection,
          examDate: pastDate,
          startTime: TimeOfDay(hour: 9, minute: 0),
          endTime: TimeOfDay(hour: 10, minute: 30),
          durationMinutes: 90,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final result = await validationService.validateEntries([entry]);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should return right'),
          (errors) {
            expect(
              errors.any((e) => e.message.contains('must be in the future')),
              true,
            );
          },
        );
      });

      test('should return error when start time is after end time', () async {
        // Arrange
        final futureDate = DateTime.now().add(Duration(days: 1));
        final entry = ExamTimetableEntry(
          id: 'entry-1',
          tenantId: TestData.testTenantId,
          timetableId: 'timetable-1',
          gradeId: TestData.testGradeId,
          subjectId: TestData.testSubjectId,
          section: TestData.testSection,
          examDate: futureDate,
          startTime: TimeOfDay(hour: 11, minute: 0),
          endTime: TimeOfDay(hour: 10, minute: 30),
          durationMinutes: -30,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final result = await validationService.validateEntries([entry]);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should return right'),
          (errors) {
            expect(
              errors.any((e) => e.message.contains('Start time must be before')),
              true,
            );
          },
        );
      });

      test('should return error when duration is zero or negative', () async {
        // Arrange
        final futureDate = DateTime.now().add(Duration(days: 1));
        final entry = ExamTimetableEntry(
          id: 'entry-1',
          tenantId: TestData.testTenantId,
          timetableId: 'timetable-1',
          gradeId: TestData.testGradeId,
          subjectId: TestData.testSubjectId,
          section: TestData.testSection,
          examDate: futureDate,
          startTime: TimeOfDay(hour: 9, minute: 0),
          endTime: TimeOfDay(hour: 9, minute: 0),
          durationMinutes: 0,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final result = await validationService.validateEntries([entry]);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should return right'),
          (errors) {
            expect(
              errors.any((e) => e.message.contains('duration must be')),
              true,
            );
          },
        );
      });

      test('should return no errors for valid entries', () async {
        // Arrange
        final futureDate = DateTime.now().add(Duration(days: 1));
        final entry = ExamTimetableEntry(
          id: 'entry-1',
          tenantId: TestData.testTenantId,
          timetableId: 'timetable-1',
          gradeId: TestData.testGradeId,
          subjectId: TestData.testSubjectId,
          section: TestData.testSection,
          examDate: futureDate,
          startTime: TimeOfDay(hour: 9, minute: 0),
          endTime: TimeOfDay(hour: 10, minute: 30),
          durationMinutes: 90,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final result = await validationService.validateEntries([entry]);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should return right'),
          (errors) {
            // Should have no errors for valid entry (or only scheduling conflicts)
            final criticalErrors = errors
                .where((e) => e.field != 'scheduling')
                .toList();
            expect(criticalErrors.isEmpty, true);
          },
        );
      });

      test('should detect scheduling conflicts for same grade/section', () async {
        // Arrange
        final futureDate = DateTime.now().add(Duration(days: 1));
        final entry1 = ExamTimetableEntry(
          id: 'entry-1',
          tenantId: TestData.testTenantId,
          timetableId: 'timetable-1',
          gradeId: 'Grade 5',
          subjectId: 'Maths',
          section: 'A',
          examDate: futureDate,
          startTime: TimeOfDay(hour: 9, minute: 0),
          endTime: TimeOfDay(hour: 10, minute: 0),
          durationMinutes: 60,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final entry2 = ExamTimetableEntry(
          id: 'entry-2',
          tenantId: TestData.testTenantId,
          timetableId: 'timetable-1',
          gradeId: 'Grade 5',
          subjectId: 'English',
          section: 'A',
          examDate: futureDate,
          startTime: TimeOfDay(hour: 9, minute: 30),
          endTime: TimeOfDay(hour: 10, minute: 30),
          durationMinutes: 60,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final result = await validationService.validateEntries([entry1, entry2]);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should return right'),
          (errors) {
            expect(
              errors.any((e) => e.message.contains('Scheduling conflict')),
              true,
            );
          },
        );
      });

      test('should not report conflict for different grades', () async {
        // Arrange
        final futureDate = DateTime.now().add(Duration(days: 1));
        final entry1 = ExamTimetableEntry(
          id: 'entry-1',
          tenantId: TestData.testTenantId,
          timetableId: 'timetable-1',
          gradeId: 'Grade 5',
          subjectId: 'Maths',
          section: 'A',
          examDate: futureDate,
          startTime: TimeOfDay(hour: 9, minute: 0),
          endTime: TimeOfDay(hour: 10, minute: 0),
          durationMinutes: 60,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final entry2 = ExamTimetableEntry(
          id: 'entry-2',
          tenantId: TestData.testTenantId,
          timetableId: 'timetable-1',
          gradeId: 'Grade 6',
          subjectId: 'Maths',
          section: 'A',
          examDate: futureDate,
          startTime: TimeOfDay(hour: 9, minute: 0),
          endTime: TimeOfDay(hour: 10, minute: 0),
          durationMinutes: 60,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final result = await validationService.validateEntries([entry1, entry2]);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should return right'),
          (errors) {
            final conflicts = errors
                .where((e) => e.message.contains('Scheduling conflict'))
                .toList();
            expect(conflicts.isEmpty, true);
          },
        );
      });
    });

    group('checkSchedulingConflicts', () {
      test('should detect overlapping times on same date', () async {
        // Arrange
        final futureDate = DateTime.now().add(Duration(days: 1));
        final entry1 = ExamTimetableEntry(
          id: 'entry-1',
          tenantId: TestData.testTenantId,
          timetableId: 'timetable-1',
          gradeId: 'Grade 5',
          subjectId: 'Maths',
          section: 'A',
          examDate: futureDate,
          startTime: TimeOfDay(hour: 9, minute: 0),
          endTime: TimeOfDay(hour: 11, minute: 0),
          durationMinutes: 120,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final entry2 = ExamTimetableEntry(
          id: 'entry-2',
          tenantId: TestData.testTenantId,
          timetableId: 'timetable-1',
          gradeId: 'Grade 5',
          subjectId: 'English',
          section: 'A',
          examDate: futureDate,
          startTime: TimeOfDay(hour: 10, minute: 0),
          endTime: TimeOfDay(hour: 12, minute: 0),
          durationMinutes: 120,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final result =
            await validationService.checkSchedulingConflicts([entry1, entry2]);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should return right'),
          (conflicts) {
            expect(conflicts.isNotEmpty, true);
            expect(conflicts[0], contains('overlap'));
          },
        );
      });

      test('should not detect conflict for non-overlapping times', () async {
        // Arrange
        final futureDate = DateTime.now().add(Duration(days: 1));
        final entry1 = ExamTimetableEntry(
          id: 'entry-1',
          tenantId: TestData.testTenantId,
          timetableId: 'timetable-1',
          gradeId: 'Grade 5',
          subjectId: 'Maths',
          section: 'A',
          examDate: futureDate,
          startTime: TimeOfDay(hour: 9, minute: 0),
          endTime: TimeOfDay(hour: 10, minute: 0),
          durationMinutes: 60,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final entry2 = ExamTimetableEntry(
          id: 'entry-2',
          tenantId: TestData.testTenantId,
          timetableId: 'timetable-1',
          gradeId: 'Grade 5',
          subjectId: 'English',
          section: 'A',
          examDate: futureDate,
          startTime: TimeOfDay(hour: 10, minute: 0),
          endTime: TimeOfDay(hour: 11, minute: 0),
          durationMinutes: 60,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final result =
            await validationService.checkSchedulingConflicts([entry1, entry2]);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should return right'),
          (conflicts) => expect(conflicts.isEmpty, true),
        );
      });
    });

    group('validateEntry', () {
      test('should return no errors for valid entry', () async {
        // Arrange
        final futureDate = DateTime.now().add(Duration(days: 1));
        final entry = ExamTimetableEntry(
          id: 'entry-1',
          tenantId: TestData.testTenantId,
          timetableId: 'timetable-1',
          gradeId: TestData.testGradeId,
          subjectId: TestData.testSubjectId,
          section: TestData.testSection,
          examDate: futureDate,
          startTime: TimeOfDay(hour: 9, minute: 0),
          endTime: TimeOfDay(hour: 10, minute: 30),
          durationMinutes: 90,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final result = await validationService.validateEntry(entry);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should return right'),
          (errors) => expect(errors.isEmpty, true),
        );
      });

      test('should return error for past exam date', () async {
        // Arrange
        final pastDate = DateTime.now().subtract(Duration(days: 1));
        final entry = ExamTimetableEntry(
          id: 'entry-1',
          tenantId: TestData.testTenantId,
          timetableId: 'timetable-1',
          gradeId: TestData.testGradeId,
          subjectId: TestData.testSubjectId,
          section: TestData.testSection,
          examDate: pastDate,
          startTime: TimeOfDay(hour: 9, minute: 0),
          endTime: TimeOfDay(hour: 10, minute: 30),
          durationMinutes: 90,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final result = await validationService.validateEntry(entry);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should return right'),
          (errors) {
            expect(errors.isNotEmpty, true);
            expect(
              errors.any((e) => e.message.contains('must be in the future')),
              true,
            );
          },
        );
      });
    });
  });
}
