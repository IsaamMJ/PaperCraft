import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/exam_timetable_entry_entity.dart';
import '../entities/exam_timetable_entity.dart';
import '../repositories/exam_timetable_repository.dart';

/// Use case for Step 3: Create an exam timetable with all entries
///
/// This is the final step - creates the actual exam timetable with all
/// subject-to-date mappings. The timetable starts in 'draft' status.
///
/// Business logic:
/// - Validates that all subjects are assigned to dates
/// - Ensures dates are within the exam calendar range
/// - Creates the timetable with all entries in a single operation
///
/// Example:
/// ```dart
/// final params = CreateExamTimetableWithEntriesParams(
///   tenantId: 'tenant-123',
///   examCalendarId: 'calendar-456',
///   examName: 'Monthly Test January',
///   examType: 'monthlyTest',
///   academicYear: '2024-25',
///   createdByUserId: 'user-789',
///   entries: [...timetableEntries],
/// );
/// final result = await createExamTimetableWithEntries(params);
/// ```
class CreateExamTimetableWithEntriesUsecase {
  final ExamTimetableRepository repository;

  CreateExamTimetableWithEntriesUsecase({
    required this.repository,
  });

  Future<Either<Failure, ExamTimetableEntity>> call(
    CreateExamTimetableWithEntriesParams params,
  ) async {
    // Validate basic inputs
    if (params.tenantId.isEmpty) {
      return Left(ValidationFailure('Tenant ID cannot be empty'));
    }
    if (params.examName.isEmpty) {
      return Left(ValidationFailure('Exam name cannot be empty'));
    }
    if (params.academicYear.isEmpty) {
      return Left(ValidationFailure('Academic year cannot be empty'));
    }
    if (params.createdByUserId.isEmpty) {
      return Left(ValidationFailure('Creator user ID cannot be empty'));
    }

    // Validate entries exist
    if (params.entries.isEmpty) {
      return Left(ValidationFailure('At least one timetable entry is required'));
    }

    // Validate all entries have exam dates
    for (final entry in params.entries) {
      if (entry.examDate == null) {
        return Left(ValidationFailure(
            'All entries must have exam dates assigned'));
      }
    }

    // Call repository to create timetable
    return await repository.createExamTimetableWithEntries(
      tenantId: params.tenantId,
      examCalendarId: params.examCalendarId,
      examName: params.examName,
      examType: params.examType,
      academicYear: params.academicYear,
      createdByUserId: params.createdByUserId,
      entries: params.entries,
    );
  }
}

/// Parameters for CreateExamTimetableWithEntriesUsecase
class CreateExamTimetableWithEntriesParams extends Equatable {
  final String tenantId;
  final String? examCalendarId;
  final String examName;
  final String examType;
  final String academicYear;
  final String createdByUserId;
  final List<ExamTimetableEntryEntity> entries;

  const CreateExamTimetableWithEntriesParams({
    required this.tenantId,
    this.examCalendarId,
    required this.examName,
    required this.examType,
    required this.academicYear,
    required this.createdByUserId,
    required this.entries,
  });

  @override
  List<Object?> get props => [
        tenantId,
        examCalendarId,
        examName,
        examType,
        academicYear,
        createdByUserId,
        entries,
      ];
}
