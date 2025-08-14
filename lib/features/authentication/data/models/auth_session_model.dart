// data/models/auth_session_model.dart
import '../../domain/entities/auth_session_entity.dart';

class AuthSessionModel extends AuthSessionEntity {
  const AuthSessionModel({
    required super.accessToken,
    required super.refreshToken,
    required super.expiresAt,
    super.providerAccessToken,
    super.providerRefreshToken,
  });

  factory AuthSessionModel.fromSupabaseSession(Map<String, dynamic> json) {
    return AuthSessionModel(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        (json['expires_at'] as int) * 1000,
      ),
      providerAccessToken: json['provider_token'] as String?,
      providerRefreshToken: json['provider_refresh_token'] as String?,
    );
  }
}
