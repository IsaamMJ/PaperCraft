import 'package:equatable/equatable.dart';

/// Entity representing a student in the system
///
/// A student is enrolled in a specific grade and section for an academic year.
/// Students are linked to grade sections, which automatically determine their subjects.
class StudentEntity extends Equatable {
  final String id;
  final String tenantId;
  final String gradeSectionId;
  final String rollNumber;
  final String fullName;
  final String? email;
  final String? phone;
  final String? gender; // M, F, or other
  final DateTime? dateOfBirth;
  final String academicYear;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? gradeNumber; // Grade number (e.g., 1, 2, 3...)
  final String? sectionName; // Section name (e.g., A, B, C...)

  const StudentEntity({
    required this.id,
    required this.tenantId,
    required this.gradeSectionId,
    required this.rollNumber,
    required this.fullName,
    this.email,
    this.phone,
    this.gender,
    this.dateOfBirth,
    required this.academicYear,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.gradeNumber,
    this.sectionName,
  });

  @override
  List<Object?> get props => [
        id,
        tenantId,
        gradeSectionId,
        rollNumber,
        fullName,
        email,
        phone,
        gender,
        dateOfBirth,
        academicYear,
        isActive,
        createdAt,
        updatedAt,
        gradeNumber,
        sectionName,
      ];

  @override
  String toString() =>
      'StudentEntity(id: $id, rollNumber: $rollNumber, fullName: $fullName, gradeSection: $gradeSectionId)';

  /// Create a copy with modified fields
  StudentEntity copyWith({
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
    return StudentEntity(
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
