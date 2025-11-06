import 'package:equatable/equatable.dart';

/// Represents a subject assigned to a specific grade + section combination
///
/// Example: Grade 10, Section A has Math, Science, English
/// Each assignment is tracked separately for flexibility
class GradeSubject extends Equatable {
  final String id;
  final String tenantId;
  final String gradeId;
  final String sectionId;
  final String subjectId;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GradeSubject({
    required this.id,
    required this.tenantId,
    required this.gradeId,
    required this.sectionId,
    required this.subjectId,
    required this.displayOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a copy of this object with modified fields
  GradeSubject copyWith({
    String? id,
    String? tenantId,
    String? gradeId,
    String? sectionId,
    String? subjectId,
    int? displayOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GradeSubject(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      gradeId: gradeId ?? this.gradeId,
      sectionId: sectionId ?? this.sectionId,
      subjectId: subjectId ?? this.subjectId,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tenantId,
    gradeId,
    sectionId,
    subjectId,
    displayOrder,
    isActive,
    createdAt,
    updatedAt,
  ];

  @override
  String toString() =>
      'GradeSubject(id: $id, gradeId: $gradeId, sectionId: $sectionId, subjectId: $subjectId)';
}
