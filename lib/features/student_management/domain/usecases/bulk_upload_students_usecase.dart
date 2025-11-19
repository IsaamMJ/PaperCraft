import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/features/student_management/domain/entities/student_entity.dart';
import 'package:papercraft/features/student_management/domain/repositories/student_repository.dart';

class BulkUploadStudentsUseCase {
  final StudentRepository repository;

  BulkUploadStudentsUseCase(this.repository);

  Future<Either<Failure, List<StudentEntity>>> call(
    BulkUploadStudentsParams params,
  ) async {
    // Validate data before upload
    final validation = _validateStudentData(params.studentData);
    if (validation != null) {
      return Left(ValidationFailure(validation));
    }

    return await repository.bulkUploadStudents(
      gradeSectionId: params.gradeSectionId,
      studentData: params.studentData,
    );
  }

  /// Validate student data for bulk upload
  String? _validateStudentData(List<Map<String, String>> data) {
    if (data.isEmpty) {
      return 'No student data provided';
    }

    for (int i = 0; i < data.length; i++) {
      final row = data[i];
      final rollNumber = row['roll_number']?.trim() ?? '';
      final fullName = row['full_name']?.trim() ?? '';

      if (rollNumber.isEmpty) {
        return 'Row ${i + 1}: Roll number is required';
      }

      if (fullName.isEmpty) {
        return 'Row ${i + 1}: Full name is required';
      }

      // Check for duplicates within the batch
      for (int j = i + 1; j < data.length; j++) {
        if (data[j]['roll_number']?.trim() == rollNumber) {
          return 'Duplicate roll number: $rollNumber in rows ${i + 1} and ${j + 1}';
        }
      }
    }

    return null;
  }
}

class BulkUploadStudentsParams extends Equatable {
  final String gradeSectionId;
  final List<Map<String, String>> studentData;

  const BulkUploadStudentsParams({
    required this.gradeSectionId,
    required this.studentData,
  });

  @override
  List<Object?> get props => [gradeSectionId, studentData];
}
