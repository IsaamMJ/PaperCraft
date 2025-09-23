// domain2/entities/grade_entity.dart
import 'package:equatable/equatable.dart';

class GradeEntity extends Equatable {
  final String id;
  final String tenantId;
  final String name;
  final int level;
  final String? section;
  final bool isActive;
  final DateTime createdAt;

  const GradeEntity({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.level,
    this.section,
    required this.isActive,
    required this.createdAt,
  });

  /// Display name for UI (e.g., "Grade 6" or "Grade 10-A")
  String get displayName {
    if (section != null && section!.isNotEmpty) {
      return '$name-$section';
    }
    return name;
  }

  factory GradeEntity.fromJson(Map<String, dynamic> json) {
    return GradeEntity(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      level: json['level'] as int,
      section: json['section'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      'level': level,
      'section': section,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, tenantId, name, level, section, isActive, createdAt];
}