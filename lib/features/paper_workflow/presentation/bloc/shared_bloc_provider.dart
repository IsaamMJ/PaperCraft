// shared_bloc_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../catalog/presentation/bloc/grade_bloc.dart';
import '../../../catalog/presentation/bloc/subject_bloc.dart';
import 'question_paper_bloc.dart';

class SharedBlocProvider extends StatelessWidget {
  final Widget child;
  static QuestionPaperBloc? _sharedQuestionPaperBloc;
  static GradeBloc? _sharedGradeBloc;
  static SubjectBloc? _sharedSubjectBloc;

  const SharedBlocProvider({super.key, required this.child});

  static QuestionPaperBloc getQuestionPaperBloc() {
    _sharedQuestionPaperBloc ??= QuestionPaperBloc(
      saveDraftUseCase: sl(),
      submitPaperUseCase: sl(),
      getDraftsUseCase: sl(),
      getUserSubmissionsUseCase: sl(),
      approvePaperUseCase: sl(),
      rejectPaperUseCase: sl(),
      getPapersForReviewUseCase: sl(),
      deleteDraftUseCase: sl(),
      pullForEditingUseCase: sl(),
      getPaperByIdUseCase: sl(),
      getAllPapersForAdminUseCase: sl(),
      getApprovedPapersUseCase: sl(),
      getExamTypesUseCase: sl(),
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

  static void disposeAll() {
    _sharedQuestionPaperBloc?.close();
    _sharedQuestionPaperBloc = null;
    _sharedGradeBloc?.close();
    _sharedGradeBloc = null;
    _sharedSubjectBloc?.close();
    _sharedSubjectBloc = null;
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<QuestionPaperBloc>.value(value: getQuestionPaperBloc()),
        BlocProvider<GradeBloc>.value(value: getGradeBloc()),
        BlocProvider<SubjectBloc>.value(value: getSubjectBloc()),
      ],
      child: child,
    );
  }
}