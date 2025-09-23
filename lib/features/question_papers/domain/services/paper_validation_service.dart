import 'package:papercraft/features/question_papers/domain/services/subject_grade_service.dart';

import '../entities/exam_type_entity.dart';
import '../entities/question_paper_entity.dart';
import '../entities/subject_entity.dart';

class PaperValidationService {
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
    }

    if (gradeLevel == null) {
      errors.add('Grade level must be selected');
    } else if (gradeLevel < 1 || gradeLevel > 12) {
      errors.add('Grade level must be between 1 and 12');
    }

    if (selectedSections.isEmpty) {
      errors.add('At least one section must be selected');
    }

    if (selectedSubjects.isEmpty) {
      errors.add('At least one subject must be selected');
    }

    if (examType == null) {
      errors.add('Exam type must be selected');
    }

    // Validate subject-grade compatibility
    if (gradeLevel != null) {
      for (final subject in selectedSubjects) {
        if (!SubjectGradeService.isSubjectAvailableForGrade(subject.name, gradeLevel)) {
          errors.add('${subject.name} is not available for Grade $gradeLevel');
        }
      }
    }

    return errors;
  }

  static bool isPaperCompleteForSubmission(QuestionPaperEntity paper) {
    return paper.isComplete &&
        paper.gradeLevel != null &&
        paper.selectedSections.isNotEmpty;
  }
}
