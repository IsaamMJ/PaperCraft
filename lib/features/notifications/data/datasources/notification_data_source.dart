import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/network/api_client.dart';
import '../../../../core/infrastructure/network/models/api_response.dart';
import '../models/notification_model.dart';

abstract class NotificationDataSource {
  Future<NotificationModel> createNotification(NotificationModel notification);
  Future<List<NotificationModel>> getUserNotifications(String userId);
  Future<List<NotificationModel>> getUnreadNotifications(String userId);
  Future<NotificationModel> markAsRead(String notificationId);
  Future<void> markAllAsRead(String userId);
  Future<int> getUnreadCount(String userId);
}

class NotificationDataSourceImpl implements NotificationDataSource {
  final ApiClient _apiClient;
  final ILogger _logger;
  static const String _tableName = 'notifications';

  NotificationDataSourceImpl(this._apiClient, this._logger);

  @override
  Future<NotificationModel> createNotification(NotificationModel notification) async {
    try {
      _logger.info('Creating notification', category: LogCategory.system, context: {
        'userId': notification.userId,
        'type': notification.type.value,
      });

      final response = await _apiClient.insert<NotificationModel>(
        table: _tableName,
        data: notification.toSupabase(),
        fromJson: NotificationModel.fromSupabase,
      );

      if (response.isSuccess) {
        _logger.info('Notification created', category: LogCategory.system, context: {
          'notificationId': response.data!.id,
        });
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Failed to create notification');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to create notification',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<NotificationModel>> getUserNotifications(String userId) async {
    try {
      final response = await _apiClient.select<NotificationModel>(
        table: _tableName,
        fromJson: NotificationModel.fromSupabase,
        filters: {'user_id': userId},
        orderBy: 'created_at',
        ascending: false,
      );

      if (response.isSuccess) {
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Failed to get notifications');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to get user notifications',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<NotificationModel>> getUnreadNotifications(String userId) async {
    try {
      final response = await _apiClient.select<NotificationModel>(
        table: _tableName,
        fromJson: NotificationModel.fromSupabase,
        filters: {
          'user_id': userId,
          'is_read': false,
        },
        orderBy: 'created_at',
        ascending: false,
      );

      if (response.isSuccess) {
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Failed to get unread notifications');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to get unread notifications',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<NotificationModel> markAsRead(String notificationId) async {
    try {
      final response = await _apiClient.update<NotificationModel>(
        table: _tableName,
        data: {
          'is_read': true,
          'read_at': DateTime.now().toIso8601String(),
        },
        filters: {'id': notificationId},
        fromJson: NotificationModel.fromSupabase,
      );

      if (response.isSuccess) {
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Failed to mark notification as read');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to mark notification as read',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    try {
      await Supabase.instance.client
          .from(_tableName)
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('is_read', false);

      _logger.info('All notifications marked as read', category: LogCategory.system, context: {
        'userId': userId,
      });
    } catch (e, stackTrace) {
      _logger.error('Failed to mark all notifications as read',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .eq('is_read', false)
          .count();

      return response.count;
    } catch (e, stackTrace) {
      _logger.error('Failed to get unread count',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }
}
