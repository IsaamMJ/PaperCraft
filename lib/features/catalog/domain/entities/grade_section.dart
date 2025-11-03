import 'package:equatable/equatable.dart';

/// Represents a section (A, B, C, etc.) within a grade
///
/// Example: Grade 5 has sections [A, B, C]
/// Each school can have different number of sections per grade
class GradeSection extends Equatable {
  final String id;
  final String tenantId;
  final String gradeId;
  final String sectionName;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GradeSection({
    required this.id,
    required this.tenantId,
    required this.gradeId,
    required this.sectionName,
    required this.displayOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a copy of this object with modified fields
  GradeSection copyWith({
    String? id,
    String? tenantId,
    String? gradeId,
    String? sectionName,
    int? displayOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GradeSection(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      gradeId: gradeId ?? this.gradeId,
      sectionName: sectionName ?? this.sectionName,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'grade_id': gradeId,
      'section_name': sectionName,
      'display_order': displayOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON response from API
  factory GradeSection.fromJson(Map<String, dynamic> json) {
    return GradeSection(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      gradeId: json['grade_id'] as String,
      sectionName: json['section_name'] as String,
      displayOrder: json['display_order'] as int,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id,
    tenantId,
    gradeId,
    sectionName,
    displayOrder,
    isActive,
    createdAt,
    updatedAt,
  ];

  @override
  String toString() =>
      'GradeSection(id: $id, gradeId: $gradeId, sectionName: $sectionName)';
}
