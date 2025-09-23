// features/question_papers/domain/services/subject_grade_service.dart
import '../entities/subject_entity.dart';

class SubjectGradeService {
  // Configuration for which subjects are available at which grade levels
  // This can be moved to a database table later if needed
  static const Map<String, List<int>> _subjectGradeLevels = {
    // Core subjects available at all levels
    'Mathematics': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    'English': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    'Science': [1, 2, 3, 4, 5, 6, 7, 8],

    // Subject branches for higher grades
    'Physics': [9, 10, 11, 12],
    'Chemistry': [9, 10, 11, 12],
    'Biology': [9, 10, 11, 12],

    // Social studies
    'History': [3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    'Geography': [3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    'Civics': [6, 7, 8, 9, 10, 11, 12],

    // Languages
    'Hindi': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    'Sanskrit': [6, 7, 8, 9, 10, 11, 12],
    'French': [6, 7, 8, 9, 10, 11, 12],
    'German': [9, 10, 11, 12],

    // Specialized subjects
    'Computer Science': [6, 7, 8, 9, 10, 11, 12],
    'Information Technology': [9, 10, 11, 12],
    'Economics': [9, 10, 11, 12],
    'Psychology': [11, 12],
    'Philosophy': [11, 12],
    'Business Studies': [11, 12],
    'Accountancy': [11, 12],

    // Arts subjects
    'Art': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    'Music': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    'Physical Education': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],

    // Vocational subjects
    'Home Science': [9, 10, 11, 12],
    'Agriculture': [9, 10, 11, 12],
  };

  /// Filter subjects that are appropriate for the given grade level
  static List<SubjectEntity> filterSubjectsByGrade(
      List<SubjectEntity> allSubjects,
      int gradeLevel
      ) {
    return allSubjects.where((subject) {
      final allowedGrades = _subjectGradeLevels[subject.name];
      return allowedGrades?.contains(gradeLevel) ?? true; // If not configured, allow all
    }).toList();
  }

  /// Check if a subject is available for a specific grade level
  static bool isSubjectAvailableForGrade(String subjectName, int gradeLevel) {
    final allowedGrades = _subjectGradeLevels[subjectName];
    return allowedGrades?.contains(gradeLevel) ?? true;
  }

  /// Get all subjects available for a specific grade level
  static List<String> getSubjectsForGrade(int gradeLevel) {
    return _subjectGradeLevels.entries
        .where((entry) => entry.value.contains(gradeLevel))
        .map((entry) => entry.key)
        .toList()
      ..sort();
  }

  /// Get grade levels where a subject is available
  static List<int> getGradeLevelsForSubject(String subjectName) {
    return _subjectGradeLevels[subjectName] ?? [];
  }

  /// Get a map of all configured subjects and their grade levels
  static Map<String, List<int>> getAllSubjectGradeMappings() {
    return Map.unmodifiable(_subjectGradeLevels);
  }

  /// Check if we need to filter subjects (returns false if grade level is null)
  static bool shouldFilterSubjects(int? gradeLevel) {
    return gradeLevel != null;
  }
}