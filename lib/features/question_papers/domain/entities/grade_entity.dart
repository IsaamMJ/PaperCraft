// features/question_papers/domain/entities/grade_entity.dart
import 'package:equatable/equatable.dart';

class GradeEntity extends Equatable {
  final String id;
  final String tenantId;
  final int gradeNumber;
  final bool isActive;
  final DateTime createdAt;

  const GradeEntity({
    required this.id,
    required this.tenantId,
    required this.gradeNumber,
    required this.isActive,
    required this.createdAt,
  });

  /// Display name for UI (e.g., "Grade 5")
  String get displayName => 'Grade $gradeNumber';

  @override
  List<Object?> get props => [id, tenantId, gradeNumber, isActive, createdAt];
}