// core/infrastructure/di/injection_container.dart
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Core domain interfaces
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
import '../../../features/onboarding/domain/usecases/seed_tenant_usecase.dart';
import '../../../features/catalog/data/datasources/subject_data_source.dart';
import '../../../features/catalog/data/repositories/subject_repository_impl.dart';
import '../../../features/catalog/domain/usecases/get_grades_usecase.dart';
import '../../../features/paper_review/domain/usecases/approve_paper_usecase.dart';
import '../../../features/paper_workflow/data/datasources/paper_local_data_source.dart';
import '../../../features/paper_workflow/domain/services/user_info_service.dart';
import '../../../features/paper_workflow/domain/services/paper_display_service.dart';
import '../../../features/paper_workflow/domain/usecases/get_all_papers_for_admin_usecase.dart';
import '../../../features/paper_workflow/domain/usecases/get_approved_papers_usecase.dart';
import '../../../features/paper_workflow/domain/usecases/get_approved_papers_paginated_usecase.dart';
import '../../../features/paper_workflow/domain/usecases/get_drafts_usecase.dart';
import '../../../features/paper_workflow/domain/usecases/get_paper_by_id_usecase.dart';
import '../../../features/paper_workflow/domain/usecases/get_papers_for_review_usecase.dart';
import '../../../features/paper_workflow/domain/usecases/get_user_submissions_usecase.dart';
import '../../../features/paper_workflow/domain/usecases/pull_for_editing_usecase.dart';
import '../../../features/paper_workflow/domain/usecases/save_draft_usecase.dart';
import '../../../features/paper_workflow/domain/usecases/submit_paper_usecase.dart';
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
import '../utils/platform_utils.dart';
import '../database/hive_database_helper.dart';
import '../network/api_client.dart';

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
import '../../../features/paper_review/domain/usecases/reject_paper_usecase.dart';

// Grade feature
import '../../../features/catalog/data/repositories/grade_repository_impl.dart';
import '../../../features/catalog/domain/repositories/grade_repository.dart';

// Assignment feature imports
import '../../../features/assignments/data/datasources/assignment_data_source.dart';
import '../../../features/assignments/data/repositories/assignment_repository_impl.dart';
import '../../../features/assignments/domain/repositories/assignment_repository.dart';
import '../../../features/assignments/presentation/bloc/teacher_assignment_bloc.dart';

