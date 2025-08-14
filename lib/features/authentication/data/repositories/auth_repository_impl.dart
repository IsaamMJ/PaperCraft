import '../../domain/entities/auth_session_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl(this.remoteDataSource);

  @override
  Future<(UserEntity, AuthSessionEntity)> signInWithGoogle() async {
    try {
      final (userModel, sessionModel) = await remoteDataSource.signInWithGoogle();
      return (userModel, sessionModel);
    } catch (e) {
      // Transform data layer exceptions to domain exceptions if needed
      rethrow;
    }
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    return await remoteDataSource.getCurrentUser();
  }

  @override
  Future<void> signOut() async {
    await remoteDataSource.signOut();
  }
}