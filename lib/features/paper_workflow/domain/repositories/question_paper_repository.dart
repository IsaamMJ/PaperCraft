
import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../../../../core/domain/models/paginated_result.dart';
import '../entities/question_paper_entity.dart';

abstract class QuestionPaperRepository {
  // =============== DRAFT OPERATIONS (Local Storage) ===============
  Future<Either<Failure, QuestionPaperEntity>> saveDraft(QuestionPaperEntity paper);
  Future<Either<Failure, List<QuestionPaperEntity>>> getDrafts();
  Future<Either<Failure, QuestionPaperEntity?>> getDraftById(String id);
  Future<Either<Failure, void>> deleteDraft(String id);


  Future<Either<Failure, List<QuestionPaperEntity>>> getAllPapersForAdmin();

  /// Get all approved papers for question bank (visible to everyone)
  Future<Either<Failure, List<QuestionPaperEntity>>> getApprovedPapers();

  /// Get approved papers with pagination and filters
  Future<Either<Failure, PaginatedResult<QuestionPaperEntity>>> getApprovedPapersPaginated({
    required int page,
    required int pageSize,
    String? searchQuery,
    String? subjectFilter,
    String? gradeFilter,
  });

  /// Get approved papers by exam date range (for office staff dashboard)
  Future<Either<Failure, List<QuestionPaperEntity>>> getApprovedPapersByExamDateRange({
    required DateTime fromDate,
    required DateTime toDate,
  });

  // =============== SUBMISSION OPERATIONS (Cloud Storage) ===============
  Future<Either<Failure, QuestionPaperEntity>> submitPaper(QuestionPaperEntity paper);
  Future<Either<Failure, List<QuestionPaperEntity>>> getUserSubmissions();
  Future<Either<Failure, List<QuestionPaperEntity>>> getPapersForReview();

  // =============== APPROVAL OPERATIONS (Admin Only) ===============
  Future<Either<Failure, QuestionPaperEntity>> approvePaper(String id);
  Future<Either<Failure, QuestionPaperEntity>> rejectPaper(String id, String reason);

  // =============== EDITING OPERATIONS ===============
  Future<Either<Failure, QuestionPaperEntity>> pullForEditing(String id);

  // =============== SEARCH AND QUERY ===============
  Future<Either<Failure, List<QuestionPaperEntity>>> searchPapers({
    String? title,
    String? subject,
    String? status,
    String? createdBy,
  });

  Future<Either<Failure, QuestionPaperEntity?>> getPaperById(String id);

  // =============== REJECTION HISTORY ===============
  Future<Either<Failure, List<Map<String, dynamic>>>> getRejectionHistory(String paperId);
}