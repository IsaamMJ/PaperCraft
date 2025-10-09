import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/notification_entity.dart';
import '../repositories/i_notification_repository.dart';

class MarkNotificationReadUseCase {
  final INotificationRepository _repository;

  MarkNotificationReadUseCase(this._repository);

  Future<Either<Failure, NotificationEntity>> call(String notificationId) {
    return _repository.markAsRead(notificationId);
  }
}
