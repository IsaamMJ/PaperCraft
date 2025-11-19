part of 'student_enrollment_bloc.dart';

abstract class StudentEnrollmentState extends Equatable {
  const StudentEnrollmentState();
}

class StudentEnrollmentInitial extends StudentEnrollmentState {
  const StudentEnrollmentInitial();

  @override
  List<Object?> get props => [];
}

class AddingStudent extends StudentEnrollmentState {
  const AddingStudent();

  @override
  List<Object?> get props => [];
}

class StudentAdded extends StudentEnrollmentState {
  final StudentEntity student;

  const StudentAdded(this.student);

  @override
  List<Object?> get props => [student];
}

class ValidatingBulkData extends StudentEnrollmentState {
  const ValidatingBulkData();

  @override
  List<Object?> get props => [];
}

class BulkUploadPreview extends StudentEnrollmentState {
  final int totalRows;
  final List<Map<String, String>> studentData;

  const BulkUploadPreview({
    required this.totalRows,
    required this.studentData,
  });

  @override
  List<Object?> get props => [totalRows, studentData];
}

class BulkUploadValidationFailed extends StudentEnrollmentState {
  final Map<int, List<String>> errors; // row number -> list of errors

  const BulkUploadValidationFailed(this.errors);

  @override
  List<Object?> get props => [errors];
}

class UploadingStudents extends StudentEnrollmentState {
  const UploadingStudents();

  @override
  List<Object?> get props => [];
}

class StudentsBulkUploaded extends StudentEnrollmentState {
  final List<StudentEntity> students;

  const StudentsBulkUploaded(this.students);

  @override
  List<Object?> get props => [students];
}

class ValidationFailed extends StudentEnrollmentState {
  final Map<String, String> errors; // field -> error message

  const ValidationFailed(this.errors);

  @override
  List<Object?> get props => [errors];
}

class StudentEnrollmentError extends StudentEnrollmentState {
  final String message;

  const StudentEnrollmentError(this.message);

  @override
  List<Object?> get props => [message];
}
