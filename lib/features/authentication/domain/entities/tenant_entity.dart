import 'package:equatable/equatable.dart';

class TenantEntity extends Equatable {
  final String id;
  final String name;
  final String? address;
  final String? domain;
  final bool isActive;
  final bool isInitialized;
  final DateTime createdAt;

  const TenantEntity({
    required this.id,
    required this.name,
    this.address,
    this.domain,
    required this.isActive,
    required this.isInitialized,
    required this.createdAt,
  });

  String get displayName => name;

  String get shortName {
    if (name.length <= 20) return name;
    return '${name.substring(0, 17)}...';
  }

  @override
  List<Object?> get props => [
    id,
    name,
    address,
    domain,
    isActive,
    isInitialized,
    createdAt,
  ];
}