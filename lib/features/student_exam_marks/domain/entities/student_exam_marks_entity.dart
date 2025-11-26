import 'package:equatable/equatable.dart';

class StudentExamMarksEntity extends Equatable {
  final String id;
  final String tenantId;
  final String studentId;
  final String examTimetableEntryId;
  final double totalMarks;
  final String status; // 'present', 'absent', 'medical_leave', 'not_appeared'
  final String? remarks;
  final String enteredBy;
  final bool isDraft;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Display fields (resolved from IDs)
  final String? studentName;
  final String? studentRollNumber;
  final String? studentEmail;

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
    this.studentName,
    this.studentRollNumber,
    this.studentEmail,
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
    studentName,
    studentRollNumber,
    studentEmail,
  ];
}
