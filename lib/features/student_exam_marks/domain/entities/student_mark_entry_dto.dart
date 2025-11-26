import 'package:equatable/equatable.dart';

/// DTO for a single student's marks entry
class StudentMarkEntryDto extends Equatable {
  final String studentId;
  final String studentName;
  final String studentRollNumber;
  final double totalMarks;
  final String status; // 'present' or 'absent'
  final String? remarks;

  const StudentMarkEntryDto({
    required this.studentId,
    required this.studentName,
    required this.studentRollNumber,
    required this.totalMarks,
    required this.status,
    this.remarks,
  });

  @override
  List<Object?> get props => [
    studentId,
    studentName,
    studentRollNumber,
    totalMarks,
    status,
    remarks,
  ];

  Map<String, dynamic> toSupabase(String examTimetableEntryId, String enteredBy) {
    return {
      'student_id': studentId,
      'exam_timetable_entry_id': examTimetableEntryId,
      'total_marks': totalMarks,
      'status': status,
      'remarks': remarks,
      'entered_by': enteredBy,
      'is_draft': false,
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}

/// Request DTO for bulk marks entry
class BulkMarksEntryRequest extends Equatable {
  final String examTimetableEntryId;
  final List<StudentMarkEntryDto> marks;
  final String enteredBy; // Teacher ID
  final bool isDraft; // true for save, false for submit

  const BulkMarksEntryRequest({
    required this.examTimetableEntryId,
    required this.marks,
    required this.enteredBy,
    required this.isDraft,
  });

  @override
  List<Object?> get props => [examTimetableEntryId, marks, enteredBy, isDraft];
}

/// Response DTO for marks submission
class MarksSubmissionResponse extends Equatable {
  final int totalRecordsUpdated;
  final List<String> successfulStudentIds;
  final List<String> failedStudentIds;
  final String message;

  const MarksSubmissionResponse({
    required this.totalRecordsUpdated,
    required this.successfulStudentIds,
    required this.failedStudentIds,
    required this.message,
  });

  @override
  List<Object?> get props => [
    totalRecordsUpdated,
    successfulStudentIds,
    failedStudentIds,
    message,
  ];
}
