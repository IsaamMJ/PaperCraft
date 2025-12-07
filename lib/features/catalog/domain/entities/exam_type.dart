// features/catalog/domain/entities/exam_type.dart

enum ExamType {
  monthlyTest,
  halfYearly,
  quarterlyTest,
  finalExam,
  dailyTest;

  /// Display name for UI
  String get displayName {
    switch (this) {
      case ExamType.monthlyTest:
        return 'Monthly Test';
      case ExamType.halfYearly:
        return 'Half Yearly Examination';
      case ExamType.quarterlyTest:
        return 'Quarterly Examination';
      case ExamType.finalExam:
        return 'Final Examination';
      case ExamType.dailyTest:
        return 'Daily Test';
    }
  }

  /// Serialization to string for database storage
  String toJson() => name;

  /// Deserialization from string
  static ExamType fromJson(String value) {
    return ExamType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ExamType.monthlyTest,
    );
  }

  /// Get all exam types for dropdown
  static List<ExamType> get allTypes => ExamType.values;
}
