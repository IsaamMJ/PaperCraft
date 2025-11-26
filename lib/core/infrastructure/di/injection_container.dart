// core/infrastructure/di/injection_container.dart
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Core domain interfaces
import '../../domain/interfaces/i_auth_provider.dart';
import '../../domain/interfaces/i_clock.dart';
import '../../domain/services/tenant_initialization_service.dart';
import '../auth/supabase_auth_provider.dart';
import '../../../features/authentication/data/datasources/tenant_data_source.dart';
import '../../../features/authentication/data/datasources/user_data_source.dart';
import '../../../features/authentication/data/repositories/tenant_repository_impl.dart';
import '../../../features/authentication/data/repositories/user_repository_impl.dart';
import '../../../features/authentication/domain/repositories/tenant_repository.dart';
import '../../../features/authentication/domain/repositories/user_repository.dart';
import '../../../features/authentication/domain/usecases/get_tenant_usecase.dart';
import '../../../features/authentication/presentation/bloc/auth_bloc.dart';
import '../../../features/catalog/data/datasources/grade_data_source.dart';
import '../../../features/catalog/domain/repositories/subject_repository.dart';
import '../../../features/catalog/domain/usecases/get_grade_levels_usecase.dart';
import '../../../features/catalog/domain/usecases/get_sections_by_grade_usecase.dart';
import '../../../features/catalog/domain/usecases/get_subjects_usecase.dart';
import '../../../features/catalog/presentation/bloc/grade_bloc.dart';
import '../../../features/catalog/presentation/bloc/subject_bloc.dart';
import '../../../features/catalog/presentation/bloc/teacher_pattern_bloc.dart';
import '../../../features/catalog/data/datasources/teacher_pattern_data_source.dart';
import '../../../features/catalog/data/repositories/teacher_pattern_repository_impl.dart';
import '../../../features/catalog/domain/repositories/teacher_pattern_repository.dart';
import '../../../features/catalog/domain/usecases/get_teacher_patterns_usecase.dart';
import '../../../features/catalog/domain/usecases/save_teacher_pattern_usecase.dart';
import '../../../features/catalog/domain/usecases/delete_teacher_pattern_usecase.dart';
import '../../../features/catalog/data/datasources/subject_data_source.dart';
import '../../../features/catalog/data/repositories/subject_repository_impl.dart';
import '../../../features/catalog/domain/usecases/get_grades_usecase.dart';

// Grade Section feature imports
import '../../../features/catalog/presentation/bloc/grade_section_bloc.dart';
import '../../../features/catalog/domain/repositories/grade_section_repository.dart';
import '../../../features/catalog/data/repositories/grade_section_repository_impl.dart';
import '../../../features/catalog/data/datasources/grade_section_remote_datasource.dart';
import '../../../features/catalog/domain/usecases/load_grade_sections_usecase.dart';
import '../../../features/catalog/domain/usecases/create_grade_section_usecase.dart';
import '../../../features/catalog/domain/usecases/delete_grade_section_usecase.dart';
import '../../../features/paper_review/domain/usecases/approve_paper_usecase.dart';
import '../../../features/paper_workflow/data/datasources/paper_local_data_source.dart';
import '../../../features/paper_workflow/domain/services/user_info_service.dart';
import '../../../features/paper_workflow/domain/services/paper_display_service.dart';
import '../../../features/paper_workflow/domain/usecases/get_all_papers_for_admin_usecase.dart';
import '../../../features/paper_workflow/domain/usecases/get_approved_papers_usecase.dart';
import '../../../features/paper_workflow/domain/usecases/get_approved_papers_paginated_usecase.dart';
import '../../../features/paper_workflow/domain/usecases/get_approved_papers_by_exam_date_range_usecase.dart';
import '../../../features/paper_workflow/domain/usecases/get_drafts_usecase.dart';
import '../../../features/paper_workflow/domain/usecases/get_paper_by_id_usecase.dart';
import '../../../features/paper_workflow/domain/usecases/get_papers_for_review_usecase.dart';
import '../../../features/paper_workflow/domain/usecases/get_user_submissions_usecase.dart';
import '../../../features/paper_workflow/domain/usecases/pull_for_editing_usecase.dart';
import '../../../features/paper_workflow/domain/usecases/save_draft_usecase.dart';
import '../../../features/paper_workflow/domain/usecases/update_paper_usecase.dart';
import '../../../features/paper_workflow/domain/usecases/submit_paper_usecase.dart';
import '../../../features/paper_workflow/domain/usecases/auto_assign_question_papers_usecase.dart';
import '../../../features/home/presentation/bloc/home_bloc.dart';
import '../../../features/question_bank/presentation/bloc/question_bank_bloc.dart';
import '../../../features/assignments/presentation/bloc/teacher_preferences_bloc.dart';
import '../../../features/assignments/data/datasources/teacher_subject_remote_datasource.dart';
import '../../../features/assignments/data/repositories/teacher_subject_repository_impl.dart';
import '../../../features/assignments/domain/repositories/teacher_subject_repository.dart';

// Reviewer assignment feature imports
import '../../../features/authentication/data/datasources/reviewer_assignment_data_source.dart';
import '../../../features/authentication/data/repositories/reviewer_assignment_repository_impl.dart';
import '../../../features/authentication/domain/repositories/reviewer_assignment_repository.dart';
import '../../../features/paper_workflow/presentation/bloc/reviewer_assignment_bloc.dart';

import '../../../features/timetable/presentation/bloc/exam_timetable_bloc.dart';
import '../../../features/timetable/presentation/bloc/exam_timetable_wizard_bloc.dart';
import '../../../features/timetable/data/datasources/exam_timetable_remote_data_source.dart';
import '../../../features/timetable/data/repositories/exam_timetable_repository_impl.dart';
import '../../../features/timetable/domain/repositories/exam_timetable_repository.dart';
import '../../../features/timetable/domain/usecases/get_exam_calendars_usecase.dart';
import '../../../features/timetable/domain/usecases/get_exam_timetables_usecase.dart';
import '../../../features/timetable/domain/usecases/create_exam_timetable_usecase.dart';
import '../../../features/timetable/domain/usecases/publish_exam_timetable_usecase.dart';
import '../../../features/timetable/domain/usecases/publish_timetable_and_auto_assign_papers_usecase.dart';
import '../../../features/timetable/domain/usecases/add_exam_timetable_entry_usecase.dart';
import '../../../features/timetable/domain/usecases/validate_exam_timetable_usecase.dart';
import '../../../features/timetable/domain/usecases/get_timetable_grades_and_sections_usecase.dart';
import '../../../features/timetable/domain/usecases/get_valid_subjects_for_grade_selection_usecase.dart';
import '../../../features/timetable/domain/usecases/map_grades_to_exam_calendar_usecase.dart';
import '../../../features/timetable/domain/usecases/get_grades_for_calendar_usecase.dart';
import '../../../features/timetable/domain/usecases/create_exam_timetable_with_entries_usecase.dart';
import '../../../features/catalog/domain/usecases/get_grades_usecase.dart';
import '../../../features/catalog/domain/usecases/get_subjects_usecase.dart';
import '../../../features/catalog/domain/repositories/grade_repository.dart';

