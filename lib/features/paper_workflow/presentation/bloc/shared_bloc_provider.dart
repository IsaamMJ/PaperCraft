// shared_bloc_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../catalog/presentation/bloc/grade_bloc.dart';
import '../../../catalog/presentation/bloc/subject_bloc.dart';
import '../../../notifications/presentation/bloc/notification_bloc.dart';
import '../../../home/presentation/bloc/home_bloc.dart';
import '../../../question_bank/presentation/bloc/question_bank_bloc.dart';
import 'question_paper_bloc.dart';

class SharedBlocProvider extends StatelessWidget {
  final Widget child;
  static QuestionPaperBloc? _sharedQuestionPaperBloc;
  static GradeBloc? _sharedGradeBloc;
  static SubjectBloc? _sharedSubjectBloc;
  static NotificationBloc? _sharedNotificationBloc;
  // HomeBloc and QuestionBankBloc now use DI container - no singleton needed

  const SharedBlocProvider({super.key, required this.child});

  static QuestionPaperBloc getQuestionPaperBloc() {
    _sharedQuestionPaperBloc ??= QuestionPaperBloc(
      saveDraftUseCase: sl(),
      submitPaperUseCase: sl(),
      getDraftsUseCase: sl(),
      getUserSubmissionsUseCase: sl(),
      approvePaperUseCase: sl(),
      rejectPaperUseCase: sl(),
      restoreSparePaperUseCase: sl(),
      questionPaperRepository: sl(),
      getPapersForReviewUseCase: sl(),
      deleteDraftUseCase: sl(),
      pullForEditingUseCase: sl(),
      getPaperByIdUseCase: sl(),
      getAllPapersForAdminUseCase: sl(),
      getApprovedPapersUseCase: sl(),
      getApprovedPapersPaginatedUseCase: sl(),
      getApprovedPapersByExamDateRangeUseCase: sl(),
      updatePaperUseCase: sl(),
    );
    return _sharedQuestionPaperBloc!;
  }

  static GradeBloc getGradeBloc() {
    _sharedGradeBloc ??= sl<GradeBloc>();
    return _sharedGradeBloc!;
  }

  static SubjectBloc getSubjectBloc() {
    _sharedSubjectBloc ??= sl<SubjectBloc>();
    return _sharedSubjectBloc!;
  }

  static NotificationBloc getNotificationBloc() {
    _sharedNotificationBloc ??= NotificationBloc(
      getUserNotificationsUseCase: sl(),
      getUnreadCountUseCase: sl(),
      markNotificationReadUseCase: sl(),
      logger: sl<ILogger>(),
    );
    return _sharedNotificationBloc!;
  }

  static HomeBloc getHomeBloc() {
    // Use DI container instead of singleton
    return sl<HomeBloc>();
  }

  static QuestionBankBloc getQuestionBankBloc() {
    // Use DI container instead of singleton
    return sl<QuestionBankBloc>();
  }

  static void disposeAll() {
    _sharedQuestionPaperBloc?.close();
    _sharedQuestionPaperBloc = null;
    _sharedGradeBloc?.close();
    _sharedGradeBloc = null;
    _sharedSubjectBloc?.close();
    _sharedSubjectBloc = null;
    _sharedNotificationBloc?.close();
    _sharedNotificationBloc = null;
    // HomeBloc and QuestionBankBloc are auto-disposed by BlocProvider
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<QuestionPaperBloc>.value(value: getQuestionPaperBloc()),
        BlocProvider<GradeBloc>.value(value: getGradeBloc()),
        BlocProvider<SubjectBloc>.value(value: getSubjectBloc()),
        BlocProvider<NotificationBloc>.value(value: getNotificationBloc()),
        BlocProvider<HomeBloc>.value(value: getHomeBloc()),
        BlocProvider<QuestionBankBloc>.value(value: getQuestionBankBloc()),
      ],
      child: child,
    );
  }
}