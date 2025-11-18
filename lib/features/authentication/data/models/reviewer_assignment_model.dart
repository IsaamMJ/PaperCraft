import '../../domain/entities/reviewer_assignment_entity.dart';

class ReviewerAssignmentModel {
  final String id;
  final String tenantId;
  final String reviewerId;
  final int gradeMin;
  final int gradeMax;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReviewerAssignmentModel({
    required this.id,
    required this.tenantId,
    required this.reviewerId,
    required this.gradeMin,
    required this.gradeMax,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReviewerAssignmentModel.fromJson(Map<String, dynamic> json) {
    return ReviewerAssignmentModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      reviewerId: json['reviewer_id'] as String,
      gradeMin: json['grade_min'] as int,
      gradeMax: json['grade_max'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  ReviewerAssignmentEntity toEntity() {
    return ReviewerAssignmentEntity(
      id: id,
      tenantId: tenantId,
      reviewerId: reviewerId,
      gradeMin: gradeMin,
      gradeMax: gradeMax,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