// Exam Calendar feature imports
import '../../../features/exams/presentation/bloc/exam_calendar_bloc.dart';
import '../../../features/exams/data/datasources/exam_calendar_remote_datasource.dart';
import '../../../features/exams/data/repositories/exam_calendar_repository_impl.dart';
import '../../../features/exams/domain/repositories/exam_calendar_repository.dart';
import '../../../features/exams/domain/usecases/load_exam_calendars_usecase.dart';
import '../../../features/exams/domain/usecases/create_exam_calendar_usecase.dart';
import '../../../features/exams/domain/usecases/delete_exam_calendar_usecase.dart';

// Student Management feature imports
import '../../../features/student_management/presentation/bloc/student_enrollment_bloc.dart';
import '../../../features/student_management/presentation/bloc/student_management_bloc.dart';
import 'modules/student_management_module.dart';

// Student Exam Marks feature imports
import '../../../features/student_exam_marks/data/datasources/student_exam_marks_cloud_data_source.dart';
import '../../../features/student_exam_marks/data/repositories/student_exam_marks_repository_impl.dart';
import '../../../features/student_exam_marks/domain/repositories/student_exam_marks_repository.dart';
import '../../../features/student_exam_marks/domain/usecases/get_marks_for_timetable_entry_usecase.dart';
import '../../../features/student_exam_marks/domain/usecases/save_marks_as_draft_usecase.dart';
import '../../../features/student_exam_marks/domain/usecases/submit_marks_usecase.dart';
import '../../../features/student_exam_marks/domain/usecases/auto_create_marks_for_timetable_usecase.dart';
import '../../../features/student_exam_marks/presentation/bloc/marks_entry_bloc.dart';

import '../../domain/interfaces/i_logger.dart';
import '../analytics/analytics_service.dart';
import '../../domain/interfaces/i_feature_flags.dart';
import '../../domain/interfaces/i_network_service.dart';

// Core infrastructure implementations
import '../config/auth_config.dart';
import '../config/environment_config.dart';
import '../config/environment.dart';
import '../feature_flags/feature_flags_impl.dart';
import '../logging/app_logger_impl.dart';
import '../network/network_service_impl.dart';
import '../services/tenant_initialization_service_impl.dart';
import '../utils/platform_utils.dart';
import '../database/hive_database_helper.dart';
import '../network/api_client.dart';
import '../realtime/realtime_service.dart';
import '../cache/cache_service.dart';

// Authentication feature
import '../../../features/authentication/data/datasources/auth_data_source.dart';
import '../../../features/authentication/data/repositories/auth_repository_impl.dart';
import '../../../features/authentication/domain/repositories/auth_repository.dart';
import '../../../features/authentication/domain/services/user_state_service.dart';
import '../../../features/authentication/domain/usecases/auth_usecase.dart';

// Question papers feature
import '../../../features/paper_workflow/data/datasources/paper_cloud_data_source.dart';
import '../../../features/paper_workflow/data/datasources/paper_local_data_source_hive.dart';
import '../../../features/paper_workflow/data/repositories/question_paper_repository_impl.dart';
import '../../../features/paper_workflow/domain/repositories/question_paper_repository.dart';
import '../../../features/paper_workflow/domain/usecases/delete_draft_usecase.dart';
import '../../../features/paper_workflow/domain/usecases/update_paper_usecase.dart';
import '../../../features/paper_review/domain/usecases/reject_paper_usecase.dart';
import '../../../features/paper_review/domain/usecases/restore_spare_paper_usecase.dart';

// Grade feature
import '../../../features/catalog/data/repositories/grade_repository_impl.dart';
import '../../../features/catalog/domain/repositories/grade_repository.dart';

// Grade Subject feature
import '../../../features/catalog/data/datasources/grade_subject_data_source.dart';
import '../../../features/catalog/data/repositories/grade_subject_repository_impl.dart';
import '../../../features/catalog/domain/repositories/grade_subject_repository.dart';

// Assignment feature imports
import '../../../features/assignments/data/datasources/teacher_assignment_datasource.dart';
import '../../../features/assignments/data/repositories/teacher_assignment_repository_impl.dart';
import '../../../features/assignments/domain/repositories/teacher_assignment_repository.dart';
import '../../../features/assignments/domain/usecases/load_teacher_assignments_usecase.dart';
import '../../../features/assignments/domain/usecases/save_teacher_assignment_usecase.dart';
import '../../../features/assignments/domain/usecases/delete_teacher_assignment_usecase.dart';
import '../../../features/assignments/domain/usecases/get_assignment_stats_usecase.dart';
import '../../../features/assignments/presentation/bloc/teacher_assignment_bloc.dart';

// Notification feature imports
import '../../../features/notifications/data/datasources/notification_data_source.dart';
import '../../../features/notifications/data/repositories/notification_repository.dart';
import '../../../features/notifications/domain/repositories/i_notification_repository.dart';
import '../../../features/notifications/domain/usecases/create_notification_usecase.dart';
import '../../../features/notifications/domain/usecases/get_user_notifications_usecase.dart';
import '../../../features/notifications/domain/usecases/mark_notification_read_usecase.dart';
import '../../../features/notifications/domain/usecases/get_unread_count_usecase.dart';

// PDF generation feature
import '../../../features/pdf_generation/domain/usecases/download_pdf_usecase.dart';
import '../../../features/pdf_generation/domain/services/pdf_generation_service.dart';

// Admin setup feature
import '../../../features/admin/data/datasources/admin_setup_remote_datasource.dart';
import '../../../features/admin/data/repositories/admin_setup_repository_impl.dart';
import '../../../features/admin/domain/repositories/admin_setup_repository.dart';
import '../../../features/admin/domain/usecases/get_available_grades_usecase.dart';
import '../../../features/admin/domain/usecases/get_subject_suggestions_usecase.dart';
import '../../../features/admin/domain/usecases/save_admin_setup_usecase.dart';
import '../../../features/admin/domain/usecases/validate_subject_assignment_usecase.dart';
import '../../../features/admin/presentation/bloc/admin_setup_bloc.dart';

/// Global service locator instance
final sl = GetIt.instance;

/// Dependency Registration Strategy:
///
/// **Singletons (registerLazySingleton):**
/// - Core services (Logger, NetworkService, FeatureFlags)
/// - Repositories (stateless data access)
/// - Use cases (stateless business logic)
/// - Data sources (API clients, database helpers)
/// - Global state managers (AuthBloc, UserStateService)
///
/// **Factories (registerFactory):**
/// - BLoCs that are page/screen-specific (ExamTypeBloc, GradeBloc, etc.)
/// - Widgets that need fresh instances
/// - Any component that maintains screen-specific state
///
/// **Rule of thumb:** If it holds state tied to a UI screen, use Factory.
/// If it's stateless or manages global app state, use Singleton.

