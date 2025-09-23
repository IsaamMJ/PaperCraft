import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// Core imports
import '../../domain/interfaces/i_logger.dart';
import '../../infrastructure/di/injection_container.dart';
import '../../infrastructure/logging/app_logger.dart';
import '../constants/app_messages.dart';
// Feature imports
import '../../../features/question_papers/presentation/bloc/question_paper_bloc.dart';
import 'app_error_widget.dart';

/// Simplified BLoC provider utilities
class AppBlocProviders {
  AppBlocProviders._();

  /// Create QuestionPaperBloc with all dependencies
  static QuestionPaperBloc createQuestionPaperBloc() {
    try {
      return QuestionPaperBloc(
        saveDraftUseCase: sl(),
        submitPaperUseCase: sl(),
        getUserSubmissionsUseCase: sl(),
        approvePaperUseCase: sl(),
        rejectPaperUseCase: sl(),
        getPapersForReviewUseCase: sl(),
        deleteDraftUseCase: sl(),
        pullForEditingUseCase: sl(),
        getPaperByIdUseCase: sl(),
        getDraftsUseCase: sl(),
        getAllPapersForAdminUseCase: sl(), // NEW
        getApprovedPapersUseCase: sl(),    // NEW
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed to create QuestionPaperBloc',
          error: error,
          stackTrace: stackTrace,
          category: LogCategory.bloc);
      rethrow;
    }
  }

  /// Widget wrapper that provides QuestionPaperBloc to its child
  static Widget withQuestionPaperBloc({
    required Widget child,
    QuestionPaperBloc? bloc,
  }) {
    return BlocProvider<QuestionPaperBloc>(
      create: (context) => bloc ?? createQuestionPaperBloc(),
      child: child,
    );
  }

  /// Route builder for question paper routes
  static Widget Function(BuildContext, GoRouterState) questionPaperRoute(
      Widget Function(BuildContext) builder,
      ) {
    return (context, state) {
      try {
        return withQuestionPaperBloc(
          child: builder(context),
        );
      } catch (error) {
        AppLogger.error('Failed to build question paper route',
            category: LogCategory.navigation,
            error: error,
            context: {'route': state.matchedLocation});

        return AppErrorWidget(
          title: 'Route Error',
          message: AppMessages.routeError,
          error: error,
          showError: true,
        );
      }
    };
  }

  /// Route builder with parameter extraction
  static Widget Function(BuildContext, GoRouterState) questionPaperRouteWithId(
      Widget Function(BuildContext, String) builder, {
        String paramKey = 'id',
      }) {
    return (context, state) {
      final id = state.pathParameters[paramKey];

      if (id == null) {
        AppLogger.warning('Missing required route parameter',
            category: LogCategory.navigation,
            context: {
              'route': state.matchedLocation,
              'paramKey': paramKey,
            });

        return AppErrorWidget(
          title: 'Parameter Missing',
          message: AppMessages.parameterMissing,
          icon: Icons.warning,
          color: Colors.orange,
        );
      }

      try {
        return withQuestionPaperBloc(
          child: builder(context, id),
        );
      } catch (error) {
        AppLogger.error('Failed to build question paper route with ID',
            category: LogCategory.navigation,
            error: error,
            context: {
              'route': state.matchedLocation,
              'paramKey': paramKey,
              'paramValue': id,
            });

        return AppErrorWidget(
          title: 'Route Error',
          message: AppMessages.routeError,
          error: error,
          showError: true,
        );
      }
    };
  }
}

/// Extension methods for convenient BLoC access
extension BlocProviderExtensions on BuildContext {
  QuestionPaperBloc get questionPaperBloc => read<QuestionPaperBloc>();
}