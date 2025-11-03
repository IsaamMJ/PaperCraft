import 'package:equatable/equatable.dart';

/// Represents the exact (Grade, Subject, Section) tuple a teacher teaches
///
/// Replaces the cartesian product problem where teachers selected
/// Grade [1,2] + Subject [Maths, English] = 4 combos.
///
/// Now teachers explicitly assign exact tuples:
/// - Grade 5, Section A, Maths
/// - Grade 5, Section A, English
/// - Grade 5, Section B, Maths
class TeacherSubject extends Equatable {
  final String id;
  final String tenantId;
  final String teacherId;
  final String gradeId;
  final String subjectId;
  final String section;
  final String academicYear;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TeacherSubject({
    required this.id,
    required this.tenantId,
    required this.teacherId,
    required this.gradeId,
    required this.subjectId,
    required this.section,
    required this.academicYear,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// User-friendly display: "Grade 5-A Maths"
  String get displayName => '$gradeId-$section $subjectId';

  /// Create a copy of this object with modified fields
  TeacherSubject copyWith({
    String? id,
    String? tenantId,
    String? teacherId,
    String? gradeId,
    String? subjectId,
    String? section,
    String? academicYear,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TeacherSubject(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      teacherId: teacherId ?? this.teacherId,
      gradeId: gradeId ?? this.gradeId,
      subjectId: subjectId ?? this.subjectId,
      section: section ?? this.section,
      academicYear: academicYear ?? this.academicYear,
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
      'teacher_id': teacherId,
      'grade_id': gradeId,
      'subject_id': subjectId,
      'section': section,
      'academic_year': academicYear,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON response from API
  factory TeacherSubject.fromJson(Map<String, dynamic> json) {
    return TeacherSubject(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      teacherId: json['teacher_id'] as String,
      gradeId: json['grade_id'] as String,
      subjectId: json['subject_id'] as String,
      section: json['section'] as String,
      academicYear: json['academic_year'] as String,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id,
    tenantId,
    teacherId,
    gradeId,
    subjectId,
    section,
    academicYear,
    isActive,
    createdAt,
    updatedAt,
  ];

  @override
  String toString() =>
      'TeacherSubject(teacherId: $teacherId, displayName: $displayName, academicYear: $academicYear)';
}