/// Setup all application dependencies
/// Must be called after EnvironmentConfig.load()
Future<void> setupDependencies() async {
  final setupStartTime = DateTime.now();

  // Step 1: Register core infrastructure interfaces
  _registerCoreServices();

  // Step 2: Initialize logger first (needed for all subsequent logging)
  await sl<ILogger>().initialize();

  sl<ILogger>().info(
    'Starting dependency initialization',
    category: LogCategory.system,
    context: {
      'startTime': setupStartTime.toIso8601String(),
      'environment': EnvironmentConfig.current.name,
      'platform': PlatformUtils.platformName,
    },
  );

  try {
    // Step 3: Setup all modules in dependency order
    await _DatabaseModule.setup();
    await _NetworkModule.setup();
    await _AuthModule.setup();
    await _QuestionPapersModule.setup();
    await _GradeModule.setup();
    await StudentManagementModule.setup();
    await _AssignmentModule.setup();
    await _ReviewerManagementModule.setup();
    await _NotificationModule.setup();
    await _AdminModule.setup();

    final setupDuration = DateTime.now().difference(setupStartTime);
    sl<ILogger>().info(
      'Dependencies initialized successfully',
      category: LogCategory.system,
      context: {
        'duration': '${setupDuration.inMilliseconds}ms',
        'components': ['database', 'network', 'auth', 'question_papers', 'grades', 'exam_types', 'user_info_service', 'paper_display_service', 'assignments', 'notifications', 'admin_setup'],
        'environment': EnvironmentConfig.current.name,
        'platform': PlatformUtils.platformName,
      },
    );
  } catch (e, stackTrace) {
    sl<ILogger>().critical(
      'Failed to setup dependencies',
      error: e,
      stackTrace: stackTrace,
      category: LogCategory.system,
      context: {
        'environment': EnvironmentConfig.current.name,
        'platform': PlatformUtils.platformName,
        'setupDuration': DateTime.now().difference(setupStartTime).inMilliseconds,
      },
    );
    rethrow;
  }
}

/// Register core infrastructure services that other services depend on
void _registerCoreServices() {
  // Validate environment configuration first
  _validateEnvironmentConfig();

  // Feature flags first (no dependencies)
  sl.registerLazySingleton<IFeatureFlags>(() => FeatureFlagsImpl(
    EnvironmentConfig.current,
    PlatformUtils.platformName,
  ));

  // Logger second (depends on feature flags)
  sl.registerLazySingleton<ILogger>(() => AppLoggerImpl(sl<IFeatureFlags>()));

  // Clock abstraction (no dependencies)
  sl.registerLazySingleton<IClock>(() => const SystemClock());

  // Auth Provider abstraction (no dependencies)
  sl.registerLazySingleton<IAuthProvider>(
    () => SupabaseAuthProvider(Supabase.instance.client),
  );

  // Analytics service (depends on nothing - can be stubbed)
  sl.registerLazySingleton<IAnalyticsService>(() => AnalyticsService());

  // Network service third (depends on logger)
  sl.registerLazySingleton<INetworkService>(() => NetworkServiceImpl(sl<ILogger>()));

  // Realtime service (depends on Supabase client and logger)
  sl.registerLazySingleton<RealtimeService>(() => RealtimeService(
    Supabase.instance.client,
    sl<ILogger>(),
  ));

  // Cache service (no dependencies)
  sl.registerLazySingleton<CacheService>(() => CacheService());

  // Tenant initialization service
  // Used by auth layer to check if tenant has completed setup wizard
  sl.registerLazySingleton<TenantInitializationService>(
    () => TenantInitializationServiceImpl(
      supabaseClient: Supabase.instance.client,
      logger: sl<ILogger>(),
    ),
  );
}

/// Database layer dependencies
class _DatabaseModule {
  static Future<void> setup() async {
    try {
      sl<ILogger>().debug('Initializing Supabase client', category: LogCategory.system);

      await Supabase.initialize(
        url: EnvironmentConfig.supabaseUrl,
        anonKey: EnvironmentConfig.supabaseAnonKey,
        debug: EnvironmentConfig.current == Environment.dev &&
            sl<IFeatureFlags>().enableDebugLogging,
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );

      sl<ILogger>().debug('Initializing Hive database', category: LogCategory.storage);

      // Create and initialize database helper
      final databaseHelper = HiveDatabaseHelper(sl<ILogger>(), sl<IFeatureFlags>());
      await databaseHelper.initialize();

      // Register the initialized instance
      sl.registerLazySingleton<HiveDatabaseHelper>(() => databaseHelper);

      sl<ILogger>().info(
        'Database module initialized successfully',
        category: LogCategory.system,
        context: {
          'supabaseConfigured': true,
          'hiveInitialized': true,
          'platform': PlatformUtils.platformName,
          'environment': EnvironmentConfig.current.name,
        },
      );
    } catch (e, stackTrace) {
      sl<ILogger>().error(
        'Database module initialization failed',
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.system,
        context: {
          'step': 'database_setup',
          'platform': PlatformUtils.platformName,
          'environment': EnvironmentConfig.current.name,
        },
      );
      rethrow;
    }
  }
}

/// Network layer dependencies
class _NetworkModule {
  static Future<void> setup() async {
    try {
      sl<ILogger>().debug('Initializing API client', category: LogCategory.network);

      // Register API client with all required dependencies
      sl.registerLazySingleton<ApiClient>(() => ApiClient(
        Supabase.instance.client,
        sl<INetworkService>(),
        sl<ILogger>(),
        sl<IFeatureFlags>(),
      ));

      sl<ILogger>().info(
        'Network module initialized successfully',
        category: LogCategory.system,
        context: {
          'apiClientConfigured': true,
          'networkServiceConfigured': true,
          'platform': PlatformUtils.platformName,
        },
      );
    } catch (e, stackTrace) {
      sl<ILogger>().error(
        'Network module initialization failed',
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.network,
        context: {
          'step': 'network_setup',
          'platform': PlatformUtils.platformName,
        },
      );
      rethrow;
    }
  }
}

/// Authentication layer dependencies
class _AuthModule {
  static Future<void> setup() async {
    try {
      sl<ILogger>().debug('Initializing authentication services', category: LogCategory.auth);

      // Data sources - infrastructure boundary, includes logging
      sl.registerLazySingleton<AuthDataSource>(
            () => AuthDataSource(
          sl<ApiClient>(),
          sl<ILogger>(),
          sl<IAuthProvider>(),
          sl<IClock>(),
          sl<TenantInitializationService>(),
        ),
      );

      // Repositories - application boundary, includes logging
      sl.registerLazySingleton<AuthRepository>(
            () => AuthRepositoryImpl(
          sl<AuthDataSource>(),
          sl<ILogger>(),
          sl<IClock>(),
        ),
      );

      // Setup tenant dependencies
      _setupTenantDependencies();

      // Use cases - Now includes logger dependency
      sl.registerLazySingleton<AuthUseCase>(
            () => AuthUseCase(sl<AuthRepository>(), sl<ILogger>()),
      );

      // User data layer BEFORE UserStateService
      sl.registerLazySingleton<UserDataSource>(
            () => UserDataSourceImpl(sl<ApiClient>(), sl<ILogger>()),
      );

      sl.registerLazySingleton<UserRepository>(
            () => UserRepositoryImpl(sl<UserDataSource>(), sl<ILogger>()),
      );

      // Domain services - Now with all dependencies injected
      sl.registerLazySingleton<UserStateService>(
            () => UserStateService(
          sl<ILogger>(),
          sl<GetTenantUseCase>(),
          sl<AuthUseCase>(),
          sl<IClock>(),
        ),
      );



      // Presentation layer (BLoC) - registered as factory for multiple instances
      // Note: AuthBloc is special - it's a singleton because it manages global auth state
      sl.registerLazySingleton<AuthBloc>(() => AuthBloc(
        sl<AuthUseCase>(),
        sl<UserStateService>(),
        sl<IAuthProvider>().onAuthStateChange,
        sl<IClock>(),
      ));

      sl<ILogger>().info(
        'Authentication module initialized successfully',
        category: LogCategory.system,
        context: {
          'authProvider': 'supabase_google_oauth',
          'redirectUrl': AuthConfig.googleOAuthRedirectUrl,
          'tenantSupport': true,
          'onboardingSupport': true,
          'environment': EnvironmentConfig.current.name,
          'platform': PlatformUtils.platformName,
        },
      );
    } catch (e, stackTrace) {
      sl<ILogger>().error(
        'Authentication module initialization failed',
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.auth,
        context: {
          'step': 'auth_setup',
          'environment': EnvironmentConfig.current.name,
          'platform': PlatformUtils.platformName,
        },
      );
      rethrow;
    }
  }


