// features/authentication/domain/entities/tenant_entity.dart
class TenantEntity {
  final String id;
  final String name;
  final String? address;
  final String? domain;
  final bool isActive;
  final DateTime createdAt;

  const TenantEntity({
    required this.id,
    required this.name,
    this.address,
    this.domain,
    required this.isActive,
    required this.createdAt,
  });

  // Business logic
  bool get isValid => id.isNotEmpty && name.isNotEmpty && isActive;

  String get displayName => name.trim();

  String get shortName {
    // Extract short name from full name (e.g., "Pearl Matriculation..." -> "Pearl")
    final words = name.trim().split(' ');
    return words.isNotEmpty ? words.first : name;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is TenantEntity &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'TenantEntity(id: $id, name: $name, isActive: $isActive)';
}