import 'package:equatable/equatable.dart';

class AuthSessionEntity extends Equatable {
  final String accessToken;         // Supabase access token
  final String refreshToken;        // Supabase refresh token
  final DateTime expiresAt;         // Expiry time
  final String? providerAccessToken; // Google access token
  final String? providerRefreshToken;// Google refresh token

  const AuthSessionEntity({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.providerAccessToken,
    this.providerRefreshToken,
  });

  @override
  List<Object?> get props => [
    accessToken,
    refreshToken,
    expiresAt,
    providerAccessToken,
    providerRefreshToken,
  ];

  @override
  String toString() {
    return 'AuthSessionEntity(accessToken: ${_maskToken(accessToken)}, refreshToken: ${_maskToken(refreshToken)}, expiresAt: $expiresAt)';
  }

  // Helper method to mask sensitive tokens in logs
  String _maskToken(String token) {
    if (token.length <= 8) return '***';
    return '${token.substring(0, 4)}...${token.substring(token.length - 4)}';
  }

  // Check if session is expired
  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }

  // Check if session will expire soon (within 5 minutes)
  bool get willExpireSoon {
    final fiveMinutesFromNow = DateTime.now().add(const Duration(minutes: 5));
    return fiveMinutesFromNow.isAfter(expiresAt);
  }

  // Copy method for token refresh scenarios
  AuthSessionEntity copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? providerAccessToken,
    String? providerRefreshToken,
  }) {
    return AuthSessionEntity(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      providerAccessToken: providerAccessToken ?? this.providerAccessToken,
      providerRefreshToken: providerRefreshToken ?? this.providerRefreshToken,
    );
  }

  // Validation method
  bool get isValid {
    return accessToken.isNotEmpty &&
        refreshToken.isNotEmpty &&
        !isExpired;
  }
}