// features/home/presentation/bloc/home_bloc.dart
import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../../core/infrastructure/realtime/realtime_service.dart';
import '../../../paper_workflow/data/models/question_paper_model.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';
import '../../../paper_workflow/domain/services/paper_display_service.dart';
import '../../../paper_workflow/domain/usecases/get_drafts_usecase.dart';
import '../../../paper_workflow/domain/usecases/get_user_submissions_usecase.dart';
import '../../../paper_workflow/domain/usecases/get_papers_for_review_usecase.dart';
import '../../../paper_workflow/domain/usecases/get_all_papers_for_admin_usecase.dart';
import '../../../catalog/domain/repositories/grade_repository.dart';
import '../../../assignments/domain/repositories/teacher_subject_repository.dart';
import '../../../catalog/domain/entities/teacher_class.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_event.dart';
import 'home_state.dart';

/// HomeBloc manages the state of the home page for both teachers and admins
///
/// Responsibilities:
/// - Load papers based on user role (teacher: drafts/submissions, admin: review/all)
/// - Handle realtime updates for live paper changes
/// - Enrich papers with display data (subject names, grades)
/// - Manage refresh operations
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetDraftsUseCase _getDraftsUseCase;
  final GetUserSubmissionsUseCase _getSubmissionsUseCase;
  final GetPapersForReviewUseCase _getPapersForReviewUseCase;
  final GetAllPapersForAdminUseCase _getAllPapersForAdminUseCase;
  final RealtimeService _realtimeService;
  final PaperDisplayService _paperDisplayService;
  final GradeRepository _gradeRepository;
  final TeacherSubjectRepository _teacherSubjectRepository;

  // Realtime channel names
  static const String _adminChannelName = 'home_admin_papers';
  static const String _teacherChannelName = 'home_teacher_papers';

  // Debouncing for realtime updates (batch multiple updates)
  Timer? _realtimeDebounceTimer;
  final List<PaperRealtimeUpdate> _pendingRealtimeUpdates = [];
  static const Duration _realtimeDebounceInterval = Duration(milliseconds: 500);

  HomeBloc({
    required GetDraftsUseCase getDraftsUseCase,
    required GetUserSubmissionsUseCase getSubmissionsUseCase,
    required GetPapersForReviewUseCase getPapersForReviewUseCase,
    required GetAllPapersForAdminUseCase getAllPapersForAdminUseCase,
    required RealtimeService realtimeService,
    required PaperDisplayService paperDisplayService,
    required GradeRepository gradeRepository,
    required TeacherSubjectRepository teacherSubjectRepository,
  })  : _getDraftsUseCase = getDraftsUseCase,
        _getSubmissionsUseCase = getSubmissionsUseCase,
        _getPapersForReviewUseCase = getPapersForReviewUseCase,
        _getAllPapersForAdminUseCase = getAllPapersForAdminUseCase,
        _realtimeService = realtimeService,
        _paperDisplayService = paperDisplayService,
        _gradeRepository = gradeRepository,
        _teacherSubjectRepository = teacherSubjectRepository,
        super(const HomeLoading(message: 'Initializing...')) {
    on<LoadHomePapers>(_onLoadHomePapers);
    on<RefreshHomePapers>(_onRefreshHomePapers);
    on<EnableRealtimeUpdates>(_onEnableRealtimeUpdates);
    on<DisableRealtimeUpdates>(_onDisableRealtimeUpdates);
    on<PaperRealtimeUpdate>(_onPaperRealtimeUpdate);
    on<LoadTeacherClasses>(_onLoadTeacherClasses);
  }

  @override
  Future<void> close() async {
    // Cancel pending debounce timer
    _realtimeDebounceTimer?.cancel();
    _pendingRealtimeUpdates.clear();

    // Unsubscribe from realtime
    await _realtimeService.unsubscribe(_adminChannelName);
    await _realtimeService.unsubscribe(_teacherChannelName);
    return super.close();
  }

  // ==================== Event Handlers ====================

  Future<void> _onLoadHomePapers(
      LoadHomePapers event,
      Emitter<HomeState> emit,
      ) async {
    emit(const HomeLoading(message: 'Loading...'));

    try {
      if (event.isAdmin) {
        await _loadAdminPapers(emit);
      } else {
        await _loadTeacherPapers(emit, event.userId);
      }
    } catch (e) {
      emit(HomeError('Failed to load papers: $e'));
    }
  }

  Future<void> _onRefreshHomePapers(
      RefreshHomePapers event,
      Emitter<HomeState> emit,
      ) async {
    // Don't show loading state on refresh (keep current data visible)
    try {
      if (event.isAdmin) {
        await _loadAdminPapers(emit);
      } else {
        await _loadTeacherPapers(emit, event.userId);
      }
    } catch (e) {
      // On refresh error, keep current state (silent failure)
      // User will see the data they already have
    }
  }

  Future<void> _onEnableRealtimeUpdates(
      EnableRealtimeUpdates event,
      Emitter<HomeState> emit,
      ) async {
    try {
      final channelName = event.isAdmin ? _adminChannelName : _teacherChannelName;

      _realtimeService.subscribeToTable(
        table: 'question_papers',
        channelName: channelName,
        onInsert: (payload) => add(PaperRealtimeUpdate(
          paperData: payload,
          eventType: RealtimeEventType.insert,
        )),
        onUpdate: (payload) => add(PaperRealtimeUpdate(
          paperData: payload,
          eventType: RealtimeEventType.update,
        )),
        onDelete: (payload) => add(PaperRealtimeUpdate(
          paperData: payload,
          eventType: RealtimeEventType.delete,
        )),
      );
    } catch (e) {
      // Log error but don't fail - realtime is optional enhancement
    }
  }

  Future<void> _onDisableRealtimeUpdates(
      DisableRealtimeUpdates event,
      Emitter<HomeState> emit,
      ) async {
    await _realtimeService.unsubscribe(_adminChannelName);
    await _realtimeService.unsubscribe(_teacherChannelName);
  }

  Future<void> _onPaperRealtimeUpdate(
      PaperRealtimeUpdate event,
      Emitter<HomeState> emit,
      ) async {
    // Only process if we have loaded state
    if (state is! HomeLoaded) return;

    // Add to pending updates
    _pendingRealtimeUpdates.add(event);

    // Cancel existing timer and start new one
    _realtimeDebounceTimer?.cancel();
    _realtimeDebounceTimer = Timer(_realtimeDebounceInterval, () async {
      try {
        await _processPendingRealtimeUpdates(emit);
      } catch (e) {
        // Log error but don't fail
      }
    });
  }

  Future<void> _onLoadTeacherClasses(
      LoadTeacherClasses event,
      Emitter<HomeState> emit,
      ) async {
    try {
      final supabase = Supabase.instance.client;

      // Query teacher_subjects directly (WITHOUT academicYear filter)
      // Fetches: grade_id, section, subject_id for this teacher
      final teacherSubjectsData = await supabase
          .from('teacher_subjects')
          .select('grade_id, section, subject_id')
          .eq('teacher_id', event.userId)
          .eq('is_active', true);

      final teacherClasses = <TeacherClass>[];

      if (teacherSubjectsData.isEmpty) {
        // No classes assigned
        if (state is HomeLoaded) {
          final currentState = state as HomeLoaded;
          emit(currentState.copyWith(teacherClasses: []));
        }
        return;
      }

      // Collect all unique subject IDs to fetch their names
      final subjectIds = <String>{};
      for (final record in teacherSubjectsData as List) {
        final subjectId = record['subject_id'] as String;
        subjectIds.add(subjectId);
      }

      // Fetch subject names from subjects table (with join to subject_catalog)
      final subjectNamesMap = <String, String>{}; // subjectId -> subjectName
      if (subjectIds.isNotEmpty) {
        try {
          // Query subjects with join to subject_catalog to get subject_name
          final subjectsData = await supabase
              .from('subjects')
              .select('id, subject_catalog(subject_name)')
              .inFilter('id', subjectIds.toList());

          for (final record in subjectsData as List) {
            final id = record['id'] as String;
            final catalogData = record['subject_catalog'] as Map<String, dynamic>?;
            final name = catalogData?['subject_name'] as String? ?? 'Unknown Subject';
            subjectNamesMap[id] = name;
          }
        } catch (e) {
          // Log error but continue with fallback (subject IDs will be displayed)
        }
      }

      // Group by grade+section to get unique classes
      final classMap = <String, Set<String>>{}; // "gradeId#section" -> {subject_names}
      final gradeNumbers = <String, int>{}; // gradeId -> gradeNumber

      for (final record in teacherSubjectsData as List) {
        final gradeId = record['grade_id'] as String;
        final section = record['section'] as String;
        final subjectId = record['subject_id'] as String;

        final classKey = '$gradeId#$section';
        classMap.putIfAbsent(classKey, () => {});

        // Use subject name if available, otherwise use ID as fallback
        final subjectName = subjectNamesMap[subjectId] ?? subjectId;
        classMap[classKey]!.add(subjectName);
      }

      // Fetch grade information to get grade numbers
      final gradesResult = await _gradeRepository.getGrades();
      await gradesResult.fold(
        (failure) async {
          // Use fallback: just use gradeId as number
        },
        (grades) async {
          for (final grade in grades) {
            gradeNumbers[grade.id] = grade.gradeNumber;
          }
        },
      );

      // Build TeacherClass objects
      for (final entry in classMap.entries) {
        final parts = entry.key.split('#');
        final gradeId = parts[0];
        final section = parts[1];
        final subjectNames = entry.value.toList();
        final gradeNumber = gradeNumbers[gradeId] ?? 0;

        if (gradeNumber > 0) {
          teacherClasses.add(
            TeacherClass(
              gradeId: gradeId,
              gradeNumber: gradeNumber,
              sectionName: section,
              subjectNames: subjectNames,
            ),
          );
        }
      }

      // Sort by grade number, then by section name
      teacherClasses.sort((a, b) {
        final gradeCompare = a.gradeNumber.compareTo(b.gradeNumber);
        if (gradeCompare != 0) return gradeCompare;
        return a.sectionName.compareTo(b.sectionName);
      });

      // Update current state with classes
      if (state is HomeLoaded) {
        final currentState = state as HomeLoaded;
        emit(currentState.copyWith(teacherClasses: teacherClasses));
      }
    } catch (e, stackTrace) {
      // Silently fail - classes are optional enhancement
    }
  }

  /// Process all pending realtime updates in batch
  /// This reduces cascading rebuilds from rapid-fire updates
  Future<void> _processPendingRealtimeUpdates(Emitter<HomeState> emit) async {
    if (_pendingRealtimeUpdates.isEmpty || state is! HomeLoaded) return;

    try {
      final currentState = state as HomeLoaded;
      var newState = currentState;

      // Process each pending update
      for (final event in _pendingRealtimeUpdates) {
        try {
          // Skip enrichment for realtime updates - use basic paper data
          // This avoids unnecessary API calls and improves performance
          final paperModel = QuestionPaperModel.fromSupabase(event.paperData);

          switch (event.eventType) {
            case RealtimeEventType.insert:
              newState = _handleInsert(newState, paperModel);
            case RealtimeEventType.update:
              newState = _handleUpdate(newState, paperModel);
            case RealtimeEventType.delete:
              newState = _handleDelete(newState, paperModel.id);
          }
        } catch (e) {
          // Skip individual update on error
        }
      }

      // Emit single state after batching all updates
      if (newState != currentState) {
        emit(newState);
      }

      _pendingRealtimeUpdates.clear();
    } catch (e) {
      // Log error but don't fail
    }
  }

  // ==================== Private Helper Methods ====================

  /// Load papers for admin users
  Future<void> _loadAdminPapers(Emitter<HomeState> emit) async {
    // Fetch both datasets in parallel
    final results = await Future.wait([
      _getPapersForReviewUseCase(),
      _getAllPapersForAdminUseCase(),
    ]);

    final reviewResult = results[0];
    final allPapersResult = results[1];

    // Handle errors
    final reviewFailure = _extractFailure(reviewResult);
    if (reviewFailure != null) {
      emit(HomeError(reviewFailure.message));
      return;
    }

    final allPapersFailure = _extractFailure(allPapersResult);
    if (allPapersFailure != null) {
      emit(HomeError(allPapersFailure.message));
      return;
    }

    // Extract success values
    final papersForReview = _extractPapers(reviewResult);
    final allPapers = _extractPapers(allPapersResult);

    // Enrich and sort papers
    final enrichedReview = await _enrichAndSortPapers(papersForReview);
    final enrichedAll = await _enrichAndSortPapers(allPapers);

    emit(HomeLoaded(
      papersForReview: enrichedReview,
      allPapersForAdmin: enrichedAll,
    ));
  }

  /// Load papers for teacher users
  Future<void> _loadTeacherPapers(Emitter<HomeState> emit, String? userId) async {
    if (userId == null) {
      emit(const HomeError('User ID not found'));
      return;
    }

    // Fetch both datasets in parallel
    final results = await Future.wait([
      _getDraftsUseCase(),
      _getSubmissionsUseCase(),
    ]);

    final draftsResult = results[0];
    final submissionsResult = results[1];

    // Handle errors
    final draftsFailure = _extractFailure(draftsResult);
    if (draftsFailure != null) {
      emit(HomeError(draftsFailure.message));
      return;
    }

    final submissionsFailure = _extractFailure(submissionsResult);
    if (submissionsFailure != null) {
      emit(HomeError(submissionsFailure.message));
      return;
    }

    // Extract success values
    final drafts = _extractPapers(draftsResult);
    final submissions = _extractPapers(submissionsResult);

    // Enrich and sort papers
    final enrichedDrafts = await _enrichAndSortPapers(drafts);
    final enrichedSubmissions = await _enrichAndSortPapers(submissions);

    emit(HomeLoaded(
      drafts: enrichedDrafts,
      submissions: enrichedSubmissions,
    ));
  }

  /// Enrich papers with display data and sort by modifiedAt (newest first)
  ///
  /// This is a testable business logic method
  Future<List<QuestionPaperEntity>> _enrichAndSortPapers(
      List<QuestionPaperEntity> papers,
      ) async {
    if (papers.isEmpty) return papers;

    final enriched = await _paperDisplayService.enrichPapers(papers);
    enriched.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return enriched;
  }

  /// Extract failure from Either result
  Failure? _extractFailure(Either<Failure, List<QuestionPaperEntity>> result) {
    return result.fold(
          (failure) => failure,
          (_) => null,
    );
  }

  /// Extract papers from Either result
  List<QuestionPaperEntity> _extractPapers(
      Either<Failure, List<QuestionPaperEntity>> result,
      ) {
    return result.fold(
          (_) => [],
          (papers) => papers,
    );
  }

  // ==================== Realtime Update Handlers ====================

  /// Handle INSERT event - add new paper to appropriate list
  HomeLoaded _handleInsert(HomeLoaded currentState, QuestionPaperEntity newPaper) {
    // Add to review queue if status is submitted/pending
    if (newPaper.status.value == 'pending' || newPaper.status.value == 'submitted') {
      return currentState.copyWith(
        papersForReview: [newPaper, ...currentState.papersForReview],
      );
    }

    // Add to all papers (for admin view)
    return currentState.copyWith(
      allPapersForAdmin: [newPaper, ...currentState.allPapersForAdmin],
    );
  }

  /// Handle UPDATE event - update existing paper in all lists
  HomeLoaded _handleUpdate(HomeLoaded currentState, QuestionPaperEntity updatedPaper) {
    return currentState.copyWith(
      drafts: _updatePaperInList(currentState.drafts, updatedPaper),
      submissions: _updatePaperInList(currentState.submissions, updatedPaper),
      papersForReview: _updatePaperInList(currentState.papersForReview, updatedPaper),
      allPapersForAdmin: _updatePaperInList(currentState.allPapersForAdmin, updatedPaper),
    );
  }

  /// Handle DELETE event - remove paper from all lists
  HomeLoaded _handleDelete(HomeLoaded currentState, String paperId) {
    return currentState.copyWith(
      drafts: currentState.drafts.where((p) => p.id != paperId).toList(),
      submissions: currentState.submissions.where((p) => p.id != paperId).toList(),
      papersForReview: currentState.papersForReview.where((p) => p.id != paperId).toList(),
      allPapersForAdmin: currentState.allPapersForAdmin.where((p) => p.id != paperId).toList(),
    );
  }

  /// Update a paper in a list if it exists
  List<QuestionPaperEntity> _updatePaperInList(
      List<QuestionPaperEntity> list,
      QuestionPaperEntity updatedPaper,
      ) {
    return list.map((p) => p.id == updatedPaper.id ? updatedPaper : p).toList();
  }
}