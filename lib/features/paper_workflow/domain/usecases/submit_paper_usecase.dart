// features/paper_workflow/domain/usecases/submit_paper_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/question_paper_entity.dart';
import '../repositories/question_paper_repository.dart';

/// Use case for submitting a question paper for review/approval
///
/// Business Logic:
/// - Validates paper is complete and ready to submit
/// - Performs checks on question count, marks, sections
/// - Marks validation: Compares paper total marks against exam calendar max marks
///   (Validation is performed at repository level to access exam_calendar)
/// - Sets submitted_at timestamp
/// - Paper status changes from 'draft' to 'submitted'
///
/// Validation Checks:
/// - All required questions present
/// - Paper sections complete
/// - Valid marks in all questions
/// - Total marks within allowed limit (from exam_calendar marks_config)
///
/// Note on Marks Validation:
/// When a paper is auto-assigned from a timetable, it includes:
/// - exam_timetable_entry_id: Link to the specific exam entry
/// The repository's submitPaper method will:
/// 1. Fetch the exam_timetable_entry using exam_timetable_entry_id
/// 2. Get associated exam_calendar and marks_config
/// 3. Extract max_marks for the paper's grade range
/// 4. Validate: paper.totalMarks <= max_marks
/// 5. Return ValidationFailure if marks exceed limit
///
class SubmitPaperUseCase {
  final QuestionPaperRepository repository;

  SubmitPaperUseCase(this.repository);

  /// Submit a question paper for review
  ///
  /// Parameters:
  /// - [paper] - The question paper entity to submit
  ///
  /// Returns:
  /// - [Either<Failure, QuestionPaperEntity>] - Submitted paper or validation failure
  ///
  /// Validation Errors:
  /// - Paper not in draft status
  /// - Incomplete questions/sections
  /// - Invalid marks
  /// - Exceeds exam calendar max marks
  Future<Either<Failure, QuestionPaperEntity>> call(QuestionPaperEntity paper) async {
    // Local validation
    if (!paper.canSubmit) {
      return Left(ValidationFailure(
        'Paper cannot be submitted: ${paper.validationErrors.join(", ")}',
      ));
    }

    // Submit to repository (which includes marks validation against exam_calendar)
    return await repository.submitPaper(paper);
  }
}