import 'package:equatable/equatable.dart';

/// Represents marks configuration for a grade range in an exam calendar
///
/// Example:
/// ```dart
/// final config = MarkConfigEntity(
///   minGrade: 1,
///   maxGrade: 5,
///   totalMarks: 25,
///   label: 'Primary',
/// );
/// ```
class MarkConfigEntity extends Equatable {
  /// Minimum grade number for this configuration
  /// Example: 1 for grades 1-5
  final int minGrade;

  /// Maximum grade number for this configuration
  /// Example: 5 for grades 1-5
  final int maxGrade;

  /// Total marks for this grade range
  /// Example: 25 for primary (grades 1-5)
  final int totalMarks;

  /// Human-readable label for this grade range
  /// Example: 'Primary', 'Secondary', 'Senior'
  /// Optional - useful for display in UI
  final String? label;

  const MarkConfigEntity({
    required this.minGrade,
    required this.maxGrade,
    required this.totalMarks,
    this.label,
  });

  /// Create a copy with optional field overrides
  MarkConfigEntity copyWith({
    int? minGrade,
    int? maxGrade,
    int? totalMarks,
    String? label,
  }) {
    return MarkConfigEntity(
      minGrade: minGrade ?? this.minGrade,
      maxGrade: maxGrade ?? this.maxGrade,
      totalMarks: totalMarks ?? this.totalMarks,
      label: label ?? this.label,
    );
  }

  /// Get grade range as string (e.g., "1-5")
  String get gradeRangeDisplay => '$minGrade-$maxGrade';

  /// Check if a specific grade falls within this configuration
  bool containsGrade(int grade) {
    return grade >= minGrade && grade <= maxGrade;
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'min_grade': minGrade,
      'max_grade': maxGrade,
      'total_marks': totalMarks,
      'label': label,
    };
  }

  /// Create from JSON
  factory MarkConfigEntity.fromJson(Map<String, dynamic> json) {
    return MarkConfigEntity(
      minGrade: json['min_grade'] as int,
      maxGrade: json['max_grade'] as int,
      totalMarks: json['total_marks'] as int,
      label: json['label'] as String?,
    );
  }

  @override
  String toString() {
    final labelStr = label != null ? ' ($label)' : '';
    return 'MarkConfigEntity($minGrade-$maxGrade: $totalMarks marks$labelStr)';
  }

  @override
  List<Object?> get props => [minGrade, maxGrade, totalMarks, label];
}
