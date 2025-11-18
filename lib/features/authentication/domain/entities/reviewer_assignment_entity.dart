import 'package:equatable/equatable.dart';

class ReviewerAssignmentEntity extends Equatable {
  final String id;
  final String tenantId;
  final String reviewerId;
  final int gradeMin;
  final int gradeMax;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReviewerAssignmentEntity({
    required this.id,
    required this.tenantId,
    required this.reviewerId,
    required this.gradeMin,
    required this.gradeMax,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
    id,
    tenantId,
    reviewerId,
    gradeMin,
    gradeMax,
    createdAt,
    updatedAt,
  ];
}
