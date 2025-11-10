import 'package:papercraft/features/timetable/domain/entities/exam_timetable_entry_entity.dart';

/// Data model for ExamTimetableEntryEntity
class ExamTimetableEntryModel extends ExamTimetableEntryEntity {
  const ExamTimetableEntryModel({
    required super.id,
    required super.tenantId,
    required super.timetableId,
    required super.gradeId,
    required super.subjectId,
    required super.section,
    required super.examDate,
    required super.startTime,
    required super.endTime,
    required super.durationMinutes,
    super.isActive,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ExamTimetableEntryModel.fromEntity(ExamTimetableEntryEntity entity) {
    return ExamTimetableEntryModel(
      id: entity.id,
      tenantId: entity.tenantId,
      timetableId: entity.timetableId,
      gradeId: entity.gradeId,
      subjectId: entity.subjectId,
      section: entity.section,
      examDate: entity.examDate,
      startTime: entity.startTime,
      endTime: entity.endTime,
      durationMinutes: entity.durationMinutes,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  factory ExamTimetableEntryModel.fromJson(Map<String, dynamic> json) {
    return ExamTimetableEntryModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      timetableId: json['timetable_id'] as String,
      gradeId: json['grade_id'] as String,
      subjectId: json['subject_id'] as String,
      section: json['section'] as String,
      examDate: DateTime.parse(json['exam_date'] as String),
      startTime: _timeStringToDuration(json['start_time'] as String),
      endTime: _timeStringToDuration(json['end_time'] as String),
      durationMinutes: json['duration_minutes'] as int,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'timetable_id': timetableId,
      'grade_id': gradeId,
      'subject_id': subjectId,
      'section': section,
      'exam_date': examDate.toIso8601String(),
      'start_time': _durationToTimeString(startTime),
      'end_time': _durationToTimeString(endTime),
      'duration_minutes': durationMinutes,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
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