  static void _setupTenantDependencies() {
    sl<ILogger>().debug('Setting up tenant dependencies', category: LogCategory.auth);

    // 1. Register TenantDataSource first
    sl.registerLazySingleton<TenantDataSource>(
          () => TenantDataSourceImpl(sl<ApiClient>(), sl<ILogger>()),
    );

    // 2. Then register TenantRepository that depends on TenantDataSource
    sl.registerLazySingleton<TenantRepository>(
          () => TenantRepositoryImpl(
            sl<TenantDataSource>(),
            sl<ILogger>(),
          ),
    );

    // 3. Finally register the UseCase
    sl.registerLazySingleton<GetTenantUseCase>(
          () => GetTenantUseCase(sl<TenantRepository>()),
    );

    sl<ILogger>().debug('Tenant dependencies registered successfully', category: LogCategory.auth, context: {
      'dataSource': 'TenantDataSourceImpl',
      'repository': 'TenantRepositoryImpl',
      'useCase': 'GetTenantUseCase',
    });
  }
}

/// Question papers feature dependencies
class _QuestionPapersModule {
  static Future<void> setup() async {
    try {
      sl<ILogger>().debug('Initializing question papers module', category: LogCategory.paper);

      _setupDataSources();
      _setupRepositories();
      _setupUseCases();
      _setupTeacherPatterns();
      _setupSubjects();
      _setupUserInfoService();
      _setupPdfService();
      _setupPaperDisplayService();

      sl<ILogger>().info(
        'Question papers module initialized successfully',
        category: LogCategory.system,
        context: {
          'features': ['drafts', 'submissions', 'reviews', 'approval_workflow', 'exam_types', 'subjects', 'user_info_service', 'paper_display_service'],
          'useCasesRegistered': 17,
          'dataSourcesRegistered': 4,
          'servicesRegistered': 2,
          'platform': PlatformUtils.platformName,
        },
      );
    } catch (e, stackTrace) {
      sl<ILogger>().error(
        'Question papers module initialization failed',
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.paper,
        context: {
          'step': 'question_papers_setup',
          'platform': PlatformUtils.platformName,
        },
      );
      rethrow;
    }
  }

  static void _setupPaperDisplayService() {
    sl<ILogger>().debug('Setting up PaperDisplayService', category: LogCategory.paper);

    sl.registerLazySingleton<PaperDisplayService>(
          () => PaperDisplayService(
        sl<SubjectRepository>(),
        sl<GradeRepository>(),
        sl<ILogger>(),
      ),
    );

    sl<ILogger>().debug('PaperDisplayService registered successfully', category: LogCategory.paper);
  }

  static void _setupUserInfoService() {
    sl<ILogger>().debug('Setting up UserInfoService', category: LogCategory.paper);

    sl.registerLazySingleton<UserInfoService>(
          () => UserInfoService(
        sl<ILogger>(),
        sl<AuthUseCase>(),
      ),
    );

    sl<ILogger>().debug('UserInfoService registered successfully', category: LogCategory.paper);
  }

  static void _setupPdfService() {
    sl<ILogger>().debug('Setting up PDF generation service', category: LogCategory.paper);

    sl.registerLazySingleton<IPdfGenerationService>(
          () => SimplePdfService(),
    );

    sl<ILogger>().debug('PDF generation service registered successfully', category: LogCategory.paper);
  }

  static void _setupSubjects() {
    sl<ILogger>().debug('Setting up subjects', category: LogCategory.paper);

    // Data Sources
    sl.registerLazySingleton<SubjectDataSource>(
          () => SubjectDataSourceImpl(Supabase.instance.client, sl<ILogger>(), sl<CacheService>()),
    );

    // Repositories
    sl.registerLazySingleton<SubjectRepository>(
          () => SubjectRepositoryImpl(sl<SubjectDataSource>(), sl<ILogger>()),
    );

    // Use Cases
    sl.registerLazySingleton<GetSubjectsUseCase>(() => GetSubjectsUseCase(sl<SubjectRepository>()));
    sl.registerLazySingleton<GetSubjectsByGradeUseCase>(() => GetSubjectsByGradeUseCase(sl<SubjectRepository>()));
    sl.registerLazySingleton<GetSubjectByIdUseCase>(() => GetSubjectByIdUseCase(sl<SubjectRepository>()));

    // BLoC registration
    // Find where SubjectBloc is registered and update it:
    sl.registerFactory(
          () => SubjectBloc(
        getSubjectsUseCase: sl(),
        getSubjectsByGradeUseCase: sl(),
        getSubjectByIdUseCase: sl(),
        subjectRepository: sl(), // ADD THIS LINE
      ),
    );

    sl<ILogger>().debug('SubjectBloc registered successfully', category: LogCategory.paper);
  }

  static void _setupTeacherPatterns() {
    sl<ILogger>().debug('Setting up teacher patterns', category: LogCategory.paper);

    // Data Sources
    sl.registerLazySingleton<TeacherPatternDataSource>(
      () => TeacherPatternDataSource(Supabase.instance.client),
    );

    // Repositories
    sl.registerLazySingleton<ITeacherPatternRepository>(
      () => TeacherPatternRepositoryImpl(sl<TeacherPatternDataSource>()),
    );

    // Use Cases
    sl.registerLazySingleton<GetTeacherPatternsUseCase>(
      () => GetTeacherPatternsUseCase(sl<ITeacherPatternRepository>()),
    );
    sl.registerLazySingleton<SaveTeacherPatternUseCase>(
      () => SaveTeacherPatternUseCase(sl<ITeacherPatternRepository>()),
    );
    sl.registerLazySingleton<DeleteTeacherPatternUseCase>(
      () => DeleteTeacherPatternUseCase(sl<ITeacherPatternRepository>()),
    );

    // BLoC registration
    sl.registerFactory<TeacherPatternBloc>(
      () => TeacherPatternBloc(
        getPatterns: sl<GetTeacherPatternsUseCase>(),
        savePattern: sl<SaveTeacherPatternUseCase>(),
        deletePattern: sl<DeleteTeacherPatternUseCase>(),
      ),
    );

    sl<ILogger>().debug('TeacherPatternBloc registered successfully', category: LogCategory.paper);
  }

  static void _setupDataSources() {
    sl<ILogger>().debug('Setting up question papers data sources', category: LogCategory.paper);


    sl.registerLazySingleton<PaperLocalDataSource>(
          () => PaperLocalDataSourceHive(sl<HiveDatabaseHelper>(), sl<ILogger>()),
    );

    sl.registerLazySingleton<PaperCloudDataSource>(
          () => PaperCloudDataSourceImpl(sl<ApiClient>(), sl<ILogger>(), sl<CacheService>()),
    );
  }

  static void _setupRepositories() {
    sl<ILogger>().debug('Setting up question papers repositories', category: LogCategory.paper);

    sl.registerLazySingleton<QuestionPaperRepository>(
          () => QuestionPaperRepositoryImpl(
        sl<PaperLocalDataSource>(),
        sl<PaperCloudDataSource>(),
        sl<ILogger>(),
        sl<UserStateService>(),
      ),
    );
  }

  static void _setupUseCases() {
    sl<ILogger>().debug('Setting up question papers use cases', category: LogCategory.paper);

    final repository = sl<QuestionPaperRepository>();

    sl.registerLazySingleton(() => SaveDraftUseCase(repository));
    sl.registerLazySingleton(() => GetDraftsUseCase(repository));
    sl.registerLazySingleton(() => DeleteDraftUseCase(repository));
    sl.registerLazySingleton(() => UpdatePaperUseCase(repository));
    sl.registerLazySingleton(() => SubmitPaperUseCase(repository));
    sl.registerLazySingleton(() => AutoAssignQuestionPapersUsecase(repository: repository));
    sl.registerLazySingleton(() => GetUserSubmissionsUseCase(repository));
    sl.registerLazySingleton(() => GetPapersForReviewUseCase(repository));
    sl.registerLazySingleton(() => ApprovePaperUseCase(
          repository,
          sl<CreateNotificationUseCase>(),
          sl<ILogger>(),
        ));
    sl.registerLazySingleton(() => RejectPaperUseCase(
          repository,
          sl<CreateNotificationUseCase>(),
          sl<ILogger>(),
        ));
    sl.registerLazySingleton(() => RestoreSparePaperUseCase(
          repository,
          sl<ILogger>(),
        ));
    sl.registerLazySingleton(() => GetPaperByIdUseCase(repository));
    sl.registerLazySingleton(() => PullForEditingUseCase(repository));
    sl.registerLazySingleton(() => GetAllPapersForAdminUseCase(repository));
    sl.registerLazySingleton(() => GetApprovedPapersUseCase(repository));
    sl.registerLazySingleton(() => GetApprovedPapersPaginatedUseCase(repository));
    sl.registerLazySingleton(() => GetApprovedPapersByExamDateRangeUseCase(repository));

    // PDF generation use cases
    sl.registerLazySingleton(() => DownloadPdfUseCase());

    // Register BLoCs
    _setupBlocs();
  }

  static void _setupBlocs() {
    sl<ILogger>().debug('Setting up question papers BLoCs', category: LogCategory.paper);

    // Register as factories - new instance each time, auto-disposed
    sl.registerFactory(() => HomeBloc(
      getDraftsUseCase: sl(),
      getSubmissionsUseCase: sl(),
      getPapersForReviewUseCase: sl(),
      getAllPapersForAdminUseCase: sl(),
      realtimeService: sl(),
      paperDisplayService: sl(),
      gradeRepository: sl(),
      teacherSubjectRepository: sl(),
    ));

    // Question Bank BLoC - singleton to preserve state across rebuilds
    sl.registerLazySingleton(() => QuestionBankBloc(
      getApprovedPapersPaginatedUseCase: sl(),
      realtimeService: sl(),
      paperDisplayService: sl(),
    ));

    // Teacher preferences BLoC - singleton for global access
    // Note: No longer depends on AssignmentRepository - uses new TeacherAssignmentRepository when needed
    sl.registerLazySingleton(() => TeacherPreferencesBloc());

    sl<ILogger>().debug('Question papers BLoCs registered successfully', category: LogCategory.paper);
  }
}

/// Grade feature dependencies
class _GradeModule {
  static Future<void> setup() async {
    try {
      sl<ILogger>().debug('Initializing grade module', category: LogCategory.system);

      _setupDataSources();
      _setupRepositories();
      _setupUseCases();

      sl<ILogger>().info(
        'Grade module initialized successfully',
        category: LogCategory.system,
        context: {
          'features': ['grade_levels', 'sections', 'subject_filtering'],
          'useCasesRegistered': 3,
          'platform': PlatformUtils.platformName,
        },
      );
    } catch (e, stackTrace) {
      sl<ILogger>().error(
        'Grade module initialization failed',
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.system,
        context: {
          'step': 'grade_setup',
          'platform': PlatformUtils.platformName,
        },
      );
      rethrow;
    }
  }

  static void _setupDataSources() {
    sl<ILogger>().debug('Setting up grade data sources', category: LogCategory.system);

    sl.registerLazySingleton<GradeDataSource>(
          () => GradeDataSourceImpl(Supabase.instance.client, sl<ILogger>(), sl<CacheService>()),
    );

    // Register GradeSectionRemoteDataSource
    sl.registerLazySingleton<GradeSectionRemoteDataSource>(
          () => GradeSectionRemoteDataSourceImpl(supabaseClient: Supabase.instance.client),
    );

    // Register GradeSubjectDataSource
    sl.registerLazySingleton<GradeSubjectDataSource>(
          () => GradeSubjectDataSourceImpl(Supabase.instance.client, sl<ILogger>()),
    );
  }

  static void _setupRepositories() {
    sl<ILogger>().debug('Setting up grade repositories', category: LogCategory.system);

    sl.registerLazySingleton<GradeRepository>(
          () => GradeRepositoryImpl(sl<GradeDataSource>(), sl<ILogger>()),
    );

    // Register GradeSectionRepository
    sl.registerLazySingleton<GradeSectionRepository>(
          () => GradeSectionRepositoryImpl(remoteDataSource: sl<GradeSectionRemoteDataSource>()),
    );

    // Register GradeSubjectRepository
    sl.registerLazySingleton<GradeSubjectRepository>(
          () => GradeSubjectRepositoryImpl(sl<GradeSubjectDataSource>()),
    );
  }

  static void _setupUseCases() {
    sl<ILogger>().debug('Setting up grade use cases', category: LogCategory.system);

    final repository = sl<GradeRepository>();

    sl.registerLazySingleton(() => GetGradesUseCase(repository));
    sl.registerLazySingleton(() => GetGradeLevelsUseCase(repository));
    sl.registerLazySingleton(() => GetSectionsByGradeUseCase(repository));

    // BLoC registration
    sl.registerFactory<GradeBloc>(
          () => GradeBloc(repository: sl<GradeRepository>()),
    );

    // Register GradeSectionBloc
    final gradeSectionRepository = sl<GradeSectionRepository>();
    sl.registerFactory<GradeSectionBloc>(
      () => GradeSectionBloc(
        loadGradeSectionsUseCase: LoadGradeSectionsUseCase(repository: gradeSectionRepository),
        createGradeSectionUseCase: CreateGradeSectionUseCase(repository: gradeSectionRepository),
        deleteGradeSectionUseCase: DeleteGradeSectionUseCase(repository: gradeSectionRepository),
        repository: gradeSectionRepository,
      ),
    );
  }
}

/// Assignment feature dependencies
class _AssignmentModule {
  static Future<void> setup() async {
    try {
      sl<ILogger>().debug('Initializing assignment module', category: LogCategory.system);

      _setupDataSources();
      _setupRepositories();
      _setupUseCases();
      _setupBlocs();

      sl<ILogger>().info(
        'Assignment module initialized successfully',
        category: LogCategory.system,
        context: {
          'features': ['teacher_grade_assignments', 'teacher_subject_assignments'],
          'blocsRegistered': 1,
          'repositoriesRegistered': 1,
          'dataSourcesRegistered': 1,
          'platform': PlatformUtils.platformName,
        },
      );
    } catch (e, stackTrace) {
      sl<ILogger>().error(
        'Assignment module initialization failed',
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.system,
        context: {
          'step': 'assignment_setup',
          'platform': PlatformUtils.platformName,
        },
      );
      rethrow;
    }
  }

