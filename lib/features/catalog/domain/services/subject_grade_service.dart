// features/question_papers/domain/services/subject_grade_service.dart
import '../entities/subject_entity.dart';

class SubjectGradeService {
  // Configuration for which subjects are available at which grade levels
  // This provides grade-level filtering for database-sourced subjects
  static const Map<String, List<int>> _subjectGradeLevels = {
    // Core subjects available at all levels
    'Mathematics': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    'English': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    'Environmental Studies': [1, 2, 3, 4, 5], // Updated to match database
    'Science': [1, 2, 3, 4, 5, 6, 7, 8],
    'Hindi': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],

    // Science subjects for higher grades
    'Physics': [9, 10, 11, 12],
    'Chemistry': [9, 10, 11, 12],
    'Biology': [9, 10, 11, 12],

    // Social studies
    'Social Studies': [3, 4, 5, 6, 7, 8], // Updated to match database
    'History': [3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    'Geography': [3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    'Civics': [6, 7, 8, 9, 10, 11, 12],

    // Additional subjects from database
    'Computer Science': [6, 7, 8, 9, 10, 11, 12],
    'Art & Craft': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    'Physical Education': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    'Music': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    'Tamil': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    'Sanskrit': [6, 7, 8, 9, 10, 11, 12],
    'Economics': [9, 10, 11, 12],
    'Psychology': [11, 12],
    'Philosophy': [11, 12],
    'Business Studies': [11, 12],

    // Legacy subjects (for backward compatibility)
    'French': [6, 7, 8, 9, 10, 11, 12],
    'German': [9, 10, 11, 12],
    'Information Technology': [9, 10, 11, 12],
    'Accountancy': [11, 12],
    'Home Science': [9, 10, 11, 12],
    'Agriculture': [9, 10, 11, 12],
    'Art': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], // Alias for Art & Craft
  };

  /// Filter database-sourced subjects that are appropriate for the given grade level
  static List<SubjectEntity> filterSubjectsByGrade(
      List<SubjectEntity> allSubjects,
      int gradeLevel
      ) {
    return allSubjects.where((subject) {
      // Check if the subject has grade level configuration
      final allowedGrades = _subjectGradeLevels[subject.name];

      if (allowedGrades != null) {
        // Use configured grade levels
        return allowedGrades.contains(gradeLevel);
      } else {
        // For subjects not in configuration, apply default logic
        return _applyDefaultGradeLogic(subject.name, gradeLevel);
      }
    }).toList();
  }

  /// Apply default logic for subjects not explicitly configured
  static bool _applyDefaultGradeLogic(String subjectName, int gradeLevel) {
    final lowerName = subjectName.toLowerCase();

    // Core subjects are generally available at all levels
    if (lowerName.contains('math') ||
        lowerName.contains('english') ||
        lowerName.contains('science') ||
        lowerName.contains('hindi') ||
        lowerName.contains('physical') ||
        lowerName.contains('art')) {
      return true;
    }

    // Advanced subjects typically start from grade 9
    if (lowerName.contains('economics') ||
        lowerName.contains('psychology') ||
        lowerName.contains('philosophy') ||
        lowerName.contains('business')) {
      return gradeLevel >= 9;
    }

    // Computer subjects typically start from grade 6
    if (lowerName.contains('computer') || lowerName.contains('technology')) {
      return gradeLevel >= 6;
    }

    // Language subjects (other than English/Hindi) typically start from grade 6
    if (lowerName.contains('tamil') ||
        lowerName.contains('sanskrit') ||
        lowerName.contains('french') ||
        lowerName.contains('german')) {
      return gradeLevel >= 6;
    }

    // If we can't determine, allow for all grades (safer default)
    return true;
  }

  /// Check if a subject is available for a specific grade level
  static bool isSubjectAvailableForGrade(String subjectName, int gradeLevel) {
    final allowedGrades = _subjectGradeLevels[subjectName];
    if (allowedGrades != null) {
      return allowedGrades.contains(gradeLevel);
    }
    return _applyDefaultGradeLogic(subjectName, gradeLevel);
  }

  /// Get all subjects available for a specific grade level (from configuration only)
  static List<String> getSubjectsForGrade(int gradeLevel) {
    return _subjectGradeLevels.entries
        .where((entry) => entry.value.contains(gradeLevel))
        .map((entry) => entry.key)
        .toList()
      ..sort();
  }

  /// Get grade levels where a subject is available (from configuration only)
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

  /// Get statistics about grade level distribution for debugging
  static Map<String, dynamic> getGradeDistributionStats() {
    final stats = <int, int>{};

    for (final gradeList in _subjectGradeLevels.values) {
      for (final grade in gradeList) {
        stats[grade] = (stats[grade] ?? 0) + 1;
      }
    }

    return {
      'totalConfiguredSubjects': _subjectGradeLevels.length,
      'gradeDistribution': stats,
      'averageSubjectsPerGrade': stats.values.isNotEmpty
          ? stats.values.reduce((a, b) => a + b) / stats.length
          : 0,
    };
  }
}