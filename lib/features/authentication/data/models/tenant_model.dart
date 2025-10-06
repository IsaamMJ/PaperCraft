import '../../domain/entities/tenant_entity.dart';

class TenantModel extends TenantEntity {
  const TenantModel({
    required super.id,
    required super.name,
    super.address,
    super.domain,
    required super.isActive,
    required super.isInitialized,
    required super.currentAcademicYear, // ADD THIS
    required super.createdAt,
  });

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    return TenantModel(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      domain: json['domain'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isInitialized: json['is_initialized'] as bool? ?? false,
      currentAcademicYear: json['current_academic_year'] as String? ?? '2024-2025', // ADD THIS
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
      'is_initialized': isInitialized,
      'current_academic_year': currentAcademicYear, // ADD THIS
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
      isInitialized: isInitialized,
      currentAcademicYear: currentAcademicYear, // ADD THIS
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
      isInitialized: entity.isInitialized,
      currentAcademicYear: entity.currentAcademicYear, // ADD THIS
      createdAt: entity.createdAt,
    );
  }
}