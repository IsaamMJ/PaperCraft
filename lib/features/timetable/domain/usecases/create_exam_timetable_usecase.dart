import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/exam_timetable_entity.dart';
import '../repositories/exam_timetable_repository.dart';

/// Use case for creating a new exam timetable
///
/// Business Logic:
/// - Creates a new timetable in draft status
/// - Validates academic year format
/// - Validates exam name is not empty
/// - Sets system fields (createdAt, updatedAt, status)
///
/// Example:
/// ```dart
/// final usecase = CreateExamTimetableUsecase(repository);
/// final timetable = ExamTimetableEntity(
///   id: 'timetable-123',
///   tenantId: 'tenant-456',
///   createdBy: 'user-789',
///   examName: 'Midterm Exams',
///   examType: 'midterm',
///   academicYear: '2025-2026',
///   createdAt: DateTime.now(),
///   updatedAt: DateTime.now(),
/// );
/// final result = await usecase(params: CreateExamTimetableParams(timetable: timetable));
/// ```
class CreateExamTimetableUsecase {
  final ExamTimetableRepository _repository;

  CreateExamTimetableUsecase({required ExamTimetableRepository repository})
      : _repository = repository;

  /// Create a new exam timetable
  ///
  /// Parameters:
  /// - [params] - Contains the timetable entity to create
  ///
  /// Returns:
  /// - [Either<Failure, ExamTimetableEntity>] - Created timetable or failure
  ///
  /// Validates:
  /// - Exam name is not empty
  /// - Academic year format matches "YYYY-YYYY"
  /// - All required fields are present
  Future<Either<Failure, ExamTimetableEntity>> call({
    required CreateExamTimetableParams params,
  }) async {
    final timetable = params.timetable;

    // Validate exam name
    if (timetable.examName.isEmpty) {
      return Left(ValidationFailure('Exam name cannot be empty'));
    }

    // Validate academic year format (e.g., "2025-2026")
    if (!_isValidAcademicYear(timetable.academicYear)) {
      return Left(
        ValidationFailure(
          'Invalid academic year format. Use format: YYYY-YYYY (e.g., 2025-2026)',
        ),
      );
    }

    // Validate required fields
    if (timetable.tenantId.isEmpty || timetable.createdBy.isEmpty) {
      return Left(ValidationFailure('Tenant ID and Created By are required'));
    }

    return await _repository.createExamTimetable(timetable);
  }

  /// Validate academic year format (YYYY-YYYY)
  bool _isValidAcademicYear(String year) {
    final pattern = RegExp(r'^\d{4}-\d{4}$');
    if (!pattern.hasMatch(year)) return false;

    final parts = year.split('-');
    final start = int.parse(parts[0]);
    final end = int.parse(parts[1]);

    // End year should be start year + 1
    return end == start + 1;
  }
}

/// Parameters for CreateExamTimetableUsecase
class CreateExamTimetableParams {
  final ExamTimetableEntity timetable;

  CreateExamTimetableParams({required this.timetable});
}
