import 'package:equatable/equatable.dart';

/// Enum for student exam mark status
enum StudentMarkStatus {
  present,
  absent,
  notAppeared,
  medicalLeave,
}

/// Extension to convert enum to string
extension StudentMarkStatusString on StudentMarkStatus {
  String toDbString() {
    switch (this) {
      case StudentMarkStatus.present:
        return 'present';
      case StudentMarkStatus.absent:
        return 'absent';
      case StudentMarkStatus.notAppeared:
        return 'not_appeared';
      case StudentMarkStatus.medicalLeave:
        return 'medical_leave';
    }
  }

  static StudentMarkStatus fromString(String value) {
    switch (value) {
      case 'present':
        return StudentMarkStatus.present;
      case 'absent':
        return StudentMarkStatus.absent;
      case 'not_appeared':
        return StudentMarkStatus.notAppeared;
      case 'medical_leave':
        return StudentMarkStatus.medicalLeave;
      default:
        return StudentMarkStatus.present;
    }
  }

  /// Get display name for UI
  String get displayName {
    switch (this) {
      case StudentMarkStatus.present:
        return 'Present';
      case StudentMarkStatus.absent:
        return 'Absent';
      case StudentMarkStatus.notAppeared:
        return 'Not Appeared';
      case StudentMarkStatus.medicalLeave:
        return 'Medical Leave';
    }
  }
}

/// Entity representing marks obtained by a student in an exam
///
/// Tracks:
/// - The marks obtained (0 to max marks for that exam)
/// - The status (present, absent, not appeared, medical leave)
/// - Who entered the marks and when
/// - Draft state for auto-save functionality
class StudentExamMarksEntity extends Equatable {
  final String id;
  final String tenantId;
  final String studentId;
  final String examTimetableEntryId;
  final double totalMarks;
  final StudentMarkStatus status;
  final String? remarks;
  final String enteredBy;
  final bool isDraft;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudentExamMarksEntity({
    required this.id,
    required this.tenantId,
    required this.studentId,
    required this.examTimetableEntryId,
    required this.totalMarks,
    required this.status,
    this.remarks,
    required this.enteredBy,
    required this.isDraft,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        tenantId,
        studentId,
        examTimetableEntryId,
        totalMarks,
        status,
        remarks,
        enteredBy,
        isDraft,
        isActive,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() =>
      'StudentExamMarksEntity(student: $studentId, exam: $examTimetableEntryId, marks: $totalMarks, status: ${status.displayName})';

  /// Create a copy with modified fields
  StudentExamMarksEntity copyWith({
    String? id,
    String? tenantId,
    String? studentId,
    String? examTimetableEntryId,
    double? totalMarks,
    StudentMarkStatus? status,
    String? remarks,
    String? enteredBy,
    bool? isDraft,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudentExamMarksEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      studentId: studentId ?? this.studentId,
      examTimetableEntryId: examTimetableEntryId ?? this.examTimetableEntryId,
      totalMarks: totalMarks ?? this.totalMarks,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      enteredBy: enteredBy ?? this.enteredBy,
      isDraft: isDraft ?? this.isDraft,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Wrapper class for marks submission summary
class MarksSubmissionSummary extends Equatable {
  final int totalStudents;
  final int markedPresent;
  final int absent;
  final int medicalLeave;
  final int notAppeared;
  final double average;
  final double highestMarks;
  final double lowestMarks;

  const MarksSubmissionSummary({
    required this.totalStudents,
    required this.markedPresent,
    required this.absent,
    required this.medicalLeave,
    required this.notAppeared,
    required this.average,
    required this.highestMarks,
    required this.lowestMarks,
  });

  @override
  List<Object?> get props => [
        totalStudents,
        markedPresent,
        absent,
        medicalLeave,
        notAppeared,
        average,
        highestMarks,
        lowestMarks,
      ];

  @override
  String toString() =>
      'MarksSubmissionSummary(total: $totalStudents, present: $markedPresent, average: $average)';
}
