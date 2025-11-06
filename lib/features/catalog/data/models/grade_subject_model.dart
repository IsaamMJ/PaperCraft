import '../../domain/entities/grade_subject.dart';

/// Data model for grade_section_subject table
/// Handles JSON serialization/deserialization for Supabase
/// Maps to the actual database schema with:
/// - section: text (section name, not UUID)
/// - is_offered: boolean (not is_active)
class GradeSubjectModel {
  final String id;
  final String tenantId;
  final String gradeId;
  final String section; // Section name (text), not UUID
  final String subjectId;
  final int displayOrder;
  final bool isOffered; // Renamed from isActive to match schema
  final DateTime createdAt;
  final DateTime updatedAt;

  const GradeSubjectModel({
    required this.id,
    required this.tenantId,
    required this.gradeId,
    required this.section,
    required this.subjectId,
    required this.displayOrder,
    required this.isOffered,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Parse from Supabase JSON response
  factory GradeSubjectModel.fromJson(Map<String, dynamic> json) {
    return GradeSubjectModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      gradeId: json['grade_id'] as String,
      section: json['section'] as String, // text field from database
      subjectId: json['subject_id'] as String,
      displayOrder: json['display_order'] as int,
      isOffered: json['is_offered'] as bool, // is_offered from database
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert to JSON for Supabase insert/update
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'grade_id': gradeId,
      'section': section, // text field
      'subject_id': subjectId,
      'display_order': displayOrder,
      'is_offered': isOffered, // is_offered field
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert model to domain entity
  GradeSubject toEntity() {
    return GradeSubject(
      id: id,
      tenantId: tenantId,
      gradeId: gradeId,
      sectionId: section, // Map section (String) to sectionId in entity
      subjectId: subjectId,
      displayOrder: displayOrder,
      isActive: isOffered, // Map isOffered to isActive in entity
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Create model from domain entity
  factory GradeSubjectModel.fromEntity(GradeSubject entity) {
    return GradeSubjectModel(
      id: entity.id,
      tenantId: entity.tenantId,
      gradeId: entity.gradeId,
      section: entity.sectionId, // Map sectionId (String) to section
      subjectId: entity.subjectId,
      displayOrder: entity.displayOrder,
      isOffered: entity.isActive, // Map isActive to isOffered
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
