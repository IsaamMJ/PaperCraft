import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/notification_entity.dart';
import '../repositories/i_notification_repository.dart';

class GetUserNotificationsUseCase {
  final INotificationRepository _repository;

  GetUserNotificationsUseCase(this._repository);

  Future<Either<Failure, List<NotificationEntity>>> call(String userId) {
    return _repository.getUserNotifications(userId);
  }
}
