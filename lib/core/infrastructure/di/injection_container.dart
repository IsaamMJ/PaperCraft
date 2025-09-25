// core/infrastructure/di/injection_container.dart
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Core domain interfaces
import '../../../features/authentication/presentation/bloc/auth_bloc.dart';
import '../../../features/question_papers/domain/usecases/get_grades_usecase.dart';
import '../../domain/interfaces/i_logger.dart';
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
import '../../../features/question_papers/data/datasources/paper_cloud_data_source.dart';
import '../../../features/question_papers/data/datasources/paper_local_data_source.dart';
import '../../../features/question_papers/data/datasources/paper_local_data_source_hive.dart';
import '../../../features/question_papers/data/repositories/question_paper_repository_impl.dart';
import '../../../features/question_papers/domain/repositories/question_paper_repository.dart';
import '../../../features/question_papers/domain/usecases/approve_paper_usecase.dart';
import '../../../features/question_papers/domain/usecases/delete_draft_usecase.dart';
import '../../../features/question_papers/domain/usecases/get_drafts_usecase.dart';
import '../../../features/question_papers/domain/usecases/get_paper_by_id_usecase.dart';
import '../../../features/question_papers/domain/usecases/get_papers_for_review_usecase.dart';
import '../../../features/question_papers/domain/usecases/get_user_submissions_usecase.dart';
import '../../../features/question_papers/domain/usecases/pull_for_editing_usecase.dart';
import '../../../features/question_papers/domain/usecases/reject_paper_usecase.dart';
import '../../../features/question_papers/domain/usecases/save_draft_usecase.dart';
import '../../../features/question_papers/domain/usecases/submit_paper_usecase.dart';
import '../../../features/question_papers/domain/usecases/get_all_papers_for_admin_usecase.dart';
import '../../../features/question_papers/domain/usecases/get_approved_papers_usecase.dart';

// NEW: Exam Type imports
import '../../../features/question_papers/data/datasources/exam_type_data_source.dart';
import '../../../features/question_papers/data/repositories/exam_type_repository_impl.dart';
import '../../../features/question_papers/domain/repositories/exam_type_repository.dart';
import '../../../features/question_papers/domain/usecases/get_exam_types_usecase.dart';

// Grade feature
import '../../../features/question_papers/data/datasources/grade_data_source.dart';
import '../../../features/question_papers/data/repositories/grade_repository_impl.dart';
import '../../../features/question_papers/domain/repositories/grade_repository.dart';
import '../../../features/question_papers/presentation/bloc/grade_bloc.dart';

