// features/assignments/domain/entities/teacher_grade_assignment_entity.dart
import 'package:equatable/equatable.dart';

class TeacherGradeAssignmentEntity extends Equatable {
  final String id;
  final String tenantId;
  final String teacherId;
  final String gradeId;
  final String academicYear;
  final bool isActive;
  final DateTime createdAt;

  const TeacherGradeAssignmentEntity({
    required this.id,
    required this.tenantId,
    required this.teacherId,
    required this.gradeId,
    required this.academicYear,
    required this.isActive,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    tenantId,
    teacherId,
    gradeId,
    academicYear,
    isActive,
    createdAt,
  ];
}