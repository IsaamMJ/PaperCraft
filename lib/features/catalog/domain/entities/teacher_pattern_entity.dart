// features/catalog/domain/entities/teacher_pattern_entity.dart
import 'package:equatable/equatable.dart';
import 'paper_section_entity.dart';

/// Represents a saved paper structure pattern that teachers can reuse
/// Patterns are auto-saved after paper creation and can be loaded for future papers
class TeacherPatternEntity extends Equatable {
  final String id;
  final String tenantId;
  final String teacherId;
  final String subjectId;
  final String name;
  final List<PaperSectionEntity> sections;
  final int totalQuestions;
  final int totalMarks;
  final int useCount;
  final DateTime? lastUsedAt;
  final DateTime createdAt;

  const TeacherPatternEntity({
    required this.id,
    required this.tenantId,
    required this.teacherId,
    required this.subjectId,
    required this.name,
    required this.sections,
    required this.totalQuestions,
    required this.totalMarks,
    this.useCount = 0,
    this.lastUsedAt,
    required this.createdAt,
  });

  /// Number of sections in this pattern
  int get sectionCount => sections.length;

  /// Summary string for display (e.g., "10×2 + 5×5")
  String get summary => sections.map((s) => '${s.questions}×${s.marksPerQuestion}').join(' + ');

  /// Full description (e.g., "MCQs (10×2) + Short Answer (5×5) = 45M")
  String get fullDescription {
    final sectionSummaries = sections.map((s) => '${s.name} (${s.summary})').join(' + ');
    return '$sectionSummaries = ${totalMarks}M';
  }

  /// Pattern display name with summary (e.g., "Quarterly (10×2 + 5×5)")
  String get displayNameWithSummary => '$name ($summary)';

  /// Check if pattern has been used recently (within last 30 days)
  bool get isRecentlyUsed {
    if (lastUsedAt == null) return false;
    final daysSinceUse = DateTime.now().difference(lastUsedAt!).inDays;
    return daysSinceUse <= 30;
  }

  /// Check if pattern is frequently used (used more than 3 times)
  bool get isFrequentlyUsed => useCount > 3;

  /// Create from JSON
  factory TeacherPatternEntity.fromJson(Map<String, dynamic> json) {
    // Parse sections from JSONB array
    List<PaperSectionEntity> parsedSections = [];
    if (json['sections'] != null && json['sections'] is List) {
      parsedSections = (json['sections'] as List<dynamic>)
          .map((section) => PaperSectionEntity.fromJson(section as Map<String, dynamic>))
          .toList();
    }

    return TeacherPatternEntity(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      teacherId: json['teacher_id'] as String,
      subjectId: json['subject_id'] as String,
      name: json['name'] as String,
      sections: parsedSections,
      totalQuestions: json['total_questions'] as int,
      totalMarks: json['total_marks'] as int,
      useCount: json['use_count'] as int? ?? 0,
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.parse(json['last_used_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'teacher_id': teacherId,
      'subject_id': subjectId,
      'name': name,
      'sections': sections.map((s) => s.toJson()).toList(),
      'total_questions': totalQuestions,
      'total_marks': totalMarks,
      'use_count': useCount,
      'last_used_at': lastUsedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create a copy with modified fields
  TeacherPatternEntity copyWith({
    String? id,
    String? tenantId,
    String? teacherId,
    String? subjectId,
    String? name,
    List<PaperSectionEntity>? sections,
    int? totalQuestions,
    int? totalMarks,
    int? useCount,
    DateTime? lastUsedAt,
    DateTime? createdAt,
  }) {
    return TeacherPatternEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      teacherId: teacherId ?? this.teacherId,
      subjectId: subjectId ?? this.subjectId,
      name: name ?? this.name,
      sections: sections ?? this.sections,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      totalMarks: totalMarks ?? this.totalMarks,
      useCount: useCount ?? this.useCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Create empty pattern for new creation
  factory TeacherPatternEntity.empty({
    required String teacherId,
    required String tenantId,
    required String subjectId,
  }) {
    return TeacherPatternEntity(
      id: '',
      tenantId: tenantId,
      teacherId: teacherId,
      subjectId: subjectId,
      name: '',
      sections: const [],
      totalQuestions: 0,
      totalMarks: 0,
      useCount: 0,
      createdAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        tenantId,
        teacherId,
        subjectId,
        name,
        sections,
        totalQuestions,
        totalMarks,
        useCount,
        lastUsedAt,
        createdAt,
      ];

  @override
  String toString() => '$name: $fullDescription (used $useCount times)';
}