  static void _setupDataSources() {
    sl<ILogger>().debug('Setting up assignment data sources', category: LogCategory.system);

    sl.registerLazySingleton<TeacherAssignmentDataSource>(
      () => TeacherAssignmentDataSourceImpl(
        supabaseClient: Supabase.instance.client,
      ),
    );

    sl.registerLazySingleton<TeacherSubjectRemoteDataSource>(
      () => TeacherSubjectRemoteDataSourceImpl(
        supabaseClient: Supabase.instance.client,
      ),
    );
  }

  static void _setupRepositories() {
    sl<ILogger>().debug('Setting up assignment repositories', category: LogCategory.system);

    sl.registerLazySingleton<TeacherAssignmentRepository>(
      () => TeacherAssignmentRepositoryImpl(
        dataSource: sl<TeacherAssignmentDataSource>(),
      ),
    );

    sl.registerLazySingleton<TeacherSubjectRepository>(
      () => TeacherSubjectRepositoryImpl(
        remoteDataSource: sl<TeacherSubjectRemoteDataSource>(),
      ),
    );
  }

  static void _setupUseCases() {
    sl<ILogger>().debug('Setting up assignment use cases', category: LogCategory.system);

    sl.registerLazySingleton<LoadTeacherAssignmentsUseCase>(
      () => LoadTeacherAssignmentsUseCase(
        repository: sl<TeacherAssignmentRepository>(),
      ),
    );

    sl.registerLazySingleton<SaveTeacherAssignmentUseCase>(
      () => SaveTeacherAssignmentUseCase(
        repository: sl<TeacherAssignmentRepository>(),
      ),
    );

    sl.registerLazySingleton<DeleteTeacherAssignmentUseCase>(
      () => DeleteTeacherAssignmentUseCase(
        repository: sl<TeacherAssignmentRepository>(),
      ),
    );

    sl.registerLazySingleton<GetAssignmentStatsUseCase>(
      () => GetAssignmentStatsUseCase(
        repository: sl<TeacherAssignmentRepository>(),
      ),
    );
  }

  static void _setupBlocs() {
    sl<ILogger>().debug('Setting up assignment BLoCs', category: LogCategory.system);

    // Register as factory so each page gets its own instance
    sl.registerFactory<TeacherAssignmentBloc>(
      () => TeacherAssignmentBloc(
        loadTeacherAssignmentsUseCase: sl<LoadTeacherAssignmentsUseCase>(),
        saveTeacherAssignmentUseCase: sl<SaveTeacherAssignmentUseCase>(),
        deleteTeacherAssignmentUseCase: sl<DeleteTeacherAssignmentUseCase>(),
        getAssignmentStatsUseCase: sl<GetAssignmentStatsUseCase>(),
      ),
    );

    sl<ILogger>().debug('TeacherAssignmentBloc registered successfully', category: LogCategory.system);
  }
}

/// Reviewer management feature dependencies
class _ReviewerManagementModule {
  static Future<void> setup() async {
    try {
      sl<ILogger>().debug('Initializing reviewer management module', category: LogCategory.system);

      _setupDataSources();
      _setupRepositories();
      _setupBlocs();

      sl<ILogger>().info(
        'Reviewer management module initialized successfully',
        category: LogCategory.system,
        context: {
          'features': ['reviewer_grade_assignments'],
          'blocsRegistered': 1,
          'repositoriesRegistered': 1,
          'dataSourcesRegistered': 1,
          'platform': PlatformUtils.platformName,
        },
      );
    } catch (e, stackTrace) {
      sl<ILogger>().error(
        'Reviewer management module initialization failed',
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.system,
        context: {
          'step': 'reviewer_management_setup',
          'platform': PlatformUtils.platformName,
        },
      );
      rethrow;
    }
  }

  static void _setupDataSources() {
    sl<ILogger>().debug('Setting up reviewer management data sources', category: LogCategory.system);

    sl.registerLazySingleton<ReviewerAssignmentDataSource>(
      () => ReviewerAssignmentDataSourceImpl(
        sl<ApiClient>(),
        sl<ILogger>(),
      ),
    );
  }

  static void _setupRepositories() {
    sl<ILogger>().debug('Setting up reviewer management repositories', category: LogCategory.system);

    sl.registerLazySingleton<ReviewerAssignmentRepository>(
      () => ReviewerAssignmentRepositoryImpl(
        sl<ReviewerAssignmentDataSource>(),
        sl<ILogger>(),
      ),
    );
  }

  static void _setupBlocs() {
    sl<ILogger>().debug('Setting up reviewer management BLoCs', category: LogCategory.system);

    // Register as factory so each page gets its own instance
    sl.registerFactory<ReviewerAssignmentBloc>(
      () => ReviewerAssignmentBloc(),
    );

    sl<ILogger>().debug('ReviewerAssignmentBloc registered successfully', category: LogCategory.system);
  }
}

class _NotificationModule {
  static Future<void> setup() async {
    try {
      sl<ILogger>().debug('Initializing notification module', category: LogCategory.system);

      _setupDataSources();
      _setupRepositories();
      _setupUseCases();

      sl<ILogger>().info(
        'Notification module initialized successfully',
        category: LogCategory.system,
        context: {
          'features': ['paper_approval_notifications', 'paper_rejection_notifications'],
          'useCasesRegistered': 4,
          'repositoriesRegistered': 1,
          'dataSourcesRegistered': 1,
          'platform': PlatformUtils.platformName,
        },
      );
    } catch (e, stackTrace) {
      sl<ILogger>().error(
        'Notification module initialization failed',
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.system,
        context: {
          'step': 'notification_setup',
          'platform': PlatformUtils.platformName,
        },
      );
      rethrow;
    }
  }

  static void _setupDataSources() {
    sl<ILogger>().debug('Setting up notification data sources', category: LogCategory.system);

    sl.registerLazySingleton<NotificationDataSource>(
      () => NotificationDataSourceImpl(
        sl<ApiClient>(),
        sl<ILogger>(),
      ),
    );
  }

  static void _setupRepositories() {
    sl<ILogger>().debug('Setting up notification repositories', category: LogCategory.system);

    sl.registerLazySingleton<INotificationRepository>(
      () => NotificationRepository(
        sl<NotificationDataSource>(),
        sl<ILogger>(),
      ),
    );
  }

  static void _setupUseCases() {
    sl<ILogger>().debug('Setting up notification use cases', category: LogCategory.system);

    sl.registerLazySingleton(() => CreateNotificationUseCase(sl<INotificationRepository>()));
    sl.registerLazySingleton(() => GetUserNotificationsUseCase(sl<INotificationRepository>()));
    sl.registerLazySingleton(() => MarkNotificationReadUseCase(sl<INotificationRepository>()));
    sl.registerLazySingleton(() => GetUnreadCountUseCase(sl<INotificationRepository>()));

    sl<ILogger>().debug('Notification use cases registered successfully', category: LogCategory.system);
  }
}

/// Admin setup feature dependencies
class _AdminModule {
  static Future<void> setup() async {
    try {
      sl<ILogger>().debug('Initializing admin setup module', category: LogCategory.system);

      _setupDataSources();

      _setupRepositories();

      _setupUseCases();

      _setupBlocs();

      sl<ILogger>().info(
        'Admin setup module initialized successfully',
        category: LogCategory.system,
        context: {
          'features': ['admin_onboarding_wizard', 'grades_setup', 'sections_setup', 'subjects_setup'],
          'useCasesRegistered': 3,
          'repositoriesRegistered': 1,
          'dataSourcesRegistered': 1,
          'blocsRegistered': 1,
          'platform': PlatformUtils.platformName,
        },
      );
    } catch (e, stackTrace) {
      sl<ILogger>().error(
        'Admin setup module initialization failed',
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.system,
        context: {
          'step': 'admin_setup',
          'platform': PlatformUtils.platformName,
        },
      );
      rethrow;
    }
  }

