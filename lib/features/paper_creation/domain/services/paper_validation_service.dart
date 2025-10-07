// features/paper_workflow/domain/services/paper_validation_service.dart
import '../../../catalog/domain/entities/exam_type_entity.dart';
import '../../../catalog/domain/entities/subject_entity.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';

class PaperValidationService {
  /// Validate paper for creation (before generating entity)
  static List<String> validatePaperForCreation({
    required String title,
    required int? gradeLevel,
    required List<String> selectedSections,
    required List<SubjectEntity> selectedSubjects,
    required ExamTypeEntity? examType,
  }) {
    final errors = <String>[];

    if (title.trim().isEmpty) {
      errors.add('Paper title is required');
    } else if (title.trim().length < 3) {
      errors.add('Paper title must be at least 3 characters');
    }

    if (gradeLevel == null) {
      errors.add('Grade level must be selected');
    }

    if (selectedSubjects.isEmpty) {
      errors.add('At least one subject must be selected');
    }

    if (examType == null) {
      errors.add('Exam type must be selected');
    }

    // Note: selectedSections can be empty if there are no sections for the grade
    // This is valid, so we don't validate it here

    return errors;
  }

  /// Check if paper is ready for submission
  static bool isPaperCompleteForSubmission(QuestionPaperEntity paper) {
    return paper.isComplete &&
        paper.gradeId.isNotEmpty &&
        paper.subjectId.isNotEmpty;
  }

  /// Validate paper entity completeness
  static List<String> validatePaperEntity(QuestionPaperEntity paper) {
    return paper.validationErrors;
  }
}