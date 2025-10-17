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

/// Enable realtime subscriptions for live updates
class EnableRealtimeUpdates extends HomeEvent {
  final bool isAdmin;
  final String? userId;

  const EnableRealtimeUpdates({
    required this.isAdmin,
    this.userId,
  });

  @override
  List<Object?> get props => [isAdmin, userId];
}

/// Disable realtime subscriptions
class DisableRealtimeUpdates extends HomeEvent {
  const DisableRealtimeUpdates();
}

/// Handle realtime paper update from subscription
class PaperRealtimeUpdate extends HomeEvent {
  final Map<String, dynamic> paperData;
  final String eventType; // 'INSERT', 'UPDATE', 'DELETE'

  const PaperRealtimeUpdate({
    required this.paperData,
    required this.eventType,
  });

  @override
  List<Object?> get props => [paperData, eventType];
}
