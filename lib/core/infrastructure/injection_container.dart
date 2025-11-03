import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Grade Section Dependencies
import '../../features/catalog/domain/repositories/grade_section_repository.dart';
import '../../features/catalog/data/repositories/grade_section_repository_impl.dart';
import '../../features/catalog/data/datasources/grade_section_remote_datasource.dart';
import '../../features/catalog/domain/usecases/load_grade_sections_usecase.dart';
import '../../features/catalog/domain/usecases/create_grade_section_usecase.dart';
import '../../features/catalog/domain/usecases/delete_grade_section_usecase.dart';
import '../../features/catalog/presentation/bloc/grade_section_bloc.dart';

// Teacher Subject Dependencies
import '../../features/assignments/domain/repositories/teacher_subject_repository.dart';
import '../../features/assignments/data/repositories/teacher_subject_repository_impl.dart';
import '../../features/assignments/data/datasources/teacher_subject_remote_datasource.dart';
import '../../features/assignments/domain/usecases/load_teacher_subjects_usecase.dart';
import '../../features/assignments/domain/usecases/save_teacher_subjects_usecase.dart';
import '../../features/assignments/domain/usecases/get_teachers_for_subject_usecase.dart';

// Exam Calendar Dependencies
import '../../features/exams/domain/repositories/exam_calendar_repository.dart';
import '../../features/exams/data/repositories/exam_calendar_repository_impl.dart';
import '../../features/exams/data/datasources/exam_calendar_remote_datasource.dart';
import '../../features/exams/domain/usecases/load_exam_calendars_usecase.dart';
import '../../features/exams/domain/usecases/create_exam_calendar_usecase.dart';
import '../../features/exams/domain/usecases/delete_exam_calendar_usecase.dart';
import '../../features/exams/presentation/bloc/exam_calendar_bloc.dart';

// Exam Timetable Dependencies
import '../../features/exams/domain/repositories/exam_timetable_repository.dart';
import '../../features/exams/data/repositories/exam_timetable_repository_impl.dart';
import '../../features/exams/data/datasources/exam_timetable_remote_datasource.dart';
import '../../features/exams/domain/usecases/load_exam_timetables_usecase.dart';
import '../../features/exams/domain/usecases/create_exam_timetable_usecase.dart';
import '../../features/exams/domain/usecases/add_timetable_entry_usecase.dart';
import '../../features/exams/domain/usecases/validate_timetable_for_publishing_usecase.dart';
import '../../features/exams/domain/usecases/publish_exam_timetable_usecase.dart';
import '../../features/exams/domain/usecases/delete_exam_timetable_usecase.dart';
import '../../features/exams/presentation/bloc/exam_timetable_bloc.dart';

// Services
import '../../features/exams/domain/services/timetable_validation_service.dart';
import '../../features/exams/data/services/timetable_validation_service_impl.dart';

// Admin Setup Dependencies
import '../../features/admin/domain/repositories/admin_setup_repository.dart';
import '../../features/admin/data/repositories/admin_setup_repository_impl.dart';
import '../../features/admin/data/datasources/admin_setup_remote_datasource.dart';
import '../../features/admin/domain/usecases/get_available_grades_usecase.dart';
import '../../features/admin/domain/usecases/get_subject_suggestions_usecase.dart';
import '../../features/admin/domain/usecases/save_admin_setup_usecase.dart';
import '../../features/admin/presentation/bloc/admin_setup_bloc.dart';

final getIt = GetIt.instance;

