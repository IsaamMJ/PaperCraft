import 'package:flutter_test/flutter_test.dart';
import 'package:papercraft/features/timetable/domain/entities/exam_calendar_entity.dart';

void main() {
  group('ExamCalendarEntity', () {
    final now = DateTime.now();
    final calendar = ExamCalendarEntity(
      id: 'cal-123',
      tenantId: 'tenant-456',
      examName: 'Mid-term Exams',
      examType: 'mid_term',
      monthNumber: 11,
      plannedStartDate: DateTime(2025, 11, 10),
      plannedEndDate: DateTime(2025, 11, 30),
      paperSubmissionDeadline: DateTime(2025, 11, 5),
      displayOrder: 1,
      metadata: {'notes': 'First semester exams'},
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    group('constructor', () {
      test('creates instance with all parameters', () {
        expect(calendar.id, 'cal-123');
        expect(calendar.tenantId, 'tenant-456');
        expect(calendar.examName, 'Mid-term Exams');
        expect(calendar.examType, 'mid_term');
        expect(calendar.monthNumber, 11);
        expect(calendar.isActive, true);
      });

      test('has default values for optional parameters', () {
        final minimal = ExamCalendarEntity(
          id: 'cal-1',
          tenantId: 'tenant-1',
          examName: 'Test',
          examType: 'mid_term',
          monthNumber: 1,
          plannedStartDate: DateTime(2025, 1, 1),
          plannedEndDate: DateTime(2025, 1, 31),
          createdAt: now,
          updatedAt: now,
        );

        expect(minimal.paperSubmissionDeadline, isNull);
        expect(minimal.displayOrder, 0);
        expect(minimal.metadata, isNull);
        expect(minimal.isActive, true);
      });
    });

    group('copyWith', () {
      test('returns same instance when no parameters provided', () {
        final copy = calendar.copyWith();
        expect(copy.id, calendar.id);
        expect(copy.examName, calendar.examName);
      });

      test('returns new instance with updated fields', () {
        final updated = calendar.copyWith(
          examName: 'Final Exams',
          status: 'final',
        );

        expect(updated.examName, 'Final Exams');
        expect(updated.id, calendar.id); // Unchanged
        expect(updated.tenantId, calendar.tenantId); // Unchanged
      });

      test('allows nullifying optional fields', () {
        final updated = calendar.copyWith(
          metadata: null,
          paperSubmissionDeadline: null,
        );

        expect(updated.metadata, isNull);
        expect(updated.paperSubmissionDeadline, isNull);
      });

      test('preserves identity equality after copy', () {
        final copy = calendar.copyWith();
        expect(copy, calendar);
      });
    });

    group('toJson and fromJson', () {
      test('toJson serializes all fields correctly', () {
        final json = calendar.toJson();

        expect(json['id'], 'cal-123');
        expect(json['tenant_id'], 'tenant-456');
        expect(json['exam_name'], 'Mid-term Exams');
        expect(json['exam_type'], 'mid_term');
        expect(json['month_number'], 11);
        expect(json['display_order'], 1);
        expect(json['is_active'], true);
        expect(json['metadata'], {'notes': 'First semester exams'});
      });

      test('fromJson deserializes JSON correctly', () {
        final json = calendar.toJson();
        final deserialized = ExamCalendarEntity.fromJson(json);

        expect(deserialized.id, calendar.id);
        expect(deserialized.tenantId, calendar.tenantId);
        expect(deserialized.examName, calendar.examName);
        expect(deserialized.examType, calendar.examType);
        expect(deserialized.monthNumber, calendar.monthNumber);
        expect(deserialized.metadata, calendar.metadata);
      });

      test('round-trip serialization preserves equality', () {
        final json = calendar.toJson();
        final deserialized = ExamCalendarEntity.fromJson(json);

        expect(deserialized, calendar);
      });

      test('fromJson handles missing optional fields', () {
        final minimal = {
          'id': 'cal-1',
          'tenant_id': 'tenant-1',
          'exam_name': 'Test',
          'exam_type': 'mid_term',
          'month_number': 1,
          'planned_start_date': '2025-01-01T00:00:00.000Z',
          'planned_end_date': '2025-01-31T00:00:00.000Z',
          'created_at': '2025-01-01T00:00:00.000Z',
          'updated_at': '2025-01-01T00:00:00.000Z',
        };

        final entity = ExamCalendarEntity.fromJson(minimal);

        expect(entity.paperSubmissionDeadline, isNull);
        expect(entity.metadata, isNull);
        expect(entity.displayOrder, 0);
        expect(entity.isActive, true);
      });
    });

    group('equality', () {
      test('two calendars with same values are equal', () {
        final calendar1 = ExamCalendarEntity(
          id: 'cal-123',
          tenantId: 'tenant-456',
          examName: 'Mid-term Exams',
          examType: 'mid_term',
          monthNumber: 11,
          plannedStartDate: DateTime(2025, 11, 10),
          plannedEndDate: DateTime(2025, 11, 30),
          createdAt: now,
          updatedAt: now,
        );

        final calendar2 = ExamCalendarEntity(
          id: 'cal-123',
          tenantId: 'tenant-456',
          examName: 'Mid-term Exams',
          examType: 'mid_term',
          monthNumber: 11,
          plannedStartDate: DateTime(2025, 11, 10),
          plannedEndDate: DateTime(2025, 11, 30),
          createdAt: now,
          updatedAt: now,
        );

        expect(calendar1, calendar2);
        expect(calendar1.hashCode, calendar2.hashCode);
      });

      test('calendars with different ids are not equal', () {
        final other = calendar.copyWith(id: 'different-id');
        expect(calendar, isNot(other));
      });

      test('calendars with different names are not equal', () {
        final other = calendar.copyWith(examName: 'Final Exams');
        expect(calendar, isNot(other));
      });
    });

    group('toString', () {
      test('returns readable string representation', () {
        final str = calendar.toString();

        expect(str, contains('ExamCalendarEntity'));
        expect(str, contains('cal-123'));
        expect(str, contains('Mid-term Exams'));
        expect(str, contains('mid_term'));
      });
    });

    group('validation constraints', () {
      test('can be created with valid date range', () {
        final valid = ExamCalendarEntity(
          id: 'cal-1',
          tenantId: 'tenant-1',
          examName: 'Test',
          examType: 'mid_term',
          monthNumber: 1,
          plannedStartDate: DateTime(2025, 1, 1),
          plannedEndDate: DateTime(2025, 1, 31),
          createdAt: now,
          updatedAt: now,
        );

        expect(valid.plannedStartDate.isBefore(valid.plannedEndDate) ||
            valid.plannedStartDate.isAtSameMomentAs(valid.plannedEndDate),
          true);
      });

      test('can have same start and end date', () {
        final same = ExamCalendarEntity(
          id: 'cal-1',
          tenantId: 'tenant-1',
          examName: 'Test',
          examType: 'mid_term',
          monthNumber: 1,
          plannedStartDate: DateTime(2025, 1, 1),
          plannedEndDate: DateTime(2025, 1, 1),
          createdAt: now,
          updatedAt: now,
        );

        expect(
          same.plannedStartDate.isAtSameMomentAs(same.plannedEndDate),
          true,
        );
      });

      test('month number is between 1 and 12', () {
        for (int month = 1; month <= 12; month++) {
          final cal = calendar.copyWith(monthNumber: month);
          expect(cal.monthNumber >= 1 && cal.monthNumber <= 12, true);
        }
      });
    });

    group('immutability', () {
      test('cannot modify fields after creation', () {
        // This test documents immutability - trying to modify would fail at compile time
        // We verify this through the copyWith pattern
        final original = calendar;
        final modified = original.copyWith(isActive: false);

        expect(original.isActive, true); // Original unchanged
        expect(modified.isActive, false); // New instance modified
      });
    });
  });
}
