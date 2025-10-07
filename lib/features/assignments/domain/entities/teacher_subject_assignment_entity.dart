// features/assignments/domain/entities/teacher_subject_assignment_entity.dart
import 'package:equatable/equatable.dart';

class TeacherSubjectAssignmentEntity extends Equatable {
  final String id;
  final String tenantId;
  final String teacherId;
  final String subjectId;
  final String academicYear;
  final bool isActive;
  final DateTime createdAt;

  const TeacherSubjectAssignmentEntity({
    required this.id,
    required this.tenantId,
    required this.teacherId,
    required this.subjectId,
    required this.academicYear,
    required this.isActive,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    tenantId,
    teacherId,
    subjectId,
    academicYear,
    isActive,
    createdAt,
  ];
}