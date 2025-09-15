import 'package:equatable/equatable.dart';

class SubjectEntity extends Equatable {
  final String id;
  final String tenantId;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  const SubjectEntity({
    required this.id,
    required this.tenantId,
    required this.name,
    this.description,
    required this.isActive,
    required this.createdAt,
  });

  factory SubjectEntity.fromJson(Map<String, dynamic> json) {
    return SubjectEntity(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      'description': description,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, tenantId, name, description, isActive, createdAt];
}