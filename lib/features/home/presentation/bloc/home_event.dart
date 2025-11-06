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

/// Load teacher's assigned classes (grades and sections)
class LoadTeacherClasses extends HomeEvent {
  final String userId;
  final String tenantId;

  const LoadTeacherClasses({
    required this.userId,
    required this.tenantId,
  });

  @override
  List<Object?> get props => [userId, tenantId];
}

/// Type-safe enum for realtime event types
enum RealtimeEventType {
  insert,
  update,
  delete;

  /// Convert from string (for backward compatibility with Supabase callbacks)
  static RealtimeEventType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'INSERT':
        return RealtimeEventType.insert;
      case 'UPDATE':
        return RealtimeEventType.update;
      case 'DELETE':
        return RealtimeEventType.delete;
      default:
        throw ArgumentError('Invalid realtime event type: $value');
    }
  }

  /// Convert to string
  String get value {
    switch (this) {
      case RealtimeEventType.insert:
        return 'INSERT';
      case RealtimeEventType.update:
        return 'UPDATE';
      case RealtimeEventType.delete:
        return 'DELETE';
    }
  }
}

/// Handle realtime paper update from subscription
class PaperRealtimeUpdate extends HomeEvent {
  final Map<String, dynamic> paperData;
  final RealtimeEventType eventType;

  const PaperRealtimeUpdate({
    required this.paperData,
    required this.eventType,
  });

  @override
  List<Object?> get props => [paperData, eventType];
}