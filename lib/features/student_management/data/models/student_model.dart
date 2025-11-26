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
    super.gender,
    super.dateOfBirth,
    required super.academicYear,
    required super.isActive,
    required super.createdAt,
    required super.updatedAt,
    super.gradeNumber,
    super.sectionName,
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
      gender: entity.gender,
      dateOfBirth: entity.dateOfBirth,
      academicYear: entity.academicYear,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      gradeNumber: entity.gradeNumber,
      sectionName: entity.sectionName,
    );
  }

  /// Create a StudentModel from JSON (from API/database)
  factory StudentModel.fromJson(Map<String, dynamic> json) {
    DateTime? dateOfBirth;
    final dobString = json['date_of_birth'] as String?;
    if (dobString != null && dobString.isNotEmpty) {
      try {
        // Try YYYY-MM-DD format first (ISO 8601)
        dateOfBirth = DateTime.parse(dobString);
      } catch (e) {
        // Try DD-MM-YYYY format
        try {
          final parts = dobString.split('-');
          if (parts.length == 3) {
            final day = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final year = int.parse(parts[2]);
            dateOfBirth = DateTime(year, month, day);
          }
        } catch (e2) {
          dateOfBirth = null;
        }
      }
    }

    return StudentModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      gradeSectionId: json['grade_section_id'] as String,
      rollNumber: json['roll_number'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      gender: json['gender'] as String?,
      dateOfBirth: dateOfBirth,
      academicYear: json['academic_year'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      gradeNumber: json['grade_number'] as int?,
      sectionName: json['section_name'] as String?,
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
      'gender': gender,
      'date_of_birth': dateOfBirth?.toIso8601String(),
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
      'gender': gender,
      'date_of_birth': dateOfBirth != null ? dateOfBirth!.toIso8601String().split('T')[0] : null,
      'academic_year': academicYear,
      'is_active': isActive,
      if (gradeNumber != null) 'grade_number': gradeNumber,
      if (sectionName != null) 'section_name': sectionName,
    };
  }

  /// Create a copy with modified fields
  @override
  StudentModel copyWith({
    String? id,
    String? tenantId,
    String? gradeSectionId,
    String? rollNumber,
    String? fullName,
    String? email,
    String? phone,
    String? gender,
    DateTime? dateOfBirth,
    String? academicYear,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? gradeNumber,
    String? sectionName,
  }) {
    return StudentModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      gradeSectionId: gradeSectionId ?? this.gradeSectionId,
      rollNumber: rollNumber ?? this.rollNumber,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      academicYear: academicYear ?? this.academicYear,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      gradeNumber: gradeNumber ?? this.gradeNumber,
      sectionName: sectionName ?? this.sectionName,
    );
  }
}
