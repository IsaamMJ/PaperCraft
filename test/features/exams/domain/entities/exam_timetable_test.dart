import 'package:flutter_test/flutter_test.dart';
import 'package:papercraft/features/exams/domain/entities/exam_timetable.dart';

void main() {
  group('ExamTimetable', () {
    final now = DateTime.now();

    final testTimetable = ExamTimetable(
      id: 'timetable-1',
      tenantId: 'tenant-123',
      createdBy: 'admin-1',
      examCalendarId: 'calendar-1',
      examName: 'June Monthly Test',
      examType: 'monthlyTest',
      examNumber: null,
      academicYear: '2024-2025',
      status: TimetableStatus.draft,
      publishedAt: null,
      isActive: true,
      metadata: null,
      createdAt: now,
      updatedAt: now,
    );

    test('should create ExamTimetable with correct properties', () {
      expect(testTimetable.id, equals('timetable-1'));
      expect(testTimetable.examName, equals('June Monthly Test'));
      expect(testTimetable.status, equals(TimetableStatus.draft));
      expect(testTimetable.isDraft, equals(true));
      expect(testTimetable.isPublished, equals(false));
      expect(testTimetable.canEdit, equals(true));
    });

    test('should compute displayName correctly for from-calendar timetable', () {
      expect(testTimetable.displayName, equals('June Monthly Test'));
      expect(testTimetable.isFromCalendar, equals(true));
    });

    test('should compute displayName correctly for ad-hoc timetable', () {
      final adHocTimetable = testTimetable.copyWith(
        examCalendarId: null,
        examNumber: 1,
      );

      expect(adHocTimetable.displayName, equals('June Monthly Test - Week 1'));
      expect(adHocTimetable.isAdHoc, equals(true));
    });

    test('should serialize to JSON correctly', () {
      final json = testTimetable.toJson();

      expect(json['id'], equals('timetable-1'));
      expect(json['exam_name'], equals('June Monthly Test'));
      expect(json['status'], equals('draft'));
      expect(json['academic_year'], equals('2024-2025'));
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'id': 'timetable-1',
        'tenant_id': 'tenant-123',
        'created_by': 'admin-1',
        'exam_calendar_id': 'calendar-1',
        'exam_name': 'June Monthly Test',
        'exam_type': 'monthlyTest',
        'exam_number': null,
        'academic_year': '2024-2025',
        'status': 'draft',
        'published_at': null,
        'is_active': true,
        'metadata': null,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final timetable = ExamTimetable.fromJson(json);

      expect(timetable.id, equals('timetable-1'));
      expect(timetable.status, equals(TimetableStatus.draft));
      expect(timetable.examName, equals('June Monthly Test'));
    });

    test('should handle published status correctly', () {
      final publishedTimetable = testTimetable.copyWith(
        status: TimetableStatus.published,
        publishedAt: DateTime.now(),
      );

      expect(publishedTimetable.isDraft, equals(false));
      expect(publishedTimetable.isPublished, equals(true));
      expect(publishedTimetable.canEdit, equals(false));
    });

    test('TimetableStatusX should convert enum to/from string', () {
      expect(TimetableStatus.draft.toShortString(), equals('draft'));
      expect(TimetableStatus.published.toShortString(), equals('published'));
      expect(TimetableStatus.completed.toShortString(), equals('completed'));

      expect(TimetableStatusX.fromString('draft'), equals(TimetableStatus.draft));
      expect(
        TimetableStatusX.fromString('published'),
        equals(TimetableStatus.published),
      );
    });

    test('should support copyWith', () {
      final updated = testTimetable.copyWith(
        status: TimetableStatus.published,
        publishedAt: now,
      );

      expect(updated.status, equals(TimetableStatus.published));
      expect(updated.publishedAt, equals(now));
      expect(updated.id, equals(testTimetable.id));
    });

    test('should support equality comparison', () {
      final timetable1 = ExamTimetable(
        id: 'timetable-1',
        tenantId: 'tenant-123',
        createdBy: 'admin-1',
        examCalendarId: 'calendar-1',
        examName: 'June Monthly Test',
        examType: 'monthlyTest',
        examNumber: null,
        academicYear: '2024-2025',
        status: TimetableStatus.draft,
        publishedAt: null,
        isActive: true,
        metadata: null,
        createdAt: now,
        updatedAt: now,
      );

      final timetable2 = ExamTimetable(
        id: 'timetable-1',
        tenantId: 'tenant-123',
        createdBy: 'admin-1',
        examCalendarId: 'calendar-1',
        examName: 'June Monthly Test',
        examType: 'monthlyTest',
        examNumber: null,
        academicYear: '2024-2025',
        status: TimetableStatus.draft,
        publishedAt: null,
        isActive: true,
        metadata: null,
        createdAt: now,
        updatedAt: now,
      );

      expect(timetable1, equals(timetable2));
    });
  });
}
