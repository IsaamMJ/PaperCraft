import 'dart:convert';
import '../../domain/entities/notification_entity.dart';

class NotificationModel extends NotificationEntity {
  const NotificationModel({
    required super.id,
    required super.userId,
    required super.tenantId,
    required super.type,
    required super.title,
    required super.message,
    super.data,
    required super.isRead,
    required super.createdAt,
    super.readAt,
  });

  factory NotificationModel.fromEntity(NotificationEntity entity) {
    return NotificationModel(
      id: entity.id,
      userId: entity.userId,
      tenantId: entity.tenantId,
      type: entity.type,
      title: entity.title,
      message: entity.message,
      data: entity.data,
      isRead: entity.isRead,
      createdAt: entity.createdAt,
      readAt: entity.readAt,
    );
  }

  factory NotificationModel.fromSupabase(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tenantId: json['tenant_id'] as String,
      type: NotificationType.fromString(json['type'] as String),
      title: json['title'] as String,
      message: json['message'] as String,
      data: json['data'] != null
          ? (json['data'] is String
              ? jsonDecode(json['data'] as String) as Map<String, dynamic>
              : json['data'] as Map<String, dynamic>)
          : null,
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'user_id': userId,
      'tenant_id': tenantId,
      'type': type.value,
      'title': title,
      'message': message,
      'data': data != null ? jsonEncode(data) : null,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
    };
  }

  NotificationEntity toEntity() {
    return NotificationEntity(
      id: id,
      userId: userId,
      tenantId: tenantId,
      type: type,
      title: title,
      message: message,
      data: data,
      isRead: isRead,
      createdAt: createdAt,
      readAt: readAt,
    );
  }
}
