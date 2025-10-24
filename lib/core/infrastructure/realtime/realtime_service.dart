// core/infrastructure/realtime/realtime_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/interfaces/i_logger.dart';

/// Service to manage Supabase Realtime subscriptions
/// Provides type-safe channel management and automatic cleanup
///
/// IMPORTANT: Always call dispose() when done to prevent memory leaks!
/// Example in StatefulWidget:
/// ```dart
/// @override
/// void dispose() {
///   _realtimeService.dispose();
///   super.dispose();
/// }
/// ```
class RealtimeService {
  final SupabaseClient _supabase;
  final ILogger _logger;
  final Map<String, RealtimeChannel> _activeChannels = {};
  bool _isDisposed = false;

  RealtimeService(this._supabase, this._logger);

  /// Check if service has been disposed
  bool get isDisposed => _isDisposed;

  /// Throw if service is used after disposal
  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('RealtimeService has been disposed and cannot be used');
    }
  }

  /// Subscribe to table changes with filters
  /// Returns channel ID for later unsubscription
  String subscribeToTable({
    required String table,
    required String channelName,
    required void Function(Map<String, dynamic> payload) onInsert,
    void Function(Map<String, dynamic> payload)? onUpdate,
    void Function(Map<String, dynamic> payload)? onDelete,
    String? filter,
  }) {
    // OPTIMIZATION: Check if service is disposed to prevent memory leaks
    _checkDisposed();

    try {
      // Remove existing channel if any (prevent duplicate subscriptions)
      if (_activeChannels.containsKey(channelName)) {
        _logger.warning('Channel already exists, removing old one',
            category: LogCategory.system, context: {'channelName': channelName});
        unsubscribeSync(channelName);
      }

      _logger.info('Creating realtime subscription',
          category: LogCategory.system,
          context: {
            'table': table,
            'channelName': channelName,
            'filter': filter,
          });

      // Create channel
      final channel = _supabase.channel(channelName);

      // Build the postgres changes filter if provided
      PostgresChangeFilter? changeFilter;
      if (filter != null) {
        // Parse filter string (e.g., "status=eq.approved")
        final parts = filter.split('=');
        if (parts.length == 2) {
          final column = parts[0];
          final valueParts = parts[1].split('.');
          if (valueParts.length == 2) {
            changeFilter = PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: column,
              value: valueParts[1],
            );
          }
        }
      }

      // OPTIMIZATION: Wrap callbacks with error handling to prevent crashes
      // If callback throws, log error but keep subscription alive
      void safeOnInsert(PostgresChangePayload payload) {
        try {
          onInsert(payload.newRecord);
        } catch (e, stackTrace) {
          _logger.error('Error in realtime INSERT callback',
              category: LogCategory.system,
              error: e,
              stackTrace: stackTrace,
              context: {'table': table, 'channel': channelName});
        }
      }

      void safeOnUpdate(PostgresChangePayload payload) {
        try {
          onUpdate!(payload.newRecord);
        } catch (e, stackTrace) {
          _logger.error('Error in realtime UPDATE callback',
              category: LogCategory.system,
              error: e,
              stackTrace: stackTrace,
              context: {'table': table, 'channel': channelName});
        }
      }

      void safeOnDelete(PostgresChangePayload payload) {
        try {
          onDelete!(payload.oldRecord);
        } catch (e, stackTrace) {
          _logger.error('Error in realtime DELETE callback',
              category: LogCategory.system,
              error: e,
              stackTrace: stackTrace,
              context: {'table': table, 'channel': channelName});
        }
      }

      // Subscribe to changes with error-safe callbacks
      channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: table,
        filter: changeFilter,
        callback: (payload) {
          _logger.debug('Realtime INSERT event',
              category: LogCategory.system,
              context: {
                'table': table,
                'channel': channelName,
              });
          safeOnInsert(payload);
        },
      );

      if (onUpdate != null) {
        channel.onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: table,
          filter: changeFilter,
          callback: (payload) {
            _logger.debug('Realtime UPDATE event',
                category: LogCategory.system,
                context: {
                  'table': table,
                  'channel': channelName,
                });
            safeOnUpdate(payload);
          },
        );
      }

      if (onDelete != null) {
        channel.onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: table,
          filter: changeFilter,
          callback: (payload) {
            _logger.debug('Realtime DELETE event',
                category: LogCategory.system,
                context: {
                  'table': table,
                  'channel': channelName,
                });
            safeOnDelete(payload);
          },
        );
      }

      // Subscribe to the channel
      channel.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          _logger.info('Realtime subscription active',
              category: LogCategory.system,
              context: {'channelName': channelName});
        } else if (status == RealtimeSubscribeStatus.closed) {
          _logger.warning('Realtime subscription closed',
              category: LogCategory.system,
              context: {'channelName': channelName, 'error': error?.toString()});
        } else if (status == RealtimeSubscribeStatus.channelError) {
          _logger.error('Realtime subscription error',
              category: LogCategory.system,
              error: error,
              context: {'channelName': channelName});
        }
      });

      _activeChannels[channelName] = channel;

      return channelName;
    } catch (e, stackTrace) {
      _logger.error('Failed to create realtime subscription',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace,
          context: {'table': table, 'channelName': channelName});
      rethrow;
    }
  }

  /// Synchronous unsubscribe (for use during cleanup)
  /// Should be called during initialization to avoid race conditions
  void unsubscribeSync(String channelName) {
    try {
      final channel = _activeChannels[channelName];
      if (channel != null) {
        _logger.debug('Synchronously removing realtime channel',
            category: LogCategory.system,
            context: {'channelName': channelName});
        _activeChannels.remove(channelName);
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to synchronously remove channel',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace,
          context: {'channelName': channelName});
    }
  }

  /// Unsubscribe from a channel asynchronously
  Future<void> unsubscribe(String channelName) async {
    if (_isDisposed) {
      _logger.warning('Attempted to unsubscribe after disposal',
          category: LogCategory.system,
          context: {'channelName': channelName});
      return;
    }

    try {
      final channel = _activeChannels[channelName];
      if (channel != null) {
        _logger.info('Unsubscribing from realtime channel',
            category: LogCategory.system,
            context: {'channelName': channelName});

        await _supabase.removeChannel(channel);
        _activeChannels.remove(channelName);
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to unsubscribe from channel',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace,
          context: {'channelName': channelName});
    }
  }

  /// Unsubscribe from all active channels
  Future<void> unsubscribeAll() async {
    if (_isDisposed) {
      _logger.warning('Attempted to unsubscribe all after disposal',
          category: LogCategory.system);
      return;
    }

    _logger.info('Unsubscribing from all realtime channels',
        category: LogCategory.system,
        context: {'activeChannels': _activeChannels.length});

    final channels = List<String>.from(_activeChannels.keys);
    for (final channelName in channels) {
      await unsubscribe(channelName);
    }
  }

  /// Get list of active channel names
  List<String> getActiveChannels() {
    return List<String>.from(_activeChannels.keys);
  }

  /// Check if a specific channel is active
  bool isChannelActive(String channelName) {
    return _activeChannels.containsKey(channelName);
  }

  /// Dispose and cleanup all subscriptions
  /// IMPORTANT: Call this in StatefulWidget.dispose() to prevent memory leaks
  /// Example:
  /// ```dart
  /// @override
  /// void dispose() {
  ///   _realtimeService.dispose();
  ///   super.dispose();
  /// }
  /// ```
  Future<void> dispose() async {
    if (_isDisposed) {
      _logger.debug('RealtimeService already disposed',
          category: LogCategory.system);
      return;
    }

    _logger.info('Disposing RealtimeService',
        category: LogCategory.system,
        context: {'activeChannels': _activeChannels.length});

    // Mark as disposed FIRST to prevent new subscriptions during cleanup
    _isDisposed = true;

    // Then cleanup all channels
    await unsubscribeAll();
  }
}
