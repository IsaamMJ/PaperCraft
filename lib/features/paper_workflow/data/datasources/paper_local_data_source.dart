// features/question_papers/data/datasources/paper_local_data_source.dart
import '../models/question_paper_model.dart';

abstract class PaperLocalDataSource {
  Future<void> saveDraft(QuestionPaperModel paper);
  Future<List<QuestionPaperModel>> getDrafts();
  Future<QuestionPaperModel?> getDraftById(String id);
  Future<void> deleteDraft(String id);
  Future<void> clearAllDrafts();
  Future<List<QuestionPaperModel>> searchDrafts({
    String? subject,
    String? title,
    DateTime? fromDate,
    DateTime? toDate,
  });
}