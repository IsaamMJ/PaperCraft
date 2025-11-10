import 'package:flutter_test/flutter_test.dart';
import 'package:papercraft/features/timetable/domain/entities/exam_timetable_entry_entity.dart';

void main() {
  group('ExamTimetableEntryEntity', () {
    final now = DateTime.now();
    final entry = ExamTimetableEntryEntity(
      id: 'entry-123',
      tenantId: 'tenant-456',
      timetableId: 'timetable-789',
      gradeId: 'grade-10',
      subjectId: 'subject-english',
      section: 'A',
      examDate: DateTime(2025, 11, 15),
      startTime: Duration(hours: 9, minutes: 0),
      endTime: Duration(hours: 11, minutes: 0),
      durationMinutes: 120,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    group('constructor', () {
      test('creates instance with all parameters', () {
        expect(entry.id, 'entry-123');
        expect(entry.tenantId, 'tenant-456');
        expect(entry.gradeId, 'grade-10');
        expect(entry.durationMinutes, 120);
      });

      test('has default isActive value', () {
        final minimal = ExamTimetableEntryEntity(
          id: 'entry-1',
          tenantId: 'tenant-1',
          timetableId: 'timetable-1',
          gradeId: 'grade-1',
          subjectId: 'subject-1',
          section: 'A',
          examDate: DateTime(2025, 1, 1),
          startTime: Duration(hours: 9),
          endTime: Duration(hours: 11),
          durationMinutes: 120,
          createdAt: now,
          updatedAt: now,
        );

        expect(minimal.isActive, true);
      });
    });

    group('time validation', () {
      test('hasValidTimeRange returns true when start < end', () {
        expect(entry.hasValidTimeRange, true);
      });

      test('hasValidTimeRange returns false when start >= end', () {
        final invalid = entry.copyWith(
          startTime: Duration(hours: 11),
          endTime: Duration(hours: 10),
        );

        expect(invalid.hasValidTimeRange, false);
      });

      test('hasValidTimeRange returns false when times are equal', () {
        final invalid = entry.copyWith(
          startTime: Duration(hours: 10),
          endTime: Duration(hours: 10),
        );

        expect(invalid.hasValidTimeRange, false);
      });
    });

    group('time display formatting', () {
      test('startTimeDisplay formats hours and minutes correctly', () {
        expect(entry.startTimeDisplay, '09:00');
      });

      test('endTimeDisplay formats hours and minutes correctly', () {
        expect(entry.endTimeDisplay, '11:00');
      });

      test('startTimeDisplay handles single digit minutes', () {
        final custom = entry.copyWith(
          startTime: Duration(hours: 9, minutes: 5),
        );

        expect(custom.startTimeDisplay, '09:05');
      });

      test('startTimeDisplay handles afternoon times', () {
        final afternoon = entry.copyWith(
          startTime: Duration(hours: 14, minutes: 30),
        );

        expect(afternoon.startTimeDisplay, '14:30');
      });
    });

    group('date display formatting', () {
      test('examDateDisplay returns formatted date', () {
        expect(entry.examDateDisplay, 'Nov 15, 2025');
      });

      test('examDateDisplay handles all months', () {
        final testCases = [
          (1, 'Jan'),
          (2, 'Feb'),
          (3, 'Mar'),
          (4, 'Apr'),
          (5, 'May'),
          (6, 'Jun'),
          (7, 'Jul'),
          (8, 'Aug'),
          (9, 'Sep'),
          (10, 'Oct'),
          (11, 'Nov'),
          (12, 'Dec'),
        ];

        for (final (month, expected) in testCases) {
          final test = entry.copyWith(
            examDate: DateTime(2025, month, 15),
          );
          expect(test.examDateDisplay, contains(expected));
        }
      });
    });

    group('schedule display', () {
      test('scheduleDisplay combines date and time info', () {
        final display = entry.scheduleDisplay;

        expect(display, contains('Nov 15, 2025'));
        expect(display, contains('09:00'));
        expect(display, contains('11:00'));
        expect(display, contains('120 min'));
      });

      test('scheduleDisplay shows correct duration', () {
        final custom = entry.copyWith(
          startTime: Duration(hours: 10),
          endTime: Duration(hours: 11, minutes: 30),
          durationMinutes: 90,
        );

        expect(custom.scheduleDisplay, contains('90 min'));
      });
    });

    group('copyWith', () {
      test('returns same instance when no parameters provided', () {
        final copy = entry.copyWith();
        expect(copy, entry);
      });

      test('allows updating single field', () {
        final updated = entry.copyWith(
          section: 'B',
        );

        expect(updated.section, 'B');
        expect(updated.gradeId, entry.gradeId);
      });

      test('allows updating multiple fields', () {
        final updated = entry.copyWith(
          section: 'C',
          durationMinutes: 90,
          isActive: false,
        );

        expect(updated.section, 'C');
        expect(updated.durationMinutes, 90);
        expect(updated.isActive, false);
      });
    });

    group('soft delete operations', () {
      test('softDelete sets isActive to false', () {
        final deleted = entry.softDelete();

        expect(deleted.isActive, false);
        expect(deleted.id, entry.id); // Other fields unchanged
      });

      test('reactivate sets isActive to true', () {
        final inactive = entry.copyWith(isActive: false);
        final reactivated = inactive.reactivate();

        expect(reactivated.isActive, true);
      });

      test('deleted entry can be soft-deleted again (idempotent)', () {
        final deleted1 = entry.softDelete();
        final deleted2 = deleted1.softDelete();

        expect(deleted1.isActive, false);
        expect(deleted2.isActive, false);
        expect(deleted1, deleted2);
      });
    });

    group('toJson and fromJson', () {
      test('toJson serializes all fields', () {
        final json = entry.toJson();

        expect(json['id'], 'entry-123');
        expect(json['tenant_id'], 'tenant-456');
        expect(json['timetable_id'], 'timetable-789');
        expect(json['grade_id'], 'grade-10');
        expect(json['subject_id'], 'subject-english');
        expect(json['section'], 'A');
        expect(json['duration_minutes'], 120);
        expect(json['is_active'], true);
      });

      test('toJson formats times correctly', () {
        final json = entry.toJson();

        expect(json['start_time'], '09:00:00');
        expect(json['end_time'], '11:00:00');
      });

      test('fromJson deserializes correctly', () {
        final json = entry.toJson();
        final deserialized = ExamTimetableEntryEntity.fromJson(json);

        expect(deserialized.id, entry.id);
        expect(deserialized.gradeId, entry.gradeId);
        expect(deserialized.section, entry.section);
        expect(deserialized.durationMinutes, entry.durationMinutes);
      });

      test('round-trip preserves equality', () {
        final json = entry.toJson();
        final deserialized = ExamTimetableEntryEntity.fromJson(json);

        expect(deserialized, entry);
      });

      test('fromJson handles edge case times', () {
        final json = {
          'id': 'entry-1',
          'tenant_id': 'tenant-1',
          'timetable_id': 'timetable-1',
          'grade_id': 'grade-1',
          'subject_id': 'subject-1',
          'section': 'A',
          'exam_date': '2025-01-01T00:00:00.000Z',
          'start_time': '00:00:00',
          'end_time': '23:59:00',
          'duration_minutes': 1439,
          'is_active': true,
          'created_at': '2025-01-01T00:00:00.000Z',
          'updated_at': '2025-01-01T00:00:00.000Z',
        };

        final entity = ExamTimetableEntryEntity.fromJson(json);

        expect(entity.startTime, Duration(hours: 0, minutes: 0));
        expect(entity.endTime, Duration(hours: 23, minutes: 59));
      });
    });

    group('equality', () {
      test('two entries with same values are equal', () {
        final entry1 = ExamTimetableEntryEntity(
          id: 'entry-123',
          tenantId: 'tenant-456',
          timetableId: 'timetable-789',
          gradeId: 'grade-10',
          subjectId: 'subject-english',
          section: 'A',
          examDate: DateTime(2025, 11, 15),
          startTime: Duration(hours: 9),
          endTime: Duration(hours: 11),
          durationMinutes: 120,
          createdAt: now,
          updatedAt: now,
        );

        final entry2 = ExamTimetableEntryEntity(
          id: 'entry-123',
          tenantId: 'tenant-456',
          timetableId: 'timetable-789',
          gradeId: 'grade-10',
          subjectId: 'subject-english',
          section: 'A',
          examDate: DateTime(2025, 11, 15),
          startTime: Duration(hours: 9),
          endTime: Duration(hours: 11),
          durationMinutes: 120,
          createdAt: now,
          updatedAt: now,
        );

        expect(entry1, entry2);
        expect(entry1.hashCode, entry2.hashCode);
      });

      test('entries with different ids are not equal', () {
        final other = entry.copyWith(id: 'different-id');
        expect(entry, isNot(other));
      });

      test('entries with different times are not equal', () {
        final other = entry.copyWith(
          startTime: Duration(hours: 10),
        );
        expect(entry, isNot(other));
      });
    });

    group('toString', () {
      test('returns readable string representation', () {
        final str = entry.toString();

        expect(str, contains('ExamTimetableEntryEntity'));
        expect(str, contains('entry-123'));
        expect(str, contains('grade-10'));
        expect(str, contains('subject-english'));
        expect(str, contains('A'));
      });
    });

    group('immutability', () {
      test('original unchanged after modifications', () {
        final original = entry;
        final modified = original.copyWith(
          section: 'B',
          isActive: false,
        );

        expect(original.section, 'A');
        expect(original.isActive, true);
        expect(modified.section, 'B');
        expect(modified.isActive, false);
      });
    });

    group('practical scenarios', () {
      test('handles morning exam (9am to 11am)', () {
        expect(entry.startTimeDisplay, '09:00');
        expect(entry.endTimeDisplay, '11:00');
        expect(entry.scheduleDisplay, contains('120 min'));
      });

      test('handles afternoon exam (2pm to 4pm)', () {
        final afternoon = entry.copyWith(
          startTime: Duration(hours: 14),
          endTime: Duration(hours: 16),
          durationMinutes: 120,
        );

        expect(afternoon.startTimeDisplay, '14:00');
        expect(afternoon.endTimeDisplay, '16:00');
      });

      test('handles 1.5 hour exam (90 minutes)', () {
        final custom = entry.copyWith(
          startTime: Duration(hours: 10),
          endTime: Duration(hours: 11, minutes: 30),
          durationMinutes: 90,
        );

        expect(custom.durationMinutes, 90);
        expect(custom.scheduleDisplay, contains('90 min'));
      });

      test('handles exam spanning multiple days (different date)', () {
        final nextDay = entry.copyWith(
          examDate: DateTime(2025, 11, 16),
        );

        expect(nextDay.examDateDisplay, 'Nov 16, 2025');
        expect(nextDay.examDate, DateTime(2025, 11, 16));
      });
    });
  });
}
