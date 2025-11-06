// features/assignments/domain/entities/teacher_subject_assignment_entity.dart
import 'package:equatable/equatable.dart';

/// Enhanced entity for teacher subject assignments
/// Tracks: Teacher → Grade → Section → Subject assignments
class TeacherSubjectAssignmentEntity extends Equatable {
  // Primary identifiers
  final String id;
  final String tenantId;
  final String teacherId;
  final String gradeId;
  final String subjectId;

  // Display fields (for UI, from database joins)
  final String? teacherName;
  final String? teacherEmail;
  final int? gradeNumber;
  final String? section;
  final String? subjectName;

  // Metadata
  final String academicYear;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const TeacherSubjectAssignmentEntity({
    required this.id,
    required this.tenantId,
    required this.teacherId,
    required this.gradeId,
    required this.subjectId,
    this.teacherName,
    this.teacherEmail,
    this.gradeNumber,
    this.section,
    this.subjectName,
    required this.academicYear,
    this.startDate,
    this.endDate,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create a copy with modified fields
  TeacherSubjectAssignmentEntity copyWith({
    String? id,
    String? tenantId,
    String? teacherId,
    String? gradeId,
    String? subjectId,
    String? teacherName,
    String? teacherEmail,
    int? gradeNumber,
    String? section,
    String? subjectName,
    String? academicYear,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TeacherSubjectAssignmentEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      teacherId: teacherId ?? this.teacherId,
      gradeId: gradeId ?? this.gradeId,
      subjectId: subjectId ?? this.subjectId,
      teacherName: teacherName ?? this.teacherName,
      teacherEmail: teacherEmail ?? this.teacherEmail,
      gradeNumber: gradeNumber ?? this.gradeNumber,
      section: section ?? this.section,
      subjectName: subjectName ?? this.subjectName,
      academicYear: academicYear ?? this.academicYear,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get composite key for grade+section grouping
  String get gradeSection => '$gradeNumber:$section';

  /// Check if assignment is valid for display
  bool get isValid => gradeNumber != null && section != null && subjectName != null;

  @override
  List<Object?> get props => [
    id,
    tenantId,
    teacherId,
    gradeId,
    subjectId,
    teacherName,
    teacherEmail,
    gradeNumber,
    section,
    subjectName,
    academicYear,
    startDate,
    endDate,
    isActive,
    createdAt,
    updatedAt,
  ];

  @override
  String toString() =>
      'TeacherSubjectAssignment(teacher: $teacherName, grade: $gradeNumber, section: $section, subject: $subjectName, year: $academicYear)';
}