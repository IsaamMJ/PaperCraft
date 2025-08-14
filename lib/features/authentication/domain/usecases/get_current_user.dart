// domain/usecases/get_current_user.dart
import '../../../../core/services/logger.dart';
import '../repositories/auth_repository.dart';
import '../entities/user_entity.dart';

class GetCurrentUser {
  final AuthRepository repository;

  GetCurrentUser(this.repository);

  Future<UserEntity?> call() async {
    try {
      LoggingService.debug('GetCurrentUser called');
      final user = await repository.getCurrentUser();
      LoggingService.debug('GetCurrentUser result: ${user?.id}');
      return user;
    } catch (e, stackTrace) {
      LoggingService.error('GetCurrentUser error: $e', e, stackTrace);
      return null;
    }
  }
}