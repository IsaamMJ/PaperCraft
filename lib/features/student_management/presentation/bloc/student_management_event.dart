part of 'student_management_bloc.dart';

abstract class StudentManagementEvent extends Equatable {
  const StudentManagementEvent();
}

class LoadStudentsForGradeSection extends StudentManagementEvent {
  final String gradeSectionId;

  const LoadStudentsForGradeSection({required this.gradeSectionId});

  @override
  List<Object?> get props => [gradeSectionId];
}

class RefreshStudentList extends StudentManagementEvent {
  const RefreshStudentList();

  @override
  List<Object?> get props => [];
}

class SearchStudents extends StudentManagementEvent {
  final String searchTerm;

  const SearchStudents({required this.searchTerm});

  @override
  List<Object?> get props => [searchTerm];
}
