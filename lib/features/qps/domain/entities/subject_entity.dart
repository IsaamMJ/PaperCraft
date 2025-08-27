import 'package:equatable/equatable.dart';

class SubjectEntity extends Equatable {
  final String id;
  final String tenantId;
  final String name;
  final String? description; // Optional field for subject description
  final bool isActive; // Track if subject is currently active

  const SubjectEntity({
    required this.id,
    required this.tenantId,
    required this.name,
    this.description,
    this.isActive = true,
  });

  factory SubjectEntity.fromJson(Map<String, dynamic> json) {
    return SubjectEntity(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      'description': description,
      'is_active': isActive,
    };
  }

  // Helper method to create a copy with different values (consistency with ExamSectionEntity)
  SubjectEntity copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? description,
    bool? isActive,
  }) {
    return SubjectEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [id, tenantId, name, description, isActive];
}