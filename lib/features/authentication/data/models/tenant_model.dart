import '../../domain/entities/tenant_entity.dart';

class TenantModel extends TenantEntity {
  const TenantModel({
    required super.id,
    required super.name,
    super.address,
    super.domain,
    required super.isActive,
    required super.createdAt,
  });

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    return TenantModel(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      domain: json['domain'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'domain': domain,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  TenantEntity toEntity() {
    return TenantEntity(
      id: id,
      name: name,
      address: address,
      domain: domain,
      isActive: isActive,
      createdAt: createdAt,
    );
  }

  factory TenantModel.fromEntity(TenantEntity entity) {
    return TenantModel(
      id: entity.id,
      name: entity.name,
      address: entity.address,
      domain: entity.domain,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }
}
