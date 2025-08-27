import '../entities/user_permissions_entity.dart';
import '../repositories/qps_repository.dart';

class GetUserPermissions {
  final QpsRepository repository;
  GetUserPermissions(this.repository);

  Future<UserPermissionsEntity?> call() async {
    return await repository.getUserPermissions();
  }
}