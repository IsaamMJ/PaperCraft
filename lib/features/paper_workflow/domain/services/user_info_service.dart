// features/question_papers/domain/services/user_info_service.dart
import 'dart:async';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../authentication/domain/usecases/auth_usecase.dart';

/// Service for fetching and caching user information by ID
/// Provides fast lookup of user full names with smart caching
class UserInfoService {
  final ILogger _logger;
  final AuthUseCase _authUseCase;

  // Cache user info for 30 minutes
  final Map<String, _UserCacheEntry> _userCache = {};
  final Duration _cacheTimeout = const Duration(minutes: 30);

  UserInfoService(this._logger, this._authUseCase);

  /// Get user full name by ID with caching
  Future<String> getUserFullName(String userId) async {
    try {
      // Check current user first (no API call needed)
      final currentUser = sl<UserStateService>().currentUser;
      if (currentUser?.id == userId) {
        return currentUser!.fullName.isNotEmpty ? currentUser.fullName : currentUser.email;
      }

      // Check cache
      final cached = _userCache[userId];
      if (cached != null && !cached.isExpired) {
        _logger.debug('User info cache hit', context: {
          'userId': userId,
          'fullName': cached.fullName,
          'cacheAge': DateTime.now().difference(cached.cachedAt).inMinutes,
        });
        return cached.fullName;
      }

      // Fetch from API
      _logger.debug('Fetching user info from API', context: {'userId': userId});

      final result = await _authUseCase.getUserById(userId);

      return result.fold(
            (failure) {
          _logger.warning('Failed to fetch user info', context: {
            'userId': userId,
            'error': failure.message,
          });

          // Return cached value even if expired, or fallback
          if (cached != null) {
            _logger.debug('Using expired cache as fallback', context: {
              'userId': userId,
              'expiredBy': DateTime.now().difference(cached.cachedAt).inMinutes - _cacheTimeout.inMinutes,
            });
            return cached.fullName;
          }

          return 'User'; // Fallback to generic User text
        },
            (user) {
          if (user != null) {
            final fullName = user.fullName.isNotEmpty ? user.fullName : user.email;

            // Cache the result
            _userCache[userId] = _UserCacheEntry(
              fullName: fullName,
              email: user.email,
              cachedAt: DateTime.now(),
            );

            _logger.debug('User info cached', context: {
              'userId': userId,
              'fullName': fullName,
              'cacheSize': _userCache.length,
            });

            return fullName;
          } else {
            _logger.warning('User not found', context: {'userId': userId});
            return 'User';
          }
        },
      );
    } catch (e) {
      _logger.warning('Exception fetching user info', context: {
        'userId': userId,
        'error': e.toString(),
      });

      // Try cache as fallback
      final cached = _userCache[userId];
      if (cached != null) {
        return cached.fullName;
      }

      return 'User';
    }
  }

  /// Preload multiple user names (batch operation)
  Future<Map<String, String>> getUserFullNames(List<String> userIds) async {
    final result = <String, String>{};
    final toFetch = <String>[];

    // Check cache and current user first
    final currentUser = sl<UserStateService>().currentUser;

    for (final userId in userIds) {
      if (currentUser?.id == userId) {
        result[userId] = currentUser!.fullName.isNotEmpty
            ? currentUser.fullName
            : currentUser.email;
      } else {
        final cached = _userCache[userId];
        if (cached != null && !cached.isExpired) {
          result[userId] = cached.fullName;
        } else {
          toFetch.add(userId);
        }
      }
    }

    // Fetch remaining users
    if (toFetch.isNotEmpty) {
      _logger.debug('Batch fetching user info', context: {
        'userCount': toFetch.length,
        'cacheHits': result.length,
      });

      // Fetch in parallel with limit to avoid overwhelming the API
      final futures = toFetch.take(10).map((userId) => getUserFullName(userId));
      final names = await Future.wait(futures);

      for (int i = 0; i < toFetch.length && i < names.length; i++) {
        result[toFetch[i]] = names[i];
      }
    }

    return result;
  }

  /// Clear expired cache entries
  void cleanupCache() {
    final now = DateTime.now();
    final expiredKeys = _userCache.entries
        .where((entry) => now.difference(entry.value.cachedAt) > _cacheTimeout)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _userCache.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      _logger.debug('Cleaned up expired user cache', context: {
        'removedEntries': expiredKeys.length,
        'remainingEntries': _userCache.length,
      });
    }
  }

  /// Clear all cache
  void clearCache() {
    final size = _userCache.length;
    _userCache.clear();
    _logger.debug('User cache cleared', context: {'clearedEntries': size});
  }

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    final now = DateTime.now();
    int validEntries = 0;
    int expiredEntries = 0;

    for (final entry in _userCache.values) {
      if (now.difference(entry.cachedAt) <= _cacheTimeout) {
        validEntries++;
      } else {
        expiredEntries++;
      }
    }

    return {
      'totalEntries': _userCache.length,
      'validEntries': validEntries,
      'expiredEntries': expiredEntries,
      'cacheTimeoutMinutes': _cacheTimeout.inMinutes,
    };
  }
}

/// Cache entry for user information
class _UserCacheEntry {
  final String fullName;
  final String email;
  final DateTime cachedAt;

  _UserCacheEntry({
    required this.fullName,
    required this.email,
    required this.cachedAt,
  });

  bool get isExpired => DateTime.now().difference(cachedAt) > const Duration(minutes: 30);
}