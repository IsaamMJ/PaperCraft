import 'package:papercraft/features/student_management/domain/entities/student_entity.dart';

/// Data model for StudentEntity
/// Handles JSON serialization/deserialization and conversion to/from entities
class StudentModel extends StudentEntity {
  const StudentModel({
    required super.id,
    required super.tenantId,
    required super.gradeSectionId,
    required super.rollNumber,
    required super.fullName,
    super.email,
    super.phone,
    required super.academicYear,
    required super.isActive,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Create a StudentModel from a StudentEntity
  factory StudentModel.fromEntity(StudentEntity entity) {
    return StudentModel(
      id: entity.id,
      tenantId: entity.tenantId,
      gradeSectionId: entity.gradeSectionId,
      rollNumber: entity.rollNumber,
      fullName: entity.fullName,
      email: entity.email,
      phone: entity.phone,
      academicYear: entity.academicYear,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Create a StudentModel from JSON (from API/database)
  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      gradeSectionId: json['grade_section_id'] as String,
      rollNumber: json['roll_number'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      academicYear: json['academic_year'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert StudentModel to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'grade_section_id': gradeSectionId,
      'roll_number': rollNumber,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'academic_year': academicYear,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert to JSON request format (for creating/updating students)
  Map<String, dynamic> toJsonRequest() {
    return {
      'tenant_id': tenantId,
      'grade_section_id': gradeSectionId,
      'roll_number': rollNumber,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'academic_year': academicYear,
      'is_active': isActive,
    };
  }

  /// Create a copy with modified fields
  StudentModel copyWith({
    String? id,
    String? tenantId,
    String? gradeSectionId,
    String? rollNumber,
    String? fullName,
    String? email,
    String? phone,
    String? academicYear,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudentModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      gradeSectionId: gradeSectionId ?? this.gradeSectionId,
      rollNumber: rollNumber ?? this.rollNumber,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      academicYear: academicYear ?? this.academicYear,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
