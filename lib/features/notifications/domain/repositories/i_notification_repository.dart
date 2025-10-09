import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/notification_entity.dart';

abstract class INotificationRepository {
  Future<Either<Failure, NotificationEntity>> createNotification({
    required String userId,
    required String tenantId,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  });

  Future<Either<Failure, List<NotificationEntity>>> getUserNotifications(String userId);
  Future<Either<Failure, List<NotificationEntity>>> getUnreadNotifications(String userId);
  Future<Either<Failure, NotificationEntity>> markAsRead(String notificationId);
  Future<Either<Failure, Unit>> markAllAsRead(String userId);
  Future<Either<Failure, int>> getUnreadCount(String userId);
}
