// features/catalog/domain/entities/exam_type.dart

enum ExamType {
  monthlyTest,
  dailyTest,
  quarterlyExam,
  annualExam;

  /// Display name for UI
  String get displayName {
    switch (this) {
      case ExamType.monthlyTest:
        return 'Monthly Test';
      case ExamType.dailyTest:
        return 'Daily Test';
      case ExamType.quarterlyExam:
        return 'Quarterly Exam';
      case ExamType.annualExam:
        return 'Annual Exam';
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