  static void _setupDataSources() {
    sl<ILogger>().debug('Setting up admin setup data sources', category: LogCategory.system);

    sl.registerLazySingleton<AdminSetupRemoteDataSource>(
      () => AdminSetupRemoteDataSourceImpl(
        supabaseClient: Supabase.instance.client,
      ),
    );

    // Register exam calendar data sources
    sl<ILogger>().debug('Setting up exam calendar data sources', category: LogCategory.system);
    sl.registerLazySingleton<ExamCalendarRemoteDataSource>(
      () => ExamCalendarRemoteDataSourceImpl(
        supabaseClient: Supabase.instance.client,
      ),
    );

    // Register exam timetable data sources
    sl<ILogger>().debug('Setting up exam timetable data sources', category: LogCategory.system);
    sl.registerLazySingleton<ExamTimetableRemoteDataSource>(
      () => ExamTimetableRemoteDataSourceImpl(
        supabaseClient: Supabase.instance.client,
      ),
    );
  }

  static void _setupRepositories() {
    sl<ILogger>().debug('Setting up admin setup repositories', category: LogCategory.system);

    sl.registerLazySingleton<AdminSetupRepository>(
      () => AdminSetupRepositoryImpl(
        remoteDataSource: sl<AdminSetupRemoteDataSource>(),
      ),
    );

    // Register exam calendar repository
    sl<ILogger>().debug('Setting up exam calendar repositories', category: LogCategory.system);
    sl.registerLazySingleton<ExamCalendarRepository>(
      () => ExamCalendarRepositoryImpl(
        remoteDataSource: sl<ExamCalendarRemoteDataSource>(),
      ),
    );

    // Register exam timetable repository
    sl<ILogger>().debug('Setting up exam timetable repositories', category: LogCategory.system);
    sl.registerLazySingleton<ExamTimetableRepository>(
      () => ExamTimetableRepositoryImpl(
        remoteDataSource: sl<ExamTimetableRemoteDataSource>(),
      ),
    );
  }

  static void _setupUseCases() {
    sl<ILogger>().debug('Setting up admin setup use cases', category: LogCategory.system);

    sl.registerLazySingleton(() => GetAvailableGradesUseCase(
      repository: sl<AdminSetupRepository>(),
    ));
    sl.registerLazySingleton(() => GetSubjectSuggestionsUseCase(
      repository: sl<AdminSetupRepository>(),
    ));
    sl.registerLazySingleton(() => SaveAdminSetupUseCase(
      repository: sl<AdminSetupRepository>(),
    ));
    sl.registerLazySingleton(() => ValidateSubjectAssignmentUseCase());

    sl<ILogger>().debug('Admin setup use cases registered successfully', category: LogCategory.system);

    // Register exam calendar use cases
    sl<ILogger>().debug('Setting up exam calendar use cases', category: LogCategory.system);
    sl.registerLazySingleton(() => LoadExamCalendarsUseCase(
      repository: sl<ExamCalendarRepository>(),
    ));
    sl.registerLazySingleton(() => CreateExamCalendarUseCase(
      repository: sl<ExamCalendarRepository>(),
    ));
    sl.registerLazySingleton(() => DeleteExamCalendarUseCase(
      repository: sl<ExamCalendarRepository>(),
    ));

    sl<ILogger>().debug('Exam calendar use cases registered successfully', category: LogCategory.system);

    sl<ILogger>().debug('Setting up exam timetable use cases', category: LogCategory.system);

    sl.registerLazySingleton(() => GetExamCalendarsUsecase(
      repository: sl<ExamTimetableRepository>(),
    ));

    sl.registerLazySingleton(() => GetExamTimetablesUsecase(
      repository: sl<ExamTimetableRepository>(),
    ));

    sl.registerLazySingleton(() => CreateExamTimetableUsecase(
      repository: sl<ExamTimetableRepository>(),
    ));

    sl.registerLazySingleton(() => PublishExamTimetableUsecase(
      repository: sl<ExamTimetableRepository>(),
    ));

    sl.registerLazySingleton(() => PublishTimetableAndAutoAssignPapersUsecase(
      publishUsecase: sl<PublishExamTimetableUsecase>(),
      timetableRepository: sl<ExamTimetableRepository>(),
      teacherSubjectRepository: sl<TeacherSubjectRepository>(),
      userRepository: sl<UserRepository>(),
      autoAssignUsecase: sl<AutoAssignQuestionPapersUsecase>(),
      autoCreateMarksUsecase: sl<AutoCreateMarksForTimetableUsecase>(),
      logger: sl<ILogger>(),
    ));

    sl.registerLazySingleton(() => AddExamTimetableEntryUsecase(
      repository: sl<ExamTimetableRepository>(),
    ));

    sl.registerLazySingleton(() => ValidateExamTimetableUsecase(
      repository: sl<ExamTimetableRepository>(),
    ));

    sl.registerLazySingleton(() => GetTimetableGradesAndSectionsUsecase());

    sl.registerLazySingleton(() => GetValidSubjectsForGradeSelectionUsecase(
      repository: sl<ExamTimetableRepository>(),
    ));

    // Register wizard step use cases
    sl<ILogger>().debug('Setting up exam timetable wizard use cases', category: LogCategory.system);

    sl.registerLazySingleton(() => MapGradesToExamCalendarUsecase(
      repository: sl<ExamTimetableRepository>(),
    ));

    sl.registerLazySingleton(() => GetGradesForCalendarUsecase(
      repository: sl<ExamTimetableRepository>(),
    ));

    sl.registerLazySingleton(() => CreateExamTimetableWithEntriesUsecase(
      repository: sl<ExamTimetableRepository>(),
    ));

    sl<ILogger>().debug('Exam timetable wizard use cases registered successfully', category: LogCategory.system);

    // Register student exam marks use cases
    sl<ILogger>().debug('Setting up student exam marks use cases', category: LogCategory.system);

    sl.registerLazySingleton<StudentExamMarksCloudDataSource>(
      () => StudentExamMarksCloudDataSourceImpl(
        sl<ApiClient>(),
        sl<ILogger>(),
      ),
    );

    sl.registerLazySingleton<StudentExamMarksRepository>(
      () => StudentExamMarksRepositoryImpl(
        sl<StudentExamMarksCloudDataSource>(),
      ),
    );

    sl.registerLazySingleton(() => GetMarksForTimetableEntryUsecase(
      repository: sl<StudentExamMarksRepository>(),
    ));

    sl.registerLazySingleton(() => SaveMarksAsDraftUsecase(
      repository: sl<StudentExamMarksRepository>(),
    ));

    sl.registerLazySingleton(() => SubmitMarksUsecase(
      repository: sl<StudentExamMarksRepository>(),
    ));

    sl.registerLazySingleton(() => AutoCreateMarksForTimetableUsecase(
      repository: sl<StudentExamMarksRepository>(),
    ));

    sl<ILogger>().debug('Student exam marks use cases registered successfully', category: LogCategory.system);

    sl<ILogger>().debug('Exam timetable use cases registered successfully', category: LogCategory.system);
  }

