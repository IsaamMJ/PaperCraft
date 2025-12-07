import 'package:flutter/foundation.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/question_paper_entity.dart';
import '../repositories/question_paper_repository.dart';

/// Use case for automatically assigning question papers to teachers when timetable is published
///
/// Business Logic:
/// - Triggered when an exam timetable is published
/// - For each timetable entry (Grade + Section + Subject + Date):
///   - Gets all teachers assigned to that grade/section/subject
///   - Creates blank question paper for each teacher
/// - Pre-fills paper metadata: grade_id, subject_id, section, exam_date, exam_type, exam_number
/// - Paper status: 'draft' with empty questions and paper_sections
/// - Handles collaborative teaching: creates separate papers per teacher (admin can delete duplicates)
///
/// Benefits:
/// - Teachers don't need to manually select grade/section/subject
/// - Paper appears in teacher dashboard immediately
/// - Speeds up paper creation process
///
/// Example:
/// ```dart
/// final usecase = AutoAssignQuestionPapersUsecase(repository);
/// final result = await usecase(
///   params: AutoAssignQuestionPapersParams(
///     timetableId: 'timetable-123',
///     tenantId: 'tenant-456',
///     timetableEntries: [...],
///     academicYear: '2025-2026',
///   ),
/// );
/// result.fold(
///   (failure) => debugPrint('Auto-assignment failed: ${failure.message}'),
///   (papers) => debugPrint('${papers.length} papers auto-assigned'),
/// );
/// ```
class AutoAssignQuestionPapersUsecase {
  final QuestionPaperRepository _repository;

  AutoAssignQuestionPapersUsecase({
    required QuestionPaperRepository repository,
  }) : _repository = repository;

  /// Execute auto-assignment of question papers
  ///
  /// Parameters:
  /// - [params] - Contains timetable details and entries
  ///
  /// Returns:
  /// - [Either<Failure, List<QuestionPaperEntity>>] - List of created papers or failure
  ///
  /// Flow:
  /// 1. Receive timetable entries from published timetable
  /// 2. For each unique teacher-subject-grade-section combination:
  ///    - Create blank question paper
  ///    - Link to exam timetable entry (exam_timetable_entry_id)
  ///    - Set status to 'draft'
  ///    - Initialize empty questions and paper_sections arrays
  /// 3. Return list of created papers
  Future<Either<Failure, List<QuestionPaperEntity>>> call({
    required AutoAssignQuestionPapersParams params,
  }) async {
    return await _repository.autoAssignPapersForTimetable(
      timetableId: params.timetableId,
      tenantId: params.tenantId,
      timetableEntries: params.timetableEntries,
      academicYear: params.academicYear,
    );
  }
}

/// Parameters for AutoAssignQuestionPapersUsecase
class AutoAssignQuestionPapersParams {
  /// ID of the exam timetable being published
  final String timetableId;

  /// Tenant ID (school/organization)
  final String tenantId;

  /// List of timetable entries with metadata:
  /// {
  ///   'id': timetable_entry_id,
  ///   'grade_id': grade_id,
  ///   'subject_id': subject_id,
  ///   'section': section_name,
  ///   'exam_date': date,
  ///   'exam_type': type,
  ///   'exam_number': number,
  ///   'teachers': [
  ///     {'teacher_id': '...', 'teacher_name': '...'},
  ///     ...
  ///   ]
  /// }
  final List<Map<String, dynamic>> timetableEntries;

  /// Academic year (e.g., "2025-2026")
  final String academicYear;

  AutoAssignQuestionPapersParams({
    required this.timetableId,
    required this.tenantId,
    required this.timetableEntries,
    required this.academicYear,
  });
}
