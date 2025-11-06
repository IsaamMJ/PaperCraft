// features/home/presentation/bloc/home_state.dart
import 'package:equatable/equatable.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';
import '../../../catalog/domain/entities/teacher_class.dart';

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class HomeInitial extends HomeState {
  const HomeInitial();
}

/// Loading home page data
class HomeLoading extends HomeState {
  final String? message;

  const HomeLoading({this.message});

  @override
  List<Object?> get props => [message];
}

/// Home page data loaded successfully
class HomeLoaded extends HomeState {
  final List<QuestionPaperEntity> drafts;
  final List<QuestionPaperEntity> submissions;
  final List<QuestionPaperEntity> papersForReview;
  final List<QuestionPaperEntity> allPapersForAdmin;
  final List<QuestionPaperEntity> approvedPapers;
  final List<TeacherClass> teacherClasses;

  const HomeLoaded({
    this.drafts = const [],
    this.submissions = const [],
    this.papersForReview = const [],
    this.allPapersForAdmin = const [],
    this.approvedPapers = const [],
    this.teacherClasses = const [],
  });

  HomeLoaded copyWith({
    List<QuestionPaperEntity>? drafts,
    List<QuestionPaperEntity>? submissions,
    List<QuestionPaperEntity>? papersForReview,
    List<QuestionPaperEntity>? allPapersForAdmin,
    List<QuestionPaperEntity>? approvedPapers,
    List<TeacherClass>? teacherClasses,
  }) {
    return HomeLoaded(
      drafts: drafts ?? this.drafts,
      submissions: submissions ?? this.submissions,
      papersForReview: papersForReview ?? this.papersForReview,
      allPapersForAdmin: allPapersForAdmin ?? this.allPapersForAdmin,
      approvedPapers: approvedPapers ?? this.approvedPapers,
      teacherClasses: teacherClasses ?? this.teacherClasses,
    );
  }

  @override
  List<Object?> get props => [
    drafts,
    submissions,
    papersForReview,
    allPapersForAdmin,
    approvedPapers,
    teacherClasses,
  ];
}

/// Error loading home page data
class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);

  @override
  List<Object?> get props => [message];
}
