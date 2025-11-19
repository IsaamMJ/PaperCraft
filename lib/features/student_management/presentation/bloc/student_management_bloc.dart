import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:papercraft/core/domain/interfaces/i_logger.dart';
import 'package:papercraft/features/student_management/domain/entities/student_entity.dart';
import 'package:papercraft/features/student_management/domain/usecases/get_students_by_grade_section_usecase.dart';

part 'student_management_event.dart';
part 'student_management_state.dart';

class StudentManagementBloc extends Bloc<StudentManagementEvent, StudentManagementState> {
  final GetStudentsByGradeSectionUseCase getStudentsUseCase;
  final ILogger logger;

  StudentManagementBloc({
    required this.getStudentsUseCase,
    required this.logger,
  }) : super(const StudentManagementInitial()) {
    on<LoadStudentsForGradeSection>(_onLoadStudents);
    on<RefreshStudentList>(_onRefreshStudents);
    on<SearchStudents>(_onSearchStudents);
  }

  Future<void> _onLoadStudents(
    LoadStudentsForGradeSection event,
    Emitter<StudentManagementState> emit,
  ) async {
    emit(const StudentManagementLoading());

    try {
      // Load students (all if gradeSectionId is empty, or for specific section)
      final result = await getStudentsUseCase(
        GetStudentsParams(gradeSectionId: event.gradeSectionId),
      );

      result.fold(
        (failure) {
          logger.error(
            'Failed to load students: ${failure.message}',
            category: LogCategory.system,
          );
          emit(StudentManagementError(failure.message));
        },
        (students) {
          logger.info(
            'Loaded ${students.length} students',
            category: LogCategory.system,
          );
          emit(StudentsLoaded(
            students: students,
            gradeSectionId: event.gradeSectionId.isEmpty ? 'all' : event.gradeSectionId,
            filteredStudents: students,
          ));
        },
      );
    } catch (e) {
      logger.error(
        'Error loading students: ${e.toString()}',
        category: LogCategory.system,
      );
      emit(StudentManagementError('Failed to load students: ${e.toString()}'));
    }
  }

  Future<void> _onRefreshStudents(
    RefreshStudentList event,
    Emitter<StudentManagementState> emit,
  ) async {
    if (state is StudentsLoaded) {
      final currentState = state as StudentsLoaded;
      emit(const StudentManagementLoading());

      try {
        final result = await getStudentsUseCase(
          GetStudentsParams(gradeSectionId: currentState.gradeSectionId),
        );

        result.fold(
          (failure) {
            logger.error(
              'Failed to refresh students: ${failure.message}',
              category: LogCategory.system,
            );
            emit(StudentManagementError(failure.message));
          },
          (students) {
            logger.info(
              'Refreshed ${students.length} students',
              category: LogCategory.system,
            );
            emit(StudentsLoaded(
              students: students,
              gradeSectionId: currentState.gradeSectionId,
              filteredStudents: students,
            ));
          },
        );
      } catch (e) {
        logger.error(
          'Error refreshing students: ${e.toString()}',
          category: LogCategory.system,
        );
        emit(StudentManagementError('Failed to refresh students: ${e.toString()}'));
      }
    }
  }

  Future<void> _onSearchStudents(
    SearchStudents event,
    Emitter<StudentManagementState> emit,
  ) async {
    if (state is StudentsLoaded) {
      final currentState = state as StudentsLoaded;

      // Filter students based on search term
      final filtered = currentState.students
          .where((student) {
            final searchLower = event.searchTerm.toLowerCase();
            return student.rollNumber.toLowerCase().contains(searchLower) ||
                student.fullName.toLowerCase().contains(searchLower) ||
                (student.email?.toLowerCase().contains(searchLower) ?? false);
          })
          .toList();

      emit(currentState.copyWith(filteredStudents: filtered));
    }
  }
}
