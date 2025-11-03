import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papercraft/features/exams/domain/entities/exam_timetable_entry.dart';

void main() {
  group('ExamTimetableEntry', () {
    final now = DateTime.now();
    final examDate = DateTime(2024, 6, 15);
    final startTime = TimeOfDay(hour: 9, minute: 0);
    final endTime = TimeOfDay(hour: 10, minute: 30);

    final testEntry = ExamTimetableEntry(
      id: 'entry-1',
      tenantId: 'tenant-123',
      timetableId: 'timetable-1',
      gradeId: 'Grade 5',
      subjectId: 'Maths',
      section: 'A',
      examDate: examDate,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: 90,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    test('should create ExamTimetableEntry with correct properties', () {
      expect(testEntry.id, equals('entry-1'));
      expect(testEntry.tenantId, equals('tenant-123'));
      expect(testEntry.timetableId, equals('timetable-1'));
      expect(testEntry.gradeId, equals('Grade 5'));
      expect(testEntry.subjectId, equals('Maths'));
      expect(testEntry.section, equals('A'));
      expect(testEntry.durationMinutes, equals(90));
      expect(testEntry.isActive, equals(true));
    });

    test('should compute displayName correctly', () {
      expect(testEntry.displayName, equals('Grade 5-A Maths'));
    });

    test('should compute displayName with different section', () {
      final entry = testEntry.copyWith(section: 'B');
      expect(entry.displayName, equals('Grade 5-B Maths'));
    });

    test('should format time range correctly', () {
      expect(testEntry.timeRange, equals('09:00 - 10:30'));
    });

    test('should format time range with afternoon times', () {
      final entry = testEntry.copyWith(
        startTime: TimeOfDay(hour: 14, minute: 0),
        endTime: TimeOfDay(hour: 15, minute: 30),
      );

      expect(entry.timeRange, equals('14:00 - 15:30'));
    });

    test('should format exam date correctly', () {
      expect(testEntry.formattedDate, equals('Jun 15, 2024'));
    });

    test('should format exam date for different months', () {
      final entry = testEntry.copyWith(
        examDate: DateTime(2024, 1, 5),
      );

      expect(entry.formattedDate, equals('Jan 5, 2024'));
    });

    test('should parse time from string correctly', () {
      final time = ExamTimetableEntry.parseTime('14:30');

      expect(time.hour, equals(14));
      expect(time.minute, equals(30));
    });

    test('should parse time with leading zeros', () {
      final time = ExamTimetableEntry.parseTime('09:05');

      expect(time.hour, equals(9));
      expect(time.minute, equals(5));
    });

    test('should serialize to JSON correctly', () {
      final json = testEntry.toJson();

      expect(json['id'], equals('entry-1'));
      expect(json['tenant_id'], equals('tenant-123'));
      expect(json['timetable_id'], equals('timetable-1'));
      expect(json['grade_id'], equals('Grade 5'));
      expect(json['subject_id'], equals('Maths'));
      expect(json['section'], equals('A'));
      expect(json['exam_date'], equals('2024-06-15'));
      expect(json['start_time'], equals('09:00'));
      expect(json['end_time'], equals('10:30'));
      expect(json['duration_minutes'], equals(90));
      expect(json['is_active'], equals(true));
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'id': 'entry-1',
        'tenant_id': 'tenant-123',
        'timetable_id': 'timetable-1',
        'grade_id': 'Grade 5',
        'subject_id': 'Maths',
        'section': 'A',
        'exam_date': '2024-06-15',
        'start_time': '09:00',
        'end_time': '10:30',
        'duration_minutes': 90,
        'is_active': true,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final entry = ExamTimetableEntry.fromJson(json);

      expect(entry.id, equals('entry-1'));
      expect(entry.gradeId, equals('Grade 5'));
      expect(entry.subjectId, equals('Maths'));
      expect(entry.section, equals('A'));
      expect(entry.startTime.hour, equals(9));
      expect(entry.startTime.minute, equals(0));
      expect(entry.endTime.hour, equals(10));
      expect(entry.endTime.minute, equals(30));
    });

    test('should handle JSON round-trip serialization', () {
      final json = testEntry.toJson();
      final entry = ExamTimetableEntry.fromJson(json);

      expect(entry.id, equals(testEntry.id));
      expect(entry.gradeId, equals(testEntry.gradeId));
      expect(entry.subjectId, equals(testEntry.subjectId));
      expect(entry.section, equals(testEntry.section));
      expect(entry.startTime, equals(testEntry.startTime));
      expect(entry.endTime, equals(testEntry.endTime));
    });

    test('should support equality comparison', () {
      final entry1 = ExamTimetableEntry(
        id: 'entry-1',
        tenantId: 'tenant-123',
        timetableId: 'timetable-1',
        gradeId: 'Grade 5',
        subjectId: 'Maths',
        section: 'A',
        examDate: examDate,
        startTime: startTime,
        endTime: endTime,
        durationMinutes: 90,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final entry2 = ExamTimetableEntry(
        id: 'entry-1',
        tenantId: 'tenant-123',
        timetableId: 'timetable-1',
        gradeId: 'Grade 5',
        subjectId: 'Maths',
        section: 'A',
        examDate: examDate,
        startTime: startTime,
        endTime: endTime,
        durationMinutes: 90,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(entry1, equals(entry2));
    });

    test('should support copyWith', () {
      final updated = testEntry.copyWith(
        startTime: TimeOfDay(hour: 10, minute: 0),
        endTime: TimeOfDay(hour: 11, minute: 30),
        durationMinutes: 90,
      );

      expect(updated.startTime.hour, equals(10));
      expect(updated.endTime.hour, equals(11));
      expect(updated.id, equals(testEntry.id));
      expect(updated.gradeId, equals(testEntry.gradeId));
    });

    test('should have correct toString representation', () {
      final string = testEntry.toString();

      expect(string, contains('ExamTimetableEntry'));
      expect(string, contains('Grade 5-A Maths'));
      expect(string, contains('09:00 - 10:30'));
    });

    test('should handle deactivation via copyWith', () {
      final inactive = testEntry.copyWith(isActive: false);

      expect(inactive.isActive, equals(false));
      expect(inactive.id, equals(testEntry.id));
    });

    test('should handle time at midnight', () {
      final entry = testEntry.copyWith(
        startTime: TimeOfDay(hour: 0, minute: 0),
        endTime: TimeOfDay(hour: 1, minute: 30),
      );

      expect(entry.timeRange, equals('00:00 - 01:30'));
    });

    test('should handle time at end of day', () {
      final entry = testEntry.copyWith(
        startTime: TimeOfDay(hour: 23, minute: 0),
        endTime: TimeOfDay(hour: 23, minute: 59),
      );

      expect(entry.timeRange, equals('23:00 - 23:59'));
    });

    test('should format date with different years', () {
      final entry = testEntry.copyWith(
        examDate: DateTime(2025, 12, 25),
      );

      expect(entry.formattedDate, equals('Dec 25, 2025'));
    });
  });
}
