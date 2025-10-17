// core/infrastructure/realtime/realtime_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/interfaces/i_logger.dart';

/// Service to manage Supabase Realtime subscriptions
/// Provides type-safe channel management and automatic cleanup
class RealtimeService {
  final SupabaseClient _supabase;
  final ILogger _logger;
  final Map<String, RealtimeChannel> _activeChannels = {};

  RealtimeService(this._supabase, this._logger);

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
    try {
      // Remove existing channel if any
      if (_activeChannels.containsKey(channelName)) {
        _logger.warning('Channel already exists, removing old one',
            category: LogCategory.system, context: {'channelName': channelName});
        unsubscribe(channelName);
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

      // Subscribe to changes
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
          onInsert(payload.newRecord);
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
            onUpdate(payload.newRecord);
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
            onDelete(payload.oldRecord);
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

  /// Unsubscribe from a channel
  Future<void> unsubscribe(String channelName) async {
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
  Future<void> dispose() async {
    await unsubscribeAll();
  }
}
