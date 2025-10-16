// features/home/presentation/bloc/home_event.dart
import 'package:equatable/equatable.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

/// Load all papers for home page (drafts, submissions, reviews, admin papers)
class LoadHomePapers extends HomeEvent {
  final bool isAdmin;
  final String? userId;

  const LoadHomePapers({
    required this.isAdmin,
    this.userId,
  });

  @override
  List<Object?> get props => [isAdmin, userId];
}

/// Refresh home page data (pull-to-refresh)
class RefreshHomePapers extends HomeEvent {
  final bool isAdmin;
  final String? userId;

  const RefreshHomePapers({
    required this.isAdmin,
    this.userId,
  });

  @override
  List<Object?> get props => [isAdmin, userId];
}
