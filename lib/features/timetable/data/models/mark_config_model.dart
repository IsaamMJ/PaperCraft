import '../../domain/entities/mark_config_entity.dart';

/// Model class for MarkConfig - used for JSON serialization/deserialization
class MarkConfigModel extends MarkConfigEntity {
  const MarkConfigModel({
    required int minGrade,
    required int maxGrade,
    required int totalMarks,
    String? label,
  }) : super(
    minGrade: minGrade,
    maxGrade: maxGrade,
    totalMarks: totalMarks,
    label: label,
  );

  /// Create from JSON (API responses/database)
  factory MarkConfigModel.fromJson(Map<String, dynamic> json) {
    return MarkConfigModel(
      minGrade: json['min_grade'] as int,
      maxGrade: json['max_grade'] as int,
      totalMarks: json['total_marks'] as int,
      label: json['label'] as String?,
    );
  }

  /// Create from entity
  factory MarkConfigModel.fromEntity(MarkConfigEntity entity) {
    return MarkConfigModel(
      minGrade: entity.minGrade,
      maxGrade: entity.maxGrade,
      totalMarks: entity.totalMarks,
      label: entity.label,
    );
  }

  /// Convert to JSON
  @override
  Map<String, dynamic> toJson() {
    return {
      'min_grade': minGrade,
      'max_grade': maxGrade,
      'total_marks': totalMarks,
      'label': label,
    };
  }

  /// Convert to entity
  MarkConfigEntity toEntity() {
    return MarkConfigEntity(
      minGrade: minGrade,
      maxGrade: maxGrade,
      totalMarks: totalMarks,
      label: label,
    );
  }
}