/// Global service locator instance
final sl = GetIt.instance;

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

    final setupDuration = DateTime.now().difference(setupStartTime);
    sl<ILogger>().info(
      'Dependencies initialized successfully',
      category: LogCategory.system,
      context: {
        'duration': '${setupDuration.inMilliseconds}ms',
        'components': ['database', 'network', 'auth', 'question_papers', 'grades', 'exam_types'],
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

      // Use cases - clean domain logic, no infrastructure concerns
      sl.registerLazySingleton<AuthUseCase>(
            () => AuthUseCase(sl<AuthRepository>()),
      );

      // Domain services - can have their own logging if needed
      sl.registerLazySingleton<UserStateService>(
            () => UserStateService(sl<ILogger>()),
      );

      // Presentation layer (BLoC) - registered as factory for multiple instances
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
}

/// Question papers feature dependencies
class _QuestionPapersModule {
  static Future<void> setup() async {
    try {
      sl<ILogger>().debug('Initializing question papers module', category: LogCategory.paper);

      _setupDataSources();
      _setupRepositories();
      _setupUseCases();
      _setupExamTypes(); // NEW: Add exam types setup

      sl<ILogger>().info(
        'Question papers module initialized successfully',
        category: LogCategory.system,
        context: {
          'features': ['drafts', 'submissions', 'reviews', 'approval_workflow', 'exam_types'],
          'useCasesRegistered': 14, // Updated count (12 + 2 exam type use cases)
          'dataSourcesRegistered': 3, // Updated count (2 + 1 exam type data source)
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

  static void _setupDataSources() {
    sl<ILogger>().debug('Setting up question papers data sources', category: LogCategory.paper);

    // Data sources - infrastructure boundary, includes logging
    sl.registerLazySingleton<PaperLocalDataSource>(
          () => PaperLocalDataSourceHive(sl<HiveDatabaseHelper>(), sl<ILogger>()),
    );

    sl.registerLazySingleton<PaperCloudDataSource>(
          () => PaperCloudDataSourceImpl(sl<ApiClient>(), sl<ILogger>()),
    );
  }

  static void _setupRepositories() {
    sl<ILogger>().debug('Setting up question papers repositories', category: LogCategory.paper);

    // Repositories - application boundary, includes logging
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

    // Use cases - pure domain logic, no infrastructure dependencies
    sl.registerLazySingleton(() => SaveDraftUseCase(repository));
    sl.registerLazySingleton(() => GetDraftsUseCase(repository));
    sl.registerLazySingleton(() => DeleteDraftUseCase(repository));
    sl.registerLazySingleton(() => SubmitPaperUseCase(repository));
    sl.registerLazySingleton(() => GetUserSubmissionsUseCase(repository));
    sl.registerLazySingleton(() => GetPapersForReviewUseCase(repository));
    sl.registerLazySingleton(() => ApprovePaperUseCase(repository));
    sl.registerLazySingleton(() => RejectPaperUseCase(repository));
    sl.registerLazySingleton(() => GetPaperByIdUseCase(repository));
    sl.registerLazySingleton(() => PullForEditingUseCase(repository));
    sl.registerLazySingleton(() => GetAllPapersForAdminUseCase(repository));
    sl.registerLazySingleton(() => GetApprovedPapersUseCase(repository));
  }

  // NEW: Exam Types setup
  static void _setupExamTypes() {
    sl<ILogger>().debug('Setting up exam types', category: LogCategory.examtype);

    // Data Sources
    sl.registerLazySingleton<ExamTypeDataSource>(
          () => ExamTypeSupabaseDataSource(Supabase.instance.client, sl<ILogger>()),
    );

    // Repositories
    sl.registerLazySingleton<ExamTypeRepository>(
          () => ExamTypeRepositoryImpl(sl<ExamTypeDataSource>(), sl<ILogger>()),
    );

    // Use Cases
    sl.registerLazySingleton(() => GetExamTypesUseCase(sl<ExamTypeRepository>()));
    sl.registerLazySingleton(() => GetExamTypeByIdUseCase(sl<ExamTypeRepository>()));
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

    // Data sources - infrastructure boundary, includes logging
    sl.registerLazySingleton<GradeDataSource>(
          () => GradeDataSourceImpl(sl<ApiClient>(), sl<ILogger>()),
    );
  }

  static void _setupRepositories() {
    sl<ILogger>().debug('Setting up grade repositories', category: LogCategory.system);

    // Repositories - application boundary, includes logging
    sl.registerLazySingleton<GradeRepository>(
          () => GradeRepositoryImpl(sl<GradeDataSource>(), sl<ILogger>()),
    );
  }

  static void _setupUseCases() {
    sl<ILogger>().debug('Setting up grade use cases', category: LogCategory.system);

    final repository = sl<GradeRepository>();

    // Use cases - pure domain logic
    sl.registerLazySingleton(() => GetGradesUseCase(repository));
    sl.registerLazySingleton(() => GetGradeLevelsUseCase(repository));
    sl.registerLazySingleton(() => GetSectionsByGradeUseCase(repository));

    // BLoC registration
    sl.registerFactory<GradeBloc>(
          () => GradeBloc(repository: sl<GradeRepository>()),
    );
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
  try {
    // Dispose network service if it exists
    if (sl.isRegistered<INetworkService>()) {
      sl<INetworkService>().dispose();
    }

    // Reset all registrations
    await sl.reset();

    // Use print since logger might not be available after reset
    print('Dependencies cleaned up successfully');
  } catch (e, stackTrace) {
    print('Failed to cleanup dependencies: $e');
    print('StackTrace: $stackTrace');
  }
}