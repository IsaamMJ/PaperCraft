// core/infrastructure/cache/cache_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Cache entry with TTL (time to live)
class CacheEntry<T> {
  final T data;
  final DateTime createdAt;
  final Duration ttl;

  CacheEntry({
    required this.data,
    required this.ttl,
  }) : createdAt = DateTime.now();

  /// Check if entry has expired
  bool get isExpired {
    return DateTime.now().difference(createdAt) > ttl;
  }
}

/// Simple in-memory cache service with TTL support
///
/// Usage:
/// ```dart
/// final cache = CacheService();
///
/// // Cache a list of papers for 5 minutes
/// cache.set('approved_papers_tenant_123', papers, duration: Duration(minutes: 5));
///
/// // Retrieve from cache
/// final cachedPapers = cache.get('approved_papers_tenant_123');
///
/// // Clear specific cache
/// cache.remove('approved_papers_tenant_123');
///
/// // Clear all cache
/// cache.clear();
/// ```
class CacheService {
  final Map<String, CacheEntry> _cache = {};
  final int _maxEntries;
  Timer? _cleanupTimer;

  CacheService({int maxEntries = 100}) : _maxEntries = maxEntries {
    // Run cleanup every minute to remove expired entries
    _startCleanupTimer();
  }

  /// Cache a value with optional TTL (default: 5 minutes)
  void set<T>(
    String key,
    T data, {
    Duration duration = const Duration(minutes: 5),
  }) {
    // OPTIMIZATION: Implement LRU eviction if cache exceeds max entries
    if (_cache.length >= _maxEntries && !_cache.containsKey(key)) {
      // Remove oldest entry (simple FIFO for now)
      final oldestKey = _cache.keys.reduce((a, b) {
        final aTime = _cache[a]!.createdAt;
        final bTime = _cache[b]!.createdAt;
        return aTime.isBefore(bTime) ? a : b;
      });
      _cache.remove(oldestKey);
    }

    _cache[key] = CacheEntry<T>(data: data, ttl: duration);
  }

  /// Retrieve a value from cache
  /// Returns null if not found or expired
  T? get<T>(String key) {
    final entry = _cache[key];

    if (entry == null) {
      return null;
    }

    // Check if expired
    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }

    return entry.data as T;
  }

  /// Check if key exists and is not expired
  bool contains(String key) {
    final entry = _cache[key];
    if (entry == null) {
      return false;
    }

    if (entry.isExpired) {
      _cache.remove(key);
      return false;
    }

    return true;
  }

  /// Remove a specific cache entry
  void remove(String key) {
    _cache.remove(key);
  }

  /// Clear all cache
  void clear() {
    _cache.clear();
  }

  /// Get cache size
  int get size => _cache.length;

  /// Start background cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _removeExpiredEntries(),
    );
  }

  /// Remove all expired entries
  void _removeExpiredEntries() {
    final expiredKeys = _cache.entries
        .where((entry) => entry.value.isExpired)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _cache.remove(key);
    }

    if (kDebugMode && expiredKeys.isNotEmpty) {
    }
  }

  /// Dispose and cleanup resources
  void dispose() {
    _cleanupTimer?.cancel();
    _cache.clear();
  }
}
