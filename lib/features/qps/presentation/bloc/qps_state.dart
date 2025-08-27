import 'package:equatable/equatable.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../domain/entities/subject_entity.dart';
import '../../domain/entities/grade_entity.dart';
import '../../domain/entities/user_permissions_entity.dart';

abstract class QpsState extends Equatable {
  const QpsState();

  @override
  List<Object?> get props => [];
}

class QpsInitial extends QpsState {}

class QpsLoading extends QpsState {}

class QpsLoaded extends QpsState {
  final List<ExamTypeEntity> examTypes;
  final List<SubjectEntity> subjects;
  final List<GradeEntity> grades;
  final List<SubjectEntity> filteredSubjects;
  final List<GradeEntity> filteredGrades;
  final UserPermissionsEntity? userPermissions;
  final bool isAdmin;

  const QpsLoaded({
    required this.examTypes,
    required this.subjects,
    required this.grades,
    required this.filteredSubjects,
    required this.filteredGrades,
    this.userPermissions,
    required this.isAdmin,
  });

  @override
  List<Object?> get props => [
    examTypes,
    subjects,
    grades,
    filteredSubjects,
    filteredGrades,
    userPermissions,
    isAdmin,
  ];

  QpsLoaded copyWith({
    List<ExamTypeEntity>? examTypes,
    List<SubjectEntity>? subjects,
    List<GradeEntity>? grades,
    List<SubjectEntity>? filteredSubjects,
    List<GradeEntity>? filteredGrades,
    UserPermissionsEntity? userPermissions,
    bool? isAdmin,
  }) {
    return QpsLoaded(
      examTypes: examTypes ?? this.examTypes,
      subjects: subjects ?? this.subjects,
      grades: grades ?? this.grades,
      filteredSubjects: filteredSubjects ?? this.filteredSubjects,
      filteredGrades: filteredGrades ?? this.filteredGrades,
      userPermissions: userPermissions ?? this.userPermissions,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}

class QpsPermissionValidated extends QpsState {
  final bool canCreate;
  final String message;

  const QpsPermissionValidated({
    required this.canCreate,
    required this.message,
  });

  @override
  List<Object> get props => [canCreate, message];
}

class QpsError extends QpsState {
  final String error;

  const QpsError({required this.error});

  @override
  List<Object> get props => [error];
}