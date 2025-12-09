import 'package:papercraft/features/timetable/domain/entities/exam_timetable_entry_entity.dart';

/// Data model for ExamTimetableEntryEntity
class ExamTimetableEntryModel extends ExamTimetableEntryEntity {
  const ExamTimetableEntryModel({
    String? id,
    required String tenantId,
    required String timetableId,
    required String gradeSectionId,
    String? gradeId,
    int? gradeNumber,
    String? section,
    required String subjectId,
    String? subjectName,
    required DateTime examDate,
    required Duration startTime,
    required Duration endTime,
    required int durationMinutes,
    String? subjectType,
    int? maxMarks,
    bool isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : super(
    id: id,
    tenantId: tenantId,
    timetableId: timetableId,
    gradeSectionId: gradeSectionId,
    gradeId: gradeId,
    gradeNumber: gradeNumber,
    section: section,
    subjectId: subjectId,
    subjectName: subjectName,
    examDate: examDate,
    startTime: startTime,
    endTime: endTime,
    durationMinutes: durationMinutes,
    subjectType: subjectType,
    maxMarks: maxMarks,
    isActive: isActive,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  factory ExamTimetableEntryModel.fromEntity(ExamTimetableEntryEntity entity) {
    return ExamTimetableEntryModel(
      id: entity.id,
      tenantId: entity.tenantId,
      timetableId: entity.timetableId,
      gradeSectionId: entity.gradeSectionId,
      gradeId: entity.gradeId,
      gradeNumber: entity.gradeNumber,
      subjectId: entity.subjectId,
      subjectName: entity.subjectName,
      section: entity.section,
      examDate: entity.examDate,
      startTime: entity.startTime,
      endTime: entity.endTime,
      durationMinutes: entity.durationMinutes,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      subjectType: entity.subjectType,
      maxMarks: entity.maxMarks,
    );
  }

  factory ExamTimetableEntryModel.fromJson(Map<String, dynamic> json) {
    return ExamTimetableEntryModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      timetableId: json['timetable_id'] as String,
      gradeSectionId: json['grade_section_id'] as String,
      gradeId: json['grade_id'] as String?, // Can be denormalized in query result
      gradeNumber: null, // Will be fetched via JOIN
      subjectId: json['subject_id'] as String,
      subjectName: null, // Will be fetched separately
      section: json['section'] as String?, // Can be denormalized in query result
      examDate: DateTime.parse(json['exam_date'] as String),
      startTime: _timeStringToDuration(json['start_time'] as String),
      endTime: _timeStringToDuration(json['end_time'] as String),
      durationMinutes: json['duration_minutes'] as int,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      subjectType: json['subject_type'] as String? ?? 'core',
      maxMarks: json['max_marks'] as int? ?? 60,
    );
  }

  Map<String, dynamic> toJson() {
    final json = {
      'tenant_id': tenantId,
      'timetable_id': timetableId,
      'grade_section_id': gradeSectionId,
      'subject_id': subjectId,
      'exam_date': examDate.toIso8601String(),
      'start_time': _durationToTimeString(startTime),
      'end_time': _durationToTimeString(endTime),
      'duration_minutes': durationMinutes,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'subject_type': subjectType ?? 'core',
      'max_marks': maxMarks ?? 60,
    };

    // Only include id if it's not null (for updates/existing records)
    if (id != null) {
      json['id'] = id;
    }

    // Include optional denormalized fields if present
    if (gradeId != null) {
      json['grade_id'] = gradeId;
    }
    if (section != null) {
      json['section'] = section;
    }

    return json;
  }

  Map<String, dynamic> toJsonRequest() {
    return {
      'grade_id': gradeId,
      'subject_id': subjectId,
      'section': section,
      'exam_date': examDate.toIso8601String(),
      'start_time': _durationToTimeString(startTime),
      'end_time': _durationToTimeString(endTime),
      'duration_minutes': durationMinutes,
    };
  }

  static String _durationToTimeString(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:00';
  }

  static Duration _timeStringToDuration(String timeStr) {
    final parts = timeStr.split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    return Duration(hours: hours, minutes: minutes);
  }
}
