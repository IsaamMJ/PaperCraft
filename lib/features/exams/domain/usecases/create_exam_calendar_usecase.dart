import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/exam_calendar.dart';
import '../repositories/exam_calendar_repository.dart';

/// Use case: Create a new exam in the calendar
///
/// Called by: ExamCalendarCreatePage (admin creates new exam)
///
/// Example: Admin creates "June Monthly Test"
/// This exam appears in calendar and can be selected when creating timetables
class CreateExamCalendarUseCase {
  final ExamCalendarRepository repository;

  CreateExamCalendarUseCase({required this.repository});

  Future<Either<Failure, ExamCalendar>> call({
    required String tenantId,
    required String examName,
    required String examType,
    required int monthNumber,
    required DateTime plannedStartDate,
    required DateTime plannedEndDate,
    DateTime? paperSubmissionDeadline,
    required int displayOrder,
    Map<String, dynamic>? metadata,
  }) async {
    // Validate inputs
    if (monthNumber < 1 || monthNumber > 12) {
      return const Left(
        ValidationFailure('Month number must be between 1 and 12'),
      );
    }

    if (plannedStartDate.isAfter(plannedEndDate)) {
      return const Left(
        ValidationFailure('Start date must be before end date'),
      );
    }

    if (paperSubmissionDeadline != null &&
        paperSubmissionDeadline.isAfter(plannedEndDate)) {
      return const Left(
        ValidationFailure('Deadline must be before exam end date'),
      );
    }

    // Check if exam name already exists
    final existsResult = await repository.examNameExists(
      tenantId: tenantId,
      examName: examName,
    );

    final existsEither = existsResult.fold(
      (failure) => Left<Failure, bool>(failure),
      (exists) => Right<Failure, bool>(exists),
    );

    final exists = await existsEither.fold(
      (failure) async => throw Exception(failure.message),
      (value) async => value,
    );

    if (exists) {
      return const Left(
        ValidationFailure('Exam with this name already exists'),
      );
    }

    // Create the calendar
    final calendar = ExamCalendar(
      id: const Uuid().v4(), // Generate UUID client-side
      tenantId: tenantId,
      examName: examName,
      examType: examType,
      monthNumber: monthNumber,
      plannedStartDate: plannedStartDate,
      plannedEndDate: plannedEndDate,
      paperSubmissionDeadline: paperSubmissionDeadline,
      displayOrder: displayOrder,
      metadata: metadata,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return await repository.createExamCalendar(calendar);
  }
}
