
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/question_paper_entity.dart';

abstract class QuestionPaperRepository {
  // =============== DRAFT OPERATIONS (Local Storage) ===============
  Future<Either<Failure, QuestionPaperEntity>> saveDraft(QuestionPaperEntity paper);
  Future<Either<Failure, List<QuestionPaperEntity>>> getDrafts();
  Future<Either<Failure, QuestionPaperEntity?>> getDraftById(String id);
  Future<Either<Failure, void>> deleteDraft(String id);

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
}