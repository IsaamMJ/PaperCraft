import 'package:flutter_test/flutter_test.dart';
import 'package:papercraft/features/exams/domain/entities/exam_calendar.dart';

void main() {
  group('ExamCalendar', () {
    final now = DateTime.now();
    final futureDate = now.add(Duration(days: 30));
    final pastDate = now.subtract(Duration(days: 30));

    final testCalendar = ExamCalendar(
      id: 'calendar-1',
      tenantId: 'tenant-123',
      examName: 'June Monthly Test',
      examType: 'monthlyTest',
      monthNumber: 6,
      plannedStartDate: futureDate,
      plannedEndDate: futureDate.add(Duration(days: 5)),
      paperSubmissionDeadline: futureDate.subtract(Duration(days: 10)),
      displayOrder: 1,
      metadata: null,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    test('should create ExamCalendar with correct properties', () {
      expect(testCalendar.id, equals('calendar-1'));
      expect(testCalendar.tenantId, equals('tenant-123'));
      expect(testCalendar.examName, equals('June Monthly Test'));
      expect(testCalendar.examType, equals('monthlyTest'));
      expect(testCalendar.monthNumber, equals(6));
      expect(testCalendar.displayOrder, equals(1));
      expect(testCalendar.isActive, equals(true));
    });

    test('should detect upcoming exam correctly', () {
      final upcomingCalendar = testCalendar.copyWith(
        plannedStartDate: futureDate,
      );

      expect(upcomingCalendar.isUpcoming, equals(true));
    });

    test('should detect past exam correctly', () {
      final pastCalendar = testCalendar.copyWith(
        plannedStartDate: pastDate,
      );

      expect(pastCalendar.isUpcoming, equals(false));
    });

    test('should detect past deadline correctly', () {
      final pastDeadlineCalendar = testCalendar.copyWith(
        paperSubmissionDeadline: pastDate,
      );

      expect(pastDeadlineCalendar.isPastDeadline, equals(true));
    });

    test('should detect future deadline correctly', () {
      final futureDeadlineCalendar = testCalendar.copyWith(
        paperSubmissionDeadline: futureDate,
      );

      expect(futureDeadlineCalendar.isPastDeadline, equals(false));
    });

    test('should calculate days until deadline correctly', () {
      final daysUntil = testCalendar.daysUntilDeadline;

      expect(daysUntil, isNotNull);
      expect(daysUntil, greaterThanOrEqualTo(8)); // Roughly 10 days minus processing time
    });

    test('should return null for days until deadline when no deadline set', () {
      final calendarNoDeadline = testCalendar.copyWith(
        paperSubmissionDeadline: null,
      );

      expect(calendarNoDeadline.daysUntilDeadline, isNull);
      expect(calendarNoDeadline.isPastDeadline, equals(false));
    });

    test('should serialize to JSON correctly', () {
      final json = testCalendar.toJson();

      expect(json['id'], equals('calendar-1'));
      expect(json['tenant_id'], equals('tenant-123'));
      expect(json['exam_name'], equals('June Monthly Test'));
      expect(json['exam_type'], equals('monthlyTest'));
      expect(json['month_number'], equals(6));
      expect(json['display_order'], equals(1));
      expect(json['is_active'], equals(true));
    });

    test('should serialize dates as date-only strings', () {
      final json = testCalendar.toJson();

      expect(json['planned_start_date'], isA<String>());
      expect(json['planned_end_date'], isA<String>());
      // Verify format is YYYY-MM-DD (no time part)
      expect(json['planned_start_date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'id': 'calendar-1',
        'tenant_id': 'tenant-123',
        'exam_name': 'June Monthly Test',
        'exam_type': 'monthlyTest',
        'month_number': 6,
        'planned_start_date': futureDate.toIso8601String().split('T')[0],
        'planned_end_date': futureDate.add(Duration(days: 5)).toIso8601String().split('T')[0],
        'paper_submission_deadline': futureDate.subtract(Duration(days: 10)).toIso8601String().split('T')[0],
        'display_order': 1,
        'metadata': null,
        'is_active': true,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final calendar = ExamCalendar.fromJson(json);

      expect(calendar.id, equals('calendar-1'));
      expect(calendar.examName, equals('June Monthly Test'));
      expect(calendar.monthNumber, equals(6));
    });

    test('should handle JSON round-trip serialization', () {
      final json = testCalendar.toJson();
      final calendar = ExamCalendar.fromJson(json);

      expect(calendar.id, equals(testCalendar.id));
      expect(calendar.examName, equals(testCalendar.examName));
      expect(calendar.monthNumber, equals(testCalendar.monthNumber));
    });

    test('should support equality comparison', () {
      final calendar1 = ExamCalendar(
        id: 'calendar-1',
        tenantId: 'tenant-123',
        examName: 'June Monthly Test',
        examType: 'monthlyTest',
        monthNumber: 6,
        plannedStartDate: futureDate,
        plannedEndDate: futureDate.add(Duration(days: 5)),
        paperSubmissionDeadline: futureDate.subtract(Duration(days: 10)),
        displayOrder: 1,
        metadata: null,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final calendar2 = ExamCalendar(
        id: 'calendar-1',
        tenantId: 'tenant-123',
        examName: 'June Monthly Test',
        examType: 'monthlyTest',
        monthNumber: 6,
        plannedStartDate: futureDate,
        plannedEndDate: futureDate.add(Duration(days: 5)),
        paperSubmissionDeadline: futureDate.subtract(Duration(days: 10)),
        displayOrder: 1,
        metadata: null,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(calendar1, equals(calendar2));
    });

    test('should support copyWith', () {
      final updated = testCalendar.copyWith(
        examName: 'July Monthly Test',
        monthNumber: 7,
      );

      expect(updated.examName, equals('July Monthly Test'));
      expect(updated.monthNumber, equals(7));
      expect(updated.id, equals(testCalendar.id));
      expect(updated.examType, equals(testCalendar.examType));
    });

    test('should have correct toString representation', () {
      final string = testCalendar.toString();

      expect(string, contains('ExamCalendar'));
      expect(string, contains('June Monthly Test'));
      expect(string, contains('monthlyTest'));
      expect(string, contains('6'));
    });

    test('should support metadata', () {
      final calendarWithMetadata = testCalendar.copyWith(
        metadata: {
          'notes': 'Important exam',
          'version': 2,
        },
      );

      expect(calendarWithMetadata.metadata, isNotNull);
      expect(calendarWithMetadata.metadata?['notes'], equals('Important exam'));
      expect(calendarWithMetadata.metadata?['version'], equals(2));
    });

    test('should handle deactivation via copyWith', () {
      final inactive = testCalendar.copyWith(isActive: false);

      expect(inactive.isActive, equals(false));
      expect(inactive.id, equals(testCalendar.id));
    });

    test('should handle null metadata', () {
      final calendarNoMetadata = testCalendar.copyWith(metadata: null);

      expect(calendarNoMetadata.metadata, isNull);
    });
  });
}