/// Setup dependency injection container
///
/// Call this in main() before running the app:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await setupInjectionContainer();
///   runApp(const MyApp());
/// }
/// ```
Future<void> setupInjectionContainer() async {
  // Get Supabase instance
  final supabase = Supabase.instance.client;

  // ==================== Services ====================
  // Timetable Validation Service
  getIt.registerSingleton<TimetableValidationService>(
    TimetableValidationServiceImpl(),
  );

  // ==================== Grade Section ====================
  // Data Sources
  getIt.registerSingleton<GradeSectionRemoteDataSource>(
    GradeSectionRemoteDataSourceImpl(supabaseClient: supabase),
  );

  // Repository
  getIt.registerSingleton<GradeSectionRepository>(
    GradeSectionRepositoryImpl(
      remoteDataSource: getIt<GradeSectionRemoteDataSource>(),
    ),
  );

  // Use Cases
  getIt.registerSingleton<LoadGradeSectionsUseCase>(
    LoadGradeSectionsUseCase(repository: getIt<GradeSectionRepository>()),
  );

  getIt.registerSingleton<CreateGradeSectionUseCase>(
    CreateGradeSectionUseCase(repository: getIt<GradeSectionRepository>()),
  );

  getIt.registerSingleton<DeleteGradeSectionUseCase>(
    DeleteGradeSectionUseCase(repository: getIt<GradeSectionRepository>()),
  );

  // BLoC
  getIt.registerSingleton<GradeSectionBloc>(
    GradeSectionBloc(
      loadGradeSectionsUseCase: getIt<LoadGradeSectionsUseCase>(),
      createGradeSectionUseCase: getIt<CreateGradeSectionUseCase>(),
      deleteGradeSectionUseCase: getIt<DeleteGradeSectionUseCase>(),
      repository: getIt<GradeSectionRepository>(),
    ),
  );

  // ==================== Teacher Subject ====================
  // Data Sources
  getIt.registerSingleton<TeacherSubjectRemoteDataSource>(
    TeacherSubjectRemoteDataSourceImpl(supabaseClient: supabase),
  );

  // Repository
  getIt.registerSingleton<TeacherSubjectRepository>(
    TeacherSubjectRepositoryImpl(
      remoteDataSource: getIt<TeacherSubjectRemoteDataSource>(),
    ),
  );

  // Use Cases
  getIt.registerSingleton<LoadTeacherSubjectsUseCase>(
    LoadTeacherSubjectsUseCase(
      repository: getIt<TeacherSubjectRepository>(),
    ),
  );

  getIt.registerSingleton<SaveTeacherSubjectsUseCase>(
    SaveTeacherSubjectsUseCase(
      repository: getIt<TeacherSubjectRepository>(),
    ),
  );

  getIt.registerSingleton<GetTeachersForSubjectUseCase>(
    GetTeachersForSubjectUseCase(
      repository: getIt<TeacherSubjectRepository>(),
    ),
  );

  // ==================== Exam Calendar ====================
  // Data Sources
  getIt.registerSingleton<ExamCalendarRemoteDataSource>(
    ExamCalendarRemoteDataSourceImpl(supabaseClient: supabase),
  );

  // Repository
  getIt.registerSingleton<ExamCalendarRepository>(
    ExamCalendarRepositoryImpl(
      remoteDataSource: getIt<ExamCalendarRemoteDataSource>(),
    ),
  );

  // Use Cases
  getIt.registerSingleton<LoadExamCalendarsUseCase>(
    LoadExamCalendarsUseCase(
      repository: getIt<ExamCalendarRepository>(),
    ),
  );

  getIt.registerSingleton<CreateExamCalendarUseCase>(
    CreateExamCalendarUseCase(
      repository: getIt<ExamCalendarRepository>(),
    ),
  );

  getIt.registerSingleton<DeleteExamCalendarUseCase>(
    DeleteExamCalendarUseCase(
      repository: getIt<ExamCalendarRepository>(),
    ),
  );

  // BLoC
  getIt.registerSingleton<ExamCalendarBloc>(
    ExamCalendarBloc(
      loadExamCalendarsUseCase: getIt<LoadExamCalendarsUseCase>(),
      createExamCalendarUseCase: getIt<CreateExamCalendarUseCase>(),
      deleteExamCalendarUseCase: getIt<DeleteExamCalendarUseCase>(),
      repository: getIt<ExamCalendarRepository>(),
    ),
  );

  // ==================== Exam Timetable ====================
  // Data Sources
  getIt.registerSingleton<ExamTimetableRemoteDataSource>(
    ExamTimetableRemoteDataSourceImpl(supabaseClient: supabase),
  );

  // Repository
  getIt.registerSingleton<ExamTimetableRepository>(
    ExamTimetableRepositoryImpl(
      remoteDataSource: getIt<ExamTimetableRemoteDataSource>(),
    ),
  );

  // Use Cases
  getIt.registerSingleton<LoadExamTimetablesUseCase>(
    LoadExamTimetablesUseCase(
      repository: getIt<ExamTimetableRepository>(),
    ),
  );

  getIt.registerSingleton<CreateExamTimetableUseCase>(
    CreateExamTimetableUseCase(
      repository: getIt<ExamTimetableRepository>(),
    ),
  );

  getIt.registerSingleton<AddTimetableEntryUseCase>(
    AddTimetableEntryUseCase(
      repository: getIt<ExamTimetableRepository>(),
    ),
  );

  getIt.registerSingleton<ValidateTimetableForPublishingUseCase>(
    ValidateTimetableForPublishingUseCase(
      repository: getIt<ExamTimetableRepository>(),
    ),
  );

  getIt.registerSingleton<PublishExamTimetableUseCase>(
    PublishExamTimetableUseCase(
      timetableRepository: getIt<ExamTimetableRepository>(),
    ),
  );

  getIt.registerSingleton<DeleteExamTimetableUseCase>(
    DeleteExamTimetableUseCase(
      repository: getIt<ExamTimetableRepository>(),
    ),
  );

  // BLoC
  getIt.registerSingleton<ExamTimetableBloc>(
    ExamTimetableBloc(
      loadExamTimetablesUseCase: getIt<LoadExamTimetablesUseCase>(),
      createExamTimetableUseCase: getIt<CreateExamTimetableUseCase>(),
      addTimetableEntryUseCase: getIt<AddTimetableEntryUseCase>(),
      validateTimetableUseCase: getIt<ValidateTimetableForPublishingUseCase>(),
      publishTimetableUseCase: getIt<PublishExamTimetableUseCase>(),
      deleteTimetableUseCase: getIt<DeleteExamTimetableUseCase>(),
      validationService: getIt<TimetableValidationService>(),
      repository: getIt<ExamTimetableRepository>(),
    ),
  );

  // ==================== Admin Setup ====================
  // Data Sources
  getIt.registerSingleton<AdminSetupRemoteDataSource>(
    AdminSetupRemoteDataSourceImpl(supabaseClient: supabase),
  );

  // Repository
  getIt.registerSingleton<AdminSetupRepository>(
    AdminSetupRepositoryImpl(
      remoteDataSource: getIt<AdminSetupRemoteDataSource>(),
    ),
  );

  // Use Cases
  getIt.registerSingleton<GetAvailableGradesUseCase>(
    GetAvailableGradesUseCase(repository: getIt<AdminSetupRepository>()),
  );

  getIt.registerSingleton<GetSubjectSuggestionsUseCase>(
    GetSubjectSuggestionsUseCase(repository: getIt<AdminSetupRepository>()),
  );

  getIt.registerSingleton<SaveAdminSetupUseCase>(
    SaveAdminSetupUseCase(repository: getIt<AdminSetupRepository>()),
  );

  // BLoC
  getIt.registerSingleton<AdminSetupBloc>(
    AdminSetupBloc(
      getAvailableGradesUseCase: getIt<GetAvailableGradesUseCase>(),
      getSubjectSuggestionsUseCase: getIt<GetSubjectSuggestionsUseCase>(),
      saveAdminSetupUseCase: getIt<SaveAdminSetupUseCase>(),
    ),
  );
}
