// features/question_bank/presentation/bloc/question_bank_state.dart
import 'package:equatable/equatable.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';

abstract class QuestionBankState extends Equatable {
  const QuestionBankState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class QuestionBankInitial extends QuestionBankState {
  const QuestionBankInitial();
}

/// Loading question bank data
class QuestionBankLoading extends QuestionBankState {
  final String? message;

  const QuestionBankLoading({this.message});

  @override
  List<Object?> get props => [message];
}

/// Question bank paginated data loaded
class QuestionBankLoaded extends QuestionBankState {
  final List<QuestionPaperEntity> papers;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final bool hasMore;
  final bool isLoadingMore;
  final String? searchQuery;
  final String? subjectFilter;
  final String? gradeFilter;

  // Pre-computed filtered and grouped data for performance
  final Map<String, List<QuestionPaperEntity>> thisMonthGroupedByClass;
  final Map<String, List<QuestionPaperEntity>> thisMonthGroupedByMonth;
  final Map<String, List<QuestionPaperEntity>> previousMonthGroupedByClass;
  final Map<String, List<QuestionPaperEntity>> previousMonthGroupedByMonth;
  final Map<String, List<QuestionPaperEntity>> archiveGroupedByClass;
  final Map<String, List<QuestionPaperEntity>> archiveGroupedByMonth;

  const QuestionBankLoaded({
    required this.papers,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.hasMore,
    this.isLoadingMore = false,
    this.searchQuery,
    this.subjectFilter,
    this.gradeFilter,
    required this.thisMonthGroupedByClass,
    required this.thisMonthGroupedByMonth,
    required this.previousMonthGroupedByClass,
    required this.previousMonthGroupedByMonth,
    required this.archiveGroupedByClass,
    required this.archiveGroupedByMonth,
  });

  QuestionBankLoaded copyWith({
    List<QuestionPaperEntity>? papers,
    int? currentPage,
    int? totalPages,
    int? totalItems,
    bool? hasMore,
    bool? isLoadingMore,
    String? searchQuery,
    String? subjectFilter,
    String? gradeFilter,
    Map<String, List<QuestionPaperEntity>>? thisMonthGroupedByClass,
    Map<String, List<QuestionPaperEntity>>? thisMonthGroupedByMonth,
    Map<String, List<QuestionPaperEntity>>? previousMonthGroupedByClass,
    Map<String, List<QuestionPaperEntity>>? previousMonthGroupedByMonth,
    Map<String, List<QuestionPaperEntity>>? archiveGroupedByClass,
    Map<String, List<QuestionPaperEntity>>? archiveGroupedByMonth,
  }) {
    return QuestionBankLoaded(
      papers: papers ?? this.papers,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalItems: totalItems ?? this.totalItems,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      searchQuery: searchQuery ?? this.searchQuery,
      subjectFilter: subjectFilter ?? this.subjectFilter,
      gradeFilter: gradeFilter ?? this.gradeFilter,
      thisMonthGroupedByClass: thisMonthGroupedByClass ?? this.thisMonthGroupedByClass,
      thisMonthGroupedByMonth: thisMonthGroupedByMonth ?? this.thisMonthGroupedByMonth,
      previousMonthGroupedByClass: previousMonthGroupedByClass ?? this.previousMonthGroupedByClass,
      previousMonthGroupedByMonth: previousMonthGroupedByMonth ?? this.previousMonthGroupedByMonth,
      archiveGroupedByClass: archiveGroupedByClass ?? this.archiveGroupedByClass,
      archiveGroupedByMonth: archiveGroupedByMonth ?? this.archiveGroupedByMonth,
    );
  }

  @override
  List<Object?> get props => [
    papers,
    currentPage,
    totalPages,
    totalItems,
    hasMore,
    isLoadingMore,
    searchQuery,
    subjectFilter,
    gradeFilter,
    thisMonthGroupedByClass,
    thisMonthGroupedByMonth,
    previousMonthGroupedByClass,
    previousMonthGroupedByMonth,
    archiveGroupedByClass,
    archiveGroupedByMonth,
  ];
}

/// Error loading question bank
class QuestionBankError extends QuestionBankState {
  final String message;

  const QuestionBankError(this.message);

  @override
  List<Object?> get props => [message];
}
