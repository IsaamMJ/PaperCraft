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
  ];
}

/// Error loading question bank
class QuestionBankError extends QuestionBankState {
  final String message;

  const QuestionBankError(this.message);

  @override
  List<Object?> get props => [message];
}
