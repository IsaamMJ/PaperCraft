import 'package:equatable/equatable.dart';

class SubjectEntity extends Equatable {
  final String id;
  final String tenantId;
  final String name;

  const SubjectEntity({
    required this.id,
    required this.tenantId,
    required this.name,
  });

  // Add the missing fromJson factory constructor
  factory SubjectEntity.fromJson(Map<String, dynamic> json) {
    return SubjectEntity(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
    );
  }

  // Add the missing toJson method
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
    };
  }

  @override
  List<Object?> get props => [id, tenantId, name];
}