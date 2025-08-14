
// Add to existing models
class GradeEntity {
  final String id;
  final String tenantId;
  final String name;
  final int level;
  final String? section;
  final bool isActive;

  const GradeEntity({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.level,
    this.section,
    required this.isActive,
  });
}

class UserPermissions {
  final String userId;
  final String tenantId;
  final List<String>? subjectIds;
  final List<int>? gradeLevels;
  final bool canCreatePapers;

  const UserPermissions({
    required this.userId,
    required this.tenantId,
    this.subjectIds,
    this.gradeLevels,
    required this.canCreatePapers,
  });
}