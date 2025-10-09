import 'package:equatable/equatable.dart';

/// Notification types for different events
enum NotificationType {
  paperApproved('paper_approved'),
  paperRejected('paper_rejected'),
  paperResubmitted('paper_resubmitted');

  const NotificationType(this.value);
  final String value;

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => NotificationType.paperApproved,
    );
  }
}

/// Notification entity representing a system notification
class NotificationEntity extends Equatable {
  final String id;
  final String userId;
  final String tenantId;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  const NotificationEntity({
    required this.id,
    required this.userId,
    required this.tenantId,
    required this.type,
    required this.title,
    required this.message,
    this.data,
    required this.isRead,
    required this.createdAt,
    this.readAt,
  });

  NotificationEntity copyWith({
    String? id,
    String? userId,
    String? tenantId,
    NotificationType? type,
    String? title,
    String? message,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return NotificationEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tenantId: tenantId ?? this.tenantId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        tenantId,
        type,
        title,
        message,
        data,
        isRead,
        createdAt,
        readAt,
      ];
}
