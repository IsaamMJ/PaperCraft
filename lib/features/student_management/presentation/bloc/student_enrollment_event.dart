part of 'student_enrollment_bloc.dart';

abstract class StudentEnrollmentEvent extends Equatable {
  const StudentEnrollmentEvent();
}

class AddSingleStudent extends StudentEnrollmentEvent {
  final String gradeSectionId;
  final String rollNumber;
  final String fullName;
  final String? email;
  final String? phone;

  const AddSingleStudent({
    required this.gradeSectionId,
    required this.rollNumber,
    required this.fullName,
    this.email,
    this.phone,
  });

  @override
  List<Object?> get props => [
        gradeSectionId,
        rollNumber,
        fullName,
        email,
        phone,
      ];
}

class BulkUploadStudents extends StudentEnrollmentEvent {
  final List<Map<String, String>> studentData;
  final String gradeSectionId; // Legacy, not used anymore (each student has their own grade_section_id)

  const BulkUploadStudents({
    required this.studentData,
    required this.gradeSectionId,
  });

  @override
  List<Object?> get props => [studentData, gradeSectionId];
}

class ValidateStudentData extends StudentEnrollmentEvent {
  final String gradeSectionId;
  final List<Map<String, String>> studentData;

  const ValidateStudentData({
    required this.gradeSectionId,
    required this.studentData,
  });

  @override
  List<Object?> get props => [gradeSectionId, studentData];
}
