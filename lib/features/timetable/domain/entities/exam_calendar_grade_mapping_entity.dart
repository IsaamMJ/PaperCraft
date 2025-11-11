import 'package:equatable/equatable.dart';

/// Entity representing a mapping between an exam calendar and a grade section
/// This entity is created in Step 2 of the exam timetable wizard
class ExamCalendarGradeMappingEntity extends Equatable {
  final String id;
  final String tenantId;
  final String examCalendarId;
  final String gradeSectionId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExamCalendarGradeMappingEntity({
    required this.id,
    required this.tenantId,
    required this.examCalendarId,
    required this.gradeSectionId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object> get props => [
        id,
        tenantId,
        examCalendarId,
        gradeSectionId,
        isActive,
        createdAt,
        updatedAt,
      ];

  /// Create a copy with modified fields
  ExamCalendarGradeMappingEntity copyWith({
    String? id,
    String? tenantId,
    String? examCalendarId,
    String? gradeSectionId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExamCalendarGradeMappingEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      examCalendarId: examCalendarId ?? this.examCalendarId,
      gradeSectionId: gradeSectionId ?? this.gradeSectionId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
