import 'package:supabase_flutter/supabase_flutter.dart';
import '../interfaces/i_logger.dart';

class AuditLogEntry {
  final String id;
  final String userId;
  final String tenantId;
  final String action;
  final String entityType;
  final String entityId;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  AuditLogEntry({
    required this.id,
    required this.userId,
    required this.tenantId,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.metadata,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'tenant_id': tenantId,
    'action': action,
    'entity_type': entityType,
    'entity_id': entityId,
    'metadata': metadata,
    'created_at': createdAt.toIso8601String(),
  };
}

class AuditLogService {
  final SupabaseClient _client;
  final ILogger _logger;

  AuditLogService(this._client, this._logger);

  Future<void> logAction({
    required String userId,
    required String tenantId,
    required String action,
    required String entityType,
    required String entityId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _client.from('audit_logs').insert({
        'user_id': userId,
        'tenant_id': tenantId,
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'metadata': metadata,
      });

      _logger.info('Audit log created', category: LogCategory.system, context: {
        'action': action,
        'entityType': entityType,
        'entityId': entityId,
      });
    } catch (e, stackTrace) {
      _logger.error('Failed to create audit log',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      // Don't throw - audit logging failure shouldn't break app
    }
  }

  Future<List<AuditLogEntry>> getLogsForEntity({
    required String entityType,
    required String entityId,
  }) async {
    try {
      final response = await _client
          .from('audit_logs')
          .select()
          .eq('entity_type', entityType)
          .eq('entity_id', entityId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => AuditLogEntry(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        tenantId: json['tenant_id'] as String,
        action: json['action'] as String,
        entityType: json['entity_type'] as String,
        entityId: json['entity_id'] as String,
        metadata: json['metadata'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(json['created_at'] as String),
      )).toList();
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch audit logs',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  Future<List<AuditLogEntry>> getRecentLogs({
    int limit = 100,
  }) async {
    try {
      final response = await _client
          .from('audit_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List).map((json) => AuditLogEntry(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        tenantId: json['tenant_id'] as String,
        action: json['action'] as String,
        entityType: json['entity_type'] as String,
        entityId: json['entity_id'] as String,
        metadata: json['metadata'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(json['created_at'] as String),
      )).toList();
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch recent audit logs',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }
}
