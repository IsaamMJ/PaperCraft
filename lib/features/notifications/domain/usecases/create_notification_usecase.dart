import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/notification_entity.dart';
import '../repositories/i_notification_repository.dart';

class CreateNotificationUseCase {
  final INotificationRepository _repository;

  CreateNotificationUseCase(this._repository);

  Future<Either<Failure, NotificationEntity>> call({
    required String userId,
    required String tenantId,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) {
    return _repository.createNotification(
      userId: userId,
      tenantId: tenantId,
      type: type,
      title: title,
      message: message,
      data: data,
    );
  }
}
