part of 'student_management_bloc.dart';

abstract class StudentManagementState extends Equatable {
  const StudentManagementState();
}

class StudentManagementInitial extends StudentManagementState {
  const StudentManagementInitial();

  @override
  List<Object?> get props => [];
}

class StudentManagementLoading extends StudentManagementState {
  const StudentManagementLoading();

  @override
  List<Object?> get props => [];
}

class StudentsLoaded extends StudentManagementState {
  final List<StudentEntity> students;
  final List<StudentEntity> filteredStudents;
  final String gradeSectionId;

  const StudentsLoaded({
    required this.students,
    required this.gradeSectionId,
    required this.filteredStudents,
  });

  StudentsLoaded copyWith({
    List<StudentEntity>? students,
    List<StudentEntity>? filteredStudents,
    String? gradeSectionId,
  }) {
    return StudentsLoaded(
      students: students ?? this.students,
      gradeSectionId: gradeSectionId ?? this.gradeSectionId,
      filteredStudents: filteredStudents ?? this.filteredStudents,
    );
  }

  @override
  List<Object?> get props => [students, filteredStudents, gradeSectionId];
}

class StudentManagementError extends StudentManagementState {
  final String message;

  const StudentManagementError(this.message);

  @override
  List<Object?> get props => [message];
}
