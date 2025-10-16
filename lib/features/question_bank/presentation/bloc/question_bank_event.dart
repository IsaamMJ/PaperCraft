// features/question_bank/presentation/bloc/question_bank_event.dart
import 'package:equatable/equatable.dart';

abstract class QuestionBankEvent extends Equatable {
  const QuestionBankEvent();

  @override
  List<Object?> get props => [];
}

/// Load paginated approved papers for question bank
class LoadQuestionBankPaginated extends QuestionBankEvent {
  final int page;
  final int pageSize;
  final String? searchQuery;
  final String? subjectFilter;
  final String? gradeFilter;
  final bool isLoadMore;

  const LoadQuestionBankPaginated({
    required this.page,
    required this.pageSize,
    this.searchQuery,
    this.subjectFilter,
    this.gradeFilter,
    this.isLoadMore = false,
  });

  @override
  List<Object?> get props => [
    page,
    pageSize,
    searchQuery,
    subjectFilter,
    gradeFilter,
    isLoadMore,
  ];
}

/// Refresh question bank (pull-to-refresh)
class RefreshQuestionBank extends QuestionBankEvent {
  final int pageSize;
  final String? searchQuery;
  final String? subjectFilter;
  final String? gradeFilter;

  const RefreshQuestionBank({
    required this.pageSize,
    this.searchQuery,
    this.subjectFilter,
    this.gradeFilter,
  });

  @override
  List<Object?> get props => [
    pageSize,
    searchQuery,
    subjectFilter,
    gradeFilter,
  ];
}
