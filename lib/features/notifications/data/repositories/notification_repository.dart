import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/i_notification_repository.dart';
import '../datasources/notification_data_source.dart';
import '../models/notification_model.dart';

class NotificationRepository implements INotificationRepository {
  final NotificationDataSource _dataSource;
  final ILogger _logger;
  final Uuid _uuid = const Uuid();

  NotificationRepository(this._dataSource, this._logger);

  @override
  Future<Either<Failure, NotificationEntity>> createNotification({
    required String userId,
    required String tenantId,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notification = NotificationModel(
        id: _uuid.v4(),
        userId: userId,
        tenantId: tenantId,
        type: NotificationType.fromString(type),
        title: title,
        message: message,
        data: data,
        isRead: false,
        createdAt: DateTime.now(),
      );

      final result = await _dataSource.createNotification(notification);
      return Right(result.toEntity());
    } catch (e) {
      _logger.error('Failed to create notification',
          category: LogCategory.system,
          error: e);
      return Left(ServerFailure('Failed to create notification: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<NotificationEntity>>> getUserNotifications(String userId) async {
    try {
      final notifications = await _dataSource.getUserNotifications(userId);
      return Right(notifications.map((n) => n.toEntity()).toList());
    } catch (e) {
      _logger.error('Failed to get user notifications',
          category: LogCategory.system,
          error: e);
      return Left(ServerFailure('Failed to get notifications: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<NotificationEntity>>> getUnreadNotifications(String userId) async {
    try {
      final notifications = await _dataSource.getUnreadNotifications(userId);
      return Right(notifications.map((n) => n.toEntity()).toList());
    } catch (e) {
      _logger.error('Failed to get unread notifications',
          category: LogCategory.system,
          error: e);
      return Left(ServerFailure('Failed to get unread notifications: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, NotificationEntity>> markAsRead(String notificationId) async {
    try {
      final notification = await _dataSource.markAsRead(notificationId);
      return Right(notification.toEntity());
    } catch (e) {
      _logger.error('Failed to mark notification as read',
          category: LogCategory.system,
          error: e);
      return Left(ServerFailure('Failed to mark as read: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Unit>> markAllAsRead(String userId) async {
    try {
      await _dataSource.markAllAsRead(userId);
      return const Right(unit);
    } catch (e) {
      _logger.error('Failed to mark all notifications as read',
          category: LogCategory.system,
          error: e);
      return Left(ServerFailure('Failed to mark all as read: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, int>> getUnreadCount(String userId) async {
    try {
      final count = await _dataSource.getUnreadCount(userId);
      return Right(count);
    } catch (e) {
      _logger.error('Failed to get unread count',
          category: LogCategory.system,
          error: e);
      return Left(ServerFailure('Failed to get unread count: ${e.toString()}'));
    }
  }
}