// Notification feature imports
import '../../../features/notifications/data/datasources/notification_data_source.dart';
import '../../../features/notifications/data/repositories/notification_repository.dart';
import '../../../features/notifications/domain/repositories/i_notification_repository.dart';
import '../../../features/notifications/domain/usecases/create_notification_usecase.dart';
import '../../../features/notifications/domain/usecases/get_user_notifications_usecase.dart';
import '../../../features/notifications/domain/usecases/mark_notification_read_usecase.dart';
import '../../../features/notifications/domain/usecases/get_unread_count_usecase.dart';

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
    await _AssignmentModule.setup();
    await _NotificationModule.setup();

    final setupDuration = DateTime.now().difference(setupStartTime);
    sl<ILogger>().info(
      'Dependencies initialized successfully',
      category: LogCategory.system,
      context: {
        'duration': '${setupDuration.inMilliseconds}ms',
        'components': ['database', 'network', 'auth', 'question_papers', 'grades', 'exam_types', 'user_info_service', 'paper_display_service', 'assignments', 'notifications'],
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

  // Analytics service (depends on nothing - can be stubbed)
  sl.registerLazySingleton<IAnalyticsService>(() => AnalyticsService());

  // Network service third (depends on logger)
  sl.registerLazySingleton<INetworkService>(() => NetworkServiceImpl(sl<ILogger>()));
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
          Supabase.instance.client,
        ),
      );

      // Repositories - application boundary, includes logging
      sl.registerLazySingleton<AuthRepository>(
            () => AuthRepositoryImpl(
          sl<AuthDataSource>(),
          sl<ILogger>(),
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
            () => UserDataSourceImpl(Supabase.instance.client, sl<ILogger>()),
      );

      sl.registerLazySingleton<UserRepository>(
            () => UserRepositoryImpl(sl<UserDataSource>(), sl<ILogger>()),
      );

      // Domain services - CORRECT: Only pass ILogger
      sl.registerLazySingleton<UserStateService>(
            () => UserStateService(sl<ILogger>()), // ✅ CORRECT - single positional parameter
      );

      // Setup onboarding dependencies (after all dependencies are ready)
      _setupOnboardingDependencies();

      // Presentation layer (BLoC) - registered as factory for multiple instances
      // Note: AuthBloc is special - it's a singleton because it manages global auth state
      sl.registerLazySingleton<AuthBloc>(() => AuthBloc(
        sl<AuthUseCase>(),
        sl<UserStateService>(),
      ));

      sl<ILogger>().info(
        'Authentication module initialized successfully',
        category: LogCategory.system,
        context: {
          'authProvider': 'supabase_google_oauth',
          'redirectUrl': AuthConfig.redirectUrl,
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

  static void _setupOnboardingDependencies() {
    sl<ILogger>().debug('Setting up onboarding dependencies', category: LogCategory.auth);

    // Register SeedTenantUseCase
    sl.registerLazySingleton<SeedTenantUseCase>(
          () => SeedTenantUseCase(
        sl<SubjectRepository>(),
        sl<GradeRepository>(),
        sl<ILogger>(),
      ),
    );

    sl<ILogger>().debug('Onboarding dependencies registered successfully', category: LogCategory.auth, context: {
      'useCase': 'SeedTenantUseCase',
      'dependencies': ['SubjectRepository', 'GradeRepository'],
    });
  }

  static void _setupTenantDependencies() {
    sl<ILogger>().debug('Setting up tenant dependencies', category: LogCategory.auth);

    // 1. Register TenantDataSource first
    sl.registerLazySingleton<TenantDataSource>(
          () => TenantDataSourceImpl(sl<ApiClient>(), sl<ILogger>()),
    );

    // 2. Then register TenantRepository that depends on TenantDataSource
    sl.registerLazySingleton<TenantRepository>(
          () => TenantRepositoryImpl(sl<TenantDataSource>(), sl<ILogger>()),
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

  static void _setupSubjects() {
    sl<ILogger>().debug('Setting up subjects', category: LogCategory.paper);

    // Data Sources
    sl.registerLazySingleton<SubjectDataSource>(
          () => SubjectDataSourceImpl(Supabase.instance.client, sl<ILogger>()),
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
          () => PaperCloudDataSourceImpl(sl<ApiClient>(), sl<ILogger>()),
    );
  }

  static void _setupRepositories() {
    sl<ILogger>().debug('Setting up question papers repositories', category: LogCategory.paper);

    sl.registerLazySingleton<QuestionPaperRepository>(
          () => QuestionPaperRepositoryImpl(
        sl<PaperLocalDataSource>(),
        sl<PaperCloudDataSource>(),
        sl<ILogger>(),
      ),
    );
  }

  static void _setupUseCases() {
    sl<ILogger>().debug('Setting up question papers use cases', category: LogCategory.paper);

    final repository = sl<QuestionPaperRepository>();

    sl.registerLazySingleton(() => SaveDraftUseCase(repository));
    sl.registerLazySingleton(() => GetDraftsUseCase(repository));
    sl.registerLazySingleton(() => DeleteDraftUseCase(repository));
    sl.registerLazySingleton(() => SubmitPaperUseCase(repository));
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
    sl.registerLazySingleton(() => GetPaperByIdUseCase(repository));
    sl.registerLazySingleton(() => PullForEditingUseCase(repository));
    sl.registerLazySingleton(() => GetAllPapersForAdminUseCase(repository));
    sl.registerLazySingleton(() => GetApprovedPapersUseCase(repository));
    sl.registerLazySingleton(() => GetApprovedPapersPaginatedUseCase(repository));
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
          () => GradeDataSourceImpl(Supabase.instance.client, sl<ILogger>()),
    );
  }

  static void _setupRepositories() {
    sl<ILogger>().debug('Setting up grade repositories', category: LogCategory.system);

    sl.registerLazySingleton<GradeRepository>(
          () => GradeRepositoryImpl(sl<GradeDataSource>(), sl<ILogger>()),
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
  }
}

/// Assignment feature dependencies
class _AssignmentModule {
  static Future<void> setup() async {
    try {
      sl<ILogger>().debug('Initializing assignment module', category: LogCategory.system);

      _setupDataSources();
      _setupRepositories();
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

    sl.registerLazySingleton<AssignmentDataSource>(
          () => AssignmentDataSourceImpl(
        Supabase.instance.client,
        sl<ILogger>(),
      ),
    );
  }

  static void _setupRepositories() {
    sl<ILogger>().debug('Setting up assignment repositories', category: LogCategory.system);

    sl.registerLazySingleton<AssignmentRepository>(
          () => AssignmentRepositoryImpl(
        sl<AssignmentDataSource>(),
        sl<GradeDataSource>(),
        sl<SubjectDataSource>(),
        sl<ILogger>(),
      ),
    );
  }

  static void _setupBlocs() {
    sl<ILogger>().debug('Setting up assignment BLoCs', category: LogCategory.system);

    // Register as factory so each page gets its own instance
    sl.registerFactory<TeacherAssignmentBloc>(
          () => TeacherAssignmentBloc(
        sl<AssignmentRepository>(),
        sl<GradeRepository>(),
        sl<SubjectRepository>(),
        sl<UserStateService>(),
      ),
    );

    sl<ILogger>().debug('TeacherAssignmentBloc registered successfully', category: LogCategory.system);
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
      // Logger might already be disposed, use print
      print('Errors during cleanup (logger unavailable):');
      for (final error in errors) {
        print('  - $error');
      }
    }
  }

  // Reset all registrations
  try {
    await sl.reset();
    print('✅ Dependencies cleaned up successfully${errors.isNotEmpty ? ' (with ${errors.length} warnings)' : ''}');
  } catch (e, stackTrace) {
    print('❌ Failed to reset dependency injection container: $e');
    print('StackTrace: $stackTrace');
    rethrow;
  }
}