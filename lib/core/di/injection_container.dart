import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/authentication/data/datasources/auth_data_source.dart';
import '../../features/authentication/data/repositories/auth_repository_impl.dart';
import '../../features/authentication/domain/repositories/auth_repository.dart';
import '../../features/authentication/domain/usecases/auth_usecase.dart';
import '../../features/question_papers/data/datasources/paper_cloud_data_source.dart';
import '../../features/question_papers/data/datasources/paper_local_data_source.dart';
import '../../features/question_papers/data/repositories/question_paper_repository_impl.dart';
import '../../features/question_papers/domain/repositories/question_paper_repository.dart';
import '../../features/question_papers/domain/usecases/approve_paper_usecase.dart';
import '../../features/question_papers/domain/usecases/delete_draft_usecase.dart';
import '../../features/question_papers/domain/usecases/get_drafts_usecase.dart';
import '../../features/question_papers/domain/usecases/get_papers_for_review_usecase.dart';
import '../../features/question_papers/domain/usecases/get_user_submissions_usecase.dart';
import '../../features/question_papers/domain/usecases/get_paper_by_id_usecase.dart';
import '../../features/question_papers/domain/usecases/pull_for_editing_usecase.dart';
import '../../features/question_papers/domain/usecases/reject_paper_usecase.dart';
import '../../features/question_papers/domain/usecases/save_draft_usecase.dart';
import '../../features/question_papers/domain/usecases/submit_paper_usecase.dart';
import '../config/app_config.dart';
import '../utils/app_logger.dart';

final sl = GetIt.instance;

Future<void> setupDependencies() async {
  try {
    await _setupSupabase();
    _setupAuth();
    _setupQuestionPapers();
    AppLogger.info('All dependencies initialized successfully');
  } catch (e) {
    AppLogger.error('Failed to setup dependencies', e);
    rethrow;
  }
}

Future<void> _setupSupabase() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
}

void _setupAuth() {
  final supabase = Supabase.instance.client;

  sl.registerLazySingleton<AuthDataSource>(
        () => AuthDataSource(supabase),
  );

  sl.registerLazySingleton<AuthRepository>(
        () => AuthRepositoryImpl(sl<AuthDataSource>(), AppConfig.authRedirectUrl),
  );

  sl.registerLazySingleton<AuthUseCase>(
        () => AuthUseCase(sl<AuthRepository>()),
  );
}

void _setupQuestionPapers() {
  final supabase = Supabase.instance.client;

  // Data sources
  sl.registerLazySingleton<PaperLocalDataSource>(() => PaperLocalDataSourceImpl());
  sl.registerLazySingleton<PaperCloudDataSource>(() => PaperCloudDataSourceImpl(supabase));

  // Repository
  sl.registerLazySingleton<QuestionPaperRepository>(
        () => QuestionPaperRepositoryImpl(sl<PaperLocalDataSource>(), sl<PaperCloudDataSource>()),
  );

  // Use cases
  final repo = sl<QuestionPaperRepository>();
  sl.registerLazySingleton(() => SaveDraftUseCase(repo));
  sl.registerLazySingleton(() => GetDraftsUseCase(repo));
  sl.registerLazySingleton(() => DeleteDraftUseCase(repo));
  sl.registerLazySingleton(() => SubmitPaperUseCase(repo));
  sl.registerLazySingleton(() => GetUserSubmissionsUseCase(repo));
  sl.registerLazySingleton(() => GetPapersForReviewUseCase(repo));
  sl.registerLazySingleton(() => ApprovePaperUseCase(repo));
  sl.registerLazySingleton(() => RejectPaperUseCase(repo));
  sl.registerLazySingleton(() => GetPaperByIdUseCase(repo));
  sl.registerLazySingleton(() => PullForEditingUseCase(repo));
}