  static void _setupBlocs() {
    sl<ILogger>().debug('Setting up admin setup BLoCs', category: LogCategory.system);

    sl.registerFactory(() => AdminSetupBloc(
      getAvailableGradesUseCase: sl<GetAvailableGradesUseCase>(),
      getSubjectSuggestionsUseCase: sl<GetSubjectSuggestionsUseCase>(),
      saveAdminSetupUseCase: sl<SaveAdminSetupUseCase>(),
    ));

    sl<ILogger>().debug('AdminSetupBloc registered successfully', category: LogCategory.system);

    // Register ExamCalendarBloc
    sl<ILogger>().debug('Setting up exam calendar BLoCs', category: LogCategory.system);
    sl.registerFactory(() => ExamCalendarBloc(
      loadExamCalendarsUseCase: sl<LoadExamCalendarsUseCase>(),
      createExamCalendarUseCase: sl<CreateExamCalendarUseCase>(),
      deleteExamCalendarUseCase: sl<DeleteExamCalendarUseCase>(),
      repository: sl<ExamCalendarRepository>(),
    ));
    sl<ILogger>().debug('ExamCalendarBloc registered successfully', category: LogCategory.system);

    sl<ILogger>().debug('Setting up exam timetable BLoCs', category: LogCategory.system);
    try {
      final getCalendarsUC = sl<GetExamCalendarsUsecase>();

      final getTimetablesUC = sl<GetExamTimetablesUsecase>();

      final createUC = sl<CreateExamTimetableUsecase>();

      final publishUC = sl<PublishExamTimetableUsecase>();

      final publishAndAutoAssignUC = sl<PublishTimetableAndAutoAssignPapersUsecase>();

      final addEntryUC = sl<AddExamTimetableEntryUsecase>();

      final validateUC = sl<ValidateExamTimetableUsecase>();

      final gradesAndSectionsUC = sl<GetTimetableGradesAndSectionsUsecase>();

      final getValidSubjectsUC = sl<GetValidSubjectsForGradeSelectionUsecase>();

      final repo = sl<ExamTimetableRepository>();

      sl.registerFactory(() => ExamTimetableBloc(
        getExamCalendarsUsecase: getCalendarsUC,
        getExamTimetablesUsecase: getTimetablesUC,
        createExamTimetableUsecase: createUC,
        publishExamTimetableUsecase: publishUC,
        publishTimetableAndAutoAssignUsecase: publishAndAutoAssignUC,
        addExamTimetableEntryUsecase: addEntryUC,
        validateExamTimetableUsecase: validateUC,
        getTimetableGradesAndSectionsUsecase: gradesAndSectionsUC,
        getValidSubjectsUsecase: getValidSubjectsUC,
        repository: repo,
      ));
    } catch (e, st) {
      rethrow;
    }
    sl<ILogger>().debug('ExamTimetableBloc registered successfully', category: LogCategory.system);

    // Register ExamTimetableWizardBloc
    sl<ILogger>().debug('Setting up exam timetable wizard BLoC', category: LogCategory.system);
    try {
      // Register GetGradesUseCase if not already registered
      if (!sl.isRegistered<GetGradesUseCase>()) {
        sl.registerLazySingleton(() => GetGradesUseCase(
          sl<GradeRepository>(),
        ));
      }

      // Register GetSubjectsUseCase if not already registered
      if (!sl.isRegistered<GetSubjectsUseCase>()) {
        sl.registerLazySingleton(() => GetSubjectsUseCase(
          sl<SubjectRepository>(),
        ));
      }

      // Register LoadGradeSectionsUseCase if not already registered
      if (!sl.isRegistered<LoadGradeSectionsUseCase>()) {
        sl.registerLazySingleton(() => LoadGradeSectionsUseCase(
          repository: sl<GradeSectionRepository>(),
        ));
      }

      // Register GetSubjectsByGradeUseCase if not already registered
      if (!sl.isRegistered<GetSubjectsByGradeUseCase>()) {
        sl.registerLazySingleton(() => GetSubjectsByGradeUseCase(
          sl<SubjectRepository>(),
        ));
      }

      // Register GetSubjectsByGradeAndSectionUseCase if not already registered
      if (!sl.isRegistered<GetSubjectsByGradeAndSectionUseCase>()) {
        sl.registerLazySingleton(() => GetSubjectsByGradeAndSectionUseCase(
          sl<SubjectRepository>(),
        ));
      }

      sl.registerLazySingleton(() => ExamTimetableWizardBloc(
        getExamCalendars: sl<GetExamCalendarsUsecase>(),
        mapGradesToExamCalendar: sl<MapGradesToExamCalendarUsecase>(),
        getGradesForCalendar: sl<GetGradesForCalendarUsecase>(),
        createExamTimetableWithEntries: sl<CreateExamTimetableWithEntriesUsecase>(),
        getGrades: sl<GetGradesUseCase>(),
        getSubjects: sl<GetSubjectsUseCase>(),
        getSubjectsByGrade: sl<GetSubjectsByGradeUseCase>(),
        getSubjectsByGradeAndSection: sl<GetSubjectsByGradeAndSectionUseCase>(),
        loadGradeSections: sl<LoadGradeSectionsUseCase>(),
      ));
    } catch (e, st) {
      rethrow;
    }
    sl<ILogger>().debug('ExamTimetableWizardBloc registered successfully', category: LogCategory.system);

    // Register MarksEntryBloc
    sl<ILogger>().debug('Setting up marks entry BLoC', category: LogCategory.system);
    sl.registerFactory(() => MarksEntryBloc(
      getMarksUsecase: sl<GetMarksForTimetableEntryUsecase>(),
      saveMarksUsecase: sl<SaveMarksAsDraftUsecase>(),
      submitMarksUsecase: sl<SubmitMarksUsecase>(),
    ));
    sl<ILogger>().debug('MarksEntryBloc registered successfully', category: LogCategory.system);
  }
}

/// Validate environment configuration before dependency setup
void _validateEnvironmentConfig() {
  if (EnvironmentConfig.supabaseUrl.isEmpty) {
    throw StateError('Supabase URL not configured. Check your environment setup.');
  }

  if (EnvironmentConfig.supabaseAnonKey.isEmpty) {
    throw StateError('Supabase anon key not configured. Check your environment setup.');
  }
}

/// Clean up all registered dependencies (useful for testing)
Future<void> cleanupDependencies() async {
  final errors = <String>[];

  // Dispose services that need cleanup
  try {
    if (sl.isRegistered<INetworkService>()) {
      try {
        sl<INetworkService>().dispose();
      } catch (e) {
        errors.add('Failed to dispose INetworkService: $e');
      }
    }
  } catch (e) {
    errors.add('Failed to check INetworkService registration: $e');
  }

  // Note: HiveDatabaseHelper doesn't require explicit disposal
  // Hive boxes are automatically closed on app termination

  // Log any errors before resetting
  if (errors.isNotEmpty && sl.isRegistered<ILogger>()) {
    try {
      final logger = sl<ILogger>();
      for (final error in errors) {
        logger.warning(error, category: LogCategory.system);
      }
    } catch (e) {
      // Logger might already be disposed, use stderr
      for (final error in errors) {
      }
    }
  }

  // Reset all registrations
  try {
    await sl.reset();
    if (sl.isRegistered<ILogger>()) {
      sl<ILogger>().info(
        'Dependencies cleaned up successfully',
        category: LogCategory.system,
        context: {
          'warningsCount': errors.length,
        },
      );
    }
  } catch (e, stackTrace) {
    if (sl.isRegistered<ILogger>()) {
      sl<ILogger>().critical(
        'Failed to reset dependency injection container',
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.system,
      );
    }
    rethrow;
  }
}