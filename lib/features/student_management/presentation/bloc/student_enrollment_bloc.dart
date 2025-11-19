import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:papercraft/core/domain/interfaces/i_logger.dart';
import 'package:papercraft/features/student_management/domain/entities/student_entity.dart';
import 'package:papercraft/features/student_management/domain/services/student_validation_service.dart';
import 'package:papercraft/features/student_management/domain/usecases/add_student_usecase.dart';
import 'package:papercraft/features/student_management/domain/usecases/bulk_upload_students_usecase.dart';

part 'student_enrollment_event.dart';
part 'student_enrollment_state.dart';

class StudentEnrollmentBloc extends Bloc<StudentEnrollmentEvent, StudentEnrollmentState> {
  final AddStudentUseCase addStudentUseCase;
  final BulkUploadStudentsUseCase bulkUploadUseCase;
  final StudentValidationService validationService;
  final ILogger logger;

  StudentEnrollmentBloc({
    required this.addStudentUseCase,
    required this.bulkUploadUseCase,
    required this.validationService,
    required this.logger,
  }) : super(const StudentEnrollmentInitial()) {
    on<AddSingleStudent>(_onAddStudent);
    on<BulkUploadStudents>(_onBulkUpload);
    on<ValidateStudentData>(_onValidateData);
  }

  Future<void> _onAddStudent(
    AddSingleStudent event,
    Emitter<StudentEnrollmentState> emit,
  ) async {
    emit(const AddingStudent());

    try {
      // Validate student data first
      final errors = validationService.validateStudent(
        rollNumber: event.rollNumber,
        fullName: event.fullName,
        email: event.email,
        phone: event.phone,
      );

      if (errors.isNotEmpty) {
        final errorMessage = errors.values.join('\n');
        emit(ValidationFailed(errors));
        return;
      }

      // Call usecase
      final result = await addStudentUseCase(
        AddStudentParams(
          gradeSectionId: event.gradeSectionId,
          rollNumber: event.rollNumber,
          fullName: event.fullName,
          email: event.email,
          phone: event.phone,
        ),
      );

      result.fold(
        (failure) {
          logger.error(
            'Failed to add student: ${failure.message}',
            category: LogCategory.system,
          );
          emit(StudentEnrollmentError(failure.message));
        },
        (student) {
          logger.info(
            'Student added: ${student.rollNumber} - ${student.fullName}',
            category: LogCategory.system,
          );
          emit(StudentAdded(student));
        },
      );
    } catch (e) {
      logger.error(
        'Error adding student: ${e.toString()}',
        category: LogCategory.system,
      );
      emit(StudentEnrollmentError('Failed to add student: ${e.toString()}'));
    }
  }

  Future<void> _onBulkUpload(
    BulkUploadStudents event,
    Emitter<StudentEnrollmentState> emit,
  ) async {
    emit(const ValidatingBulkData());

    try {
      // Validate all rows first
      final allErrors = <int, List<String>>{};
      var rowNumber = 1;

      for (final row in event.studentData) {
        final errors = validationService.validateCsvRow(
          row: row,
          rowNumber: rowNumber,
        );
        if (errors.isNotEmpty) {
          allErrors[rowNumber] = errors;
        }
        rowNumber++;
      }

      // If there are validation errors, emit and return
      if (allErrors.isNotEmpty) {
        emit(BulkUploadValidationFailed(allErrors));
        return;
      }

      // Show preview
      emit(BulkUploadPreview(
        totalRows: event.studentData.length,
        studentData: event.studentData,
      ));
    } catch (e) {
      logger.error(
        'Error validating bulk data: ${e.toString()}',
        category: LogCategory.system,
      );
      emit(StudentEnrollmentError('Validation failed: ${e.toString()}'));
    }
  }

  Future<void> _onValidateData(
    ValidateStudentData event,
    Emitter<StudentEnrollmentState> emit,
  ) async {
    emit(const UploadingStudents());

    try {
      // Call usecase for bulk upload
      final result = await bulkUploadUseCase(
        BulkUploadStudentsParams(
          gradeSectionId: event.gradeSectionId,
          studentData: event.studentData,
        ),
      );

      result.fold(
        (failure) {
          logger.error(
            'Failed to bulk upload: ${failure.message}',
            category: LogCategory.system,
          );
          emit(StudentEnrollmentError(failure.message));
        },
        (students) {
          logger.info(
            'Bulk uploaded ${students.length} students',
            category: LogCategory.system,
          );
          emit(StudentsBulkUploaded(students));
        },
      );
    } catch (e) {
      logger.error(
        'Error bulk uploading students: ${e.toString()}',
        category: LogCategory.system,
      );
      emit(StudentEnrollmentError('Upload failed: ${e.toString()}'));
    }
  }
}
