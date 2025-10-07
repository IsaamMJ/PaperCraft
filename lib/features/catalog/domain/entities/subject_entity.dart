// features/question_papers/domain/entities/subject_entity.dart
import 'package:equatable/equatable.dart';

class SubjectEntity extends Equatable {
  final String id;
  final String tenantId;
  final String catalogSubjectId;
  final String name;
  final String? description;
  final int? minGrade;
  final int? maxGrade;
  final bool isActive;
  final DateTime createdAt;

  const SubjectEntity({
    required this.id,
    required this.tenantId,
    required this.catalogSubjectId,
    required this.name,
    this.description,
    this.minGrade,
    this.maxGrade,
    required this.isActive,
    required this.createdAt,
  });

  /// Check if subject is available for a specific grade
  bool isAvailableForGrade(int grade) {
    if (minGrade == null || maxGrade == null) return true;
    return grade >= minGrade! && grade <= maxGrade!;
  }

  @override
  List<Object?> get props => [
    id,
    tenantId,
    catalogSubjectId,
    name,
    description,
    minGrade,
    maxGrade,
    isActive,
    createdAt,
  ];
}