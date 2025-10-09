import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../repositories/i_notification_repository.dart';

class GetUnreadCountUseCase {
  final INotificationRepository _repository;

  GetUnreadCountUseCase(this._repository);

  Future<Either<Failure, int>> call(String userId) {
    return _repository.getUnreadCount(userId);
  }
}
