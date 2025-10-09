import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/usecases/get_user_notifications_usecase.dart';
import '../../domain/usecases/get_unread_count_usecase.dart';
import '../../domain/usecases/mark_notification_read_usecase.dart';
import '../../../../core/domain/interfaces/i_logger.dart';

// Events
abstract class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

class LoadNotifications extends NotificationEvent {
  final String userId;

  const LoadNotifications(this.userId);

  @override
  List<Object?> get props => [userId];
}

class LoadUnreadCount extends NotificationEvent {
  final String userId;

  const LoadUnreadCount(this.userId);

  @override
  List<Object?> get props => [userId];
}

class MarkNotificationAsRead extends NotificationEvent {
  final String notificationId;

  const MarkNotificationAsRead(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

class RefreshNotifications extends NotificationEvent {
  final String userId;

  const RefreshNotifications(this.userId);

  @override
  List<Object?> get props => [userId];
}

// States
abstract class NotificationState extends Equatable {
  const NotificationState();

  @override
  List<Object?> get props => [];
}

class NotificationInitial extends NotificationState {}

class NotificationLoading extends NotificationState {}

class NotificationLoaded extends NotificationState {
  final List<NotificationEntity> notifications;
  final int unreadCount;

  const NotificationLoaded({
    required this.notifications,
    required this.unreadCount,
  });

  @override
  List<Object?> get props => [notifications, unreadCount];

  NotificationLoaded copyWith({
    List<NotificationEntity>? notifications,
    int? unreadCount,
  }) {
    return NotificationLoaded(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class NotificationError extends NotificationState {
  final String message;

  const NotificationError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final GetUserNotificationsUseCase getUserNotificationsUseCase;
  final GetUnreadCountUseCase getUnreadCountUseCase;
  final MarkNotificationReadUseCase markNotificationReadUseCase;
  final ILogger logger;

  NotificationBloc({
    required this.getUserNotificationsUseCase,
    required this.getUnreadCountUseCase,
    required this.markNotificationReadUseCase,
    required this.logger,
  }) : super(NotificationInitial()) {
    on<LoadNotifications>(_onLoadNotifications);
    on<LoadUnreadCount>(_onLoadUnreadCount);
    on<MarkNotificationAsRead>(_onMarkAsRead);
    on<RefreshNotifications>(_onRefreshNotifications);
  }

  Future<void> _onLoadNotifications(
    LoadNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    emit(NotificationLoading());

    final notificationsResult = await getUserNotificationsUseCase(event.userId);
    final countResult = await getUnreadCountUseCase(event.userId);

    notificationsResult.fold(
      (failure) => emit(NotificationError(failure.message)),
      (notifications) {
        countResult.fold(
          (failure) => emit(NotificationLoaded(
            notifications: notifications,
            unreadCount: 0,
          )),
          (count) => emit(NotificationLoaded(
            notifications: notifications,
            unreadCount: count,
          )),
        );
      },
    );
  }

  Future<void> _onLoadUnreadCount(
    LoadUnreadCount event,
    Emitter<NotificationState> emit,
  ) async {
    final currentState = state;

    final countResult = await getUnreadCountUseCase(event.userId);

    countResult.fold(
      (failure) {
        logger.warning('Failed to load unread count',
          category: LogCategory.system,
          context: {'error': failure.message}
        );
      },
      (count) {
        if (currentState is NotificationLoaded) {
          emit(currentState.copyWith(unreadCount: count));
        }
      },
    );
  }

  Future<void> _onMarkAsRead(
    MarkNotificationAsRead event,
    Emitter<NotificationState> emit,
  ) async {
    final currentState = state;

    final result = await markNotificationReadUseCase(event.notificationId);

    result.fold(
      (failure) {
        logger.error('Failed to mark notification as read',
          category: LogCategory.system,
          context: {'error': failure.message, 'notificationId': event.notificationId}
        );
      },
      (updatedNotification) {
        if (currentState is NotificationLoaded) {
          final updatedNotifications = currentState.notifications.map((n) {
            return n.id == event.notificationId ? updatedNotification : n;
          }).toList();

          final newUnreadCount = updatedNotifications.where((n) => !n.isRead).length;

          emit(currentState.copyWith(
            notifications: updatedNotifications,
            unreadCount: newUnreadCount,
          ));
        }
      },
    );
  }

  Future<void> _onRefreshNotifications(
    RefreshNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    final notificationsResult = await getUserNotificationsUseCase(event.userId);
    final countResult = await getUnreadCountUseCase(event.userId);

    notificationsResult.fold(
      (failure) {
        logger.warning('Failed to refresh notifications',
          category: LogCategory.system,
          context: {'error': failure.message}
        );
      },
      (notifications) {
        countResult.fold(
          (failure) {
            if (state is NotificationLoaded) {
              emit((state as NotificationLoaded).copyWith(
                notifications: notifications,
              ));
            }
          },
          (count) {
            if (state is NotificationLoaded) {
              emit((state as NotificationLoaded).copyWith(
                notifications: notifications,
                unreadCount: count,
              ));
            } else {
              emit(NotificationLoaded(
                notifications: notifications,
                unreadCount: count,
              ));
            }
          },
        );
      },
    );
  }
}
