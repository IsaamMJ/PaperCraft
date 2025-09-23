import 'user_entity.dart';

class AuthResultEntity {
  final UserEntity user;
  final bool isFirstLogin;

  const AuthResultEntity({
    required this.user,
    required this.isFirstLogin,
  });
}