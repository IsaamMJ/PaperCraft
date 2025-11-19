import 'package:get_it/get_it.dart';
import 'package:papercraft/core/domain/interfaces/i_logger.dart';
import 'package:papercraft/features/authentication/domain/services/user_state_service.dart';
import 'package:papercraft/core/infrastructure/di/injection_container.dart';
import 'package:papercraft/features/student_management/data/datasources/student_marks_remote_datasource.dart';
import 'package:papercraft/features/student_management/data/datasources/student_remote_datasource.dart';
import 'package:papercraft/features/student_management/data/repositories/student_marks_repository_impl.dart';
import 'package:papercraft/features/student_management/data/repositories/student_repository_impl.dart';
import 'package:papercraft/features/student_management/domain/repositories/student_marks_repository.dart';
import 'package:papercraft/features/student_management/domain/repositories/student_repository.dart';
import 'package:papercraft/features/student_management/domain/services/marks_validation_service.dart';
import 'package:papercraft/features/student_management/domain/services/student_validation_service.dart';
import 'package:papercraft/features/student_management/domain/usecases/add_student_usecase.dart';
import 'package:papercraft/features/student_management/domain/usecases/bulk_upload_students_usecase.dart';
import 'package:papercraft/features/student_management/domain/usecases/get_students_by_grade_section_usecase.dart';
import 'package:papercraft/features/student_management/domain/usecases/marks_usecases.dart';
import 'package:papercraft/features/student_management/presentation/bloc/marks_entry_bloc.dart';
import 'package:papercraft/features/student_management/presentation/bloc/student_enrollment_bloc.dart';
import 'package:papercraft/features/student_management/presentation/bloc/student_management_bloc.dart';
import 'package:papercraft/features/timetable/domain/repositories/exam_timetable_repository.dart';

/// Module for setting up Student Management feature dependencies
class StudentManagementModule {
  static Future<void> setup() async {
    final logger = sl<ILogger>();

    try {
      logger.info('Setting up Student Management module', category: LogCategory.system);

      // Domain Services
      sl.registerLazySingleton<StudentValidationService>(
        () => StudentValidationService(sl<ILogger>()),
      );

      sl.registerLazySingleton<MarksValidationService>(
        () => MarksValidationService(
          examRepository: sl<ExamTimetableRepository>(),
          logger: sl<ILogger>(),
        ),
      );

      // Remote DataSources
      sl.registerLazySingleton<StudentRemoteDataSource>(
        () => StudentRemoteDataSourceImpl(
          supabaseClient: sl.call(),
        ),
      );

      sl.registerLazySingleton<StudentMarksRemoteDataSource>(
        () => StudentMarksRemoteDataSourceImpl(
          supabaseClient: sl.call(),
        ),
      );

      // Repositories
      sl.registerLazySingleton<StudentRepository>(
        () => StudentRepositoryImpl(
          remoteDataSource: sl<StudentRemoteDataSource>(),
          logger: sl<ILogger>(),
          userStateService: sl<UserStateService>(),
        ),
      );

      sl.registerLazySingleton<StudentMarksRepository>(
        () => StudentMarksRepositoryImpl(
          remoteDataSource: sl<StudentMarksRemoteDataSource>(),
          logger: sl<ILogger>(),
          userStateService: sl<UserStateService>(),
        ),
      );

      // UseCases
      sl.registerLazySingleton<AddStudentUseCase>(
        () => AddStudentUseCase(sl<StudentRepository>()),
      );

      sl.registerLazySingleton<GetStudentsByGradeSectionUseCase>(
        () => GetStudentsByGradeSectionUseCase(sl<StudentRepository>()),
      );

      sl.registerLazySingleton<BulkUploadStudentsUseCase>(
        () => BulkUploadStudentsUseCase(sl<StudentRepository>()),
      );

      sl.registerLazySingleton<AddExamMarksUseCase>(
        () => AddExamMarksUseCase(sl<StudentMarksRepository>()),
      );

      sl.registerLazySingleton<GetExamMarksUseCase>(
        () => GetExamMarksUseCase(sl<StudentMarksRepository>()),
      );

      sl.registerLazySingleton<SubmitMarksUseCase>(
        () => SubmitMarksUseCase(sl<StudentMarksRepository>()),
      );

      sl.registerLazySingleton<UpdateStudentMarksUseCase>(
        () => UpdateStudentMarksUseCase(sl<StudentMarksRepository>()),
      );

      sl.registerLazySingleton<BulkUploadMarksUseCase>(
        () => BulkUploadMarksUseCase(sl<StudentMarksRepository>()),
      );

      sl.registerLazySingleton<GetMarksStatisticsUseCase>(
        () => GetMarksStatisticsUseCase(sl<StudentMarksRepository>()),
      );

      // BLoCs (Factories for per-screen instances)
      sl.registerFactory<StudentManagementBloc>(
        () => StudentManagementBloc(
          getStudentsUseCase: sl<GetStudentsByGradeSectionUseCase>(),
          logger: sl<ILogger>(),
        ),
      );

      sl.registerFactory<StudentEnrollmentBloc>(
        () => StudentEnrollmentBloc(
          addStudentUseCase: sl<AddStudentUseCase>(),
          bulkUploadUseCase: sl<BulkUploadStudentsUseCase>(),
          validationService: sl<StudentValidationService>(),
          logger: sl<ILogger>(),
        ),
      );

      sl.registerFactory<MarksEntryBloc>(
        () => MarksEntryBloc(
          getStudentsUseCase: sl<GetStudentsByGradeSectionUseCase>(),
          getExamMarksUseCase: sl<GetExamMarksUseCase>(),
          addMarksUseCase: sl<AddExamMarksUseCase>(),
          updateMarksUseCase: sl<UpdateStudentMarksUseCase>(),
          submitMarksUseCase: sl<SubmitMarksUseCase>(),
          bulkUploadMarksUseCase: sl<BulkUploadMarksUseCase>(),
          getStatisticsUseCase: sl<GetMarksStatisticsUseCase>(),
          validationService: sl<MarksValidationService>(),
          logger: sl<ILogger>(),
        ),
      );

      logger.info('Student Management module setup completed', category: LogCategory.system);
    } catch (e) {
      logger.error(
        'Failed to setup Student Management module: ${e.toString()}',
        category: LogCategory.system,
      );
      rethrow;
    }
  }
}
