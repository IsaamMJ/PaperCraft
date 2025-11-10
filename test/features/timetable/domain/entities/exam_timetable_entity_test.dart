import 'package:flutter_test/flutter_test.dart';
import 'package:papercraft/features/timetable/domain/entities/exam_timetable_entity.dart';

void main() {
  group('ExamTimetableEntity', () {
    final now = DateTime.now();
    final timetable = ExamTimetableEntity(
      id: 'timetable-123',
      tenantId: 'tenant-456',
      createdBy: 'admin-789',
      examCalendarId: 'calendar-111',
      examName: 'Mid-term Exams',
      examType: 'mid_term',
      examNumber: 1,
      academicYear: '2025-2026',
      status: 'draft',
      publishedAt: null,
      isActive: true,
      metadata: {'version': 1},
      createdAt: now,
      updatedAt: now,
    );

    group('constructor', () {
      test('creates instance with all parameters', () {
        expect(timetable.id, 'timetable-123');
        expect(timetable.tenantId, 'tenant-456');
        expect(timetable.createdBy, 'admin-789');
        expect(timetable.examName, 'Mid-term Exams');
        expect(timetable.status, 'draft');
      });

      test('has default status of draft', () {
        final minimal = ExamTimetableEntity(
          id: 'timetable-1',
          tenantId: 'tenant-1',
          createdBy: 'admin-1',
          examName: 'Test',
          examType: 'mid_term',
          academicYear: '2025-2026',
          createdAt: now,
          updatedAt: now,
        );

        expect(minimal.status, 'draft');
        expect(minimal.isActive, true);
      });
    });

    group('status checks', () {
      test('isDraft returns true for draft status', () {
        expect(timetable.isDraft, true);
      });

      test('isPublished returns false for draft status', () {
        expect(timetable.isPublished, false);
      });

      test('isArchived returns false for draft status', () {
        expect(timetable.isArchived, false);
      });

      test('isDraft works for published status', () {
        final published = timetable.copyWith(status: 'published');
        expect(published.isDraft, false);
        expect(published.isPublished, true);
      });

      test('isArchived works for archived status', () {
        final archived = timetable.copyWith(status: 'archived');
        expect(archived.isArchived, true);
        expect(archived.isDraft, false);
      });
    });

    group('permission checks', () {
      test('canEdit returns true for draft active timetables', () {
        expect(timetable.canEdit, true);
      });

      test('canEdit returns false for published timetables', () {
        final published = timetable.copyWith(status: 'published');
        expect(published.canEdit, false);
      });

      test('canEdit returns false for inactive timetables', () {
        final inactive = timetable.copyWith(isActive: false);
        expect(inactive.canEdit, false);
      });

      test('canPublish returns true for draft active timetables', () {
        expect(timetable.canPublish, true);
      });

      test('canPublish returns false for published timetables', () {
        final published = timetable.copyWith(status: 'published');
        expect(published.canPublish, false);
      });
    });

    group('state transitions', () {
      test('markAsPublished sets status and publishedAt', () {
        final published = timetable.markAsPublished();

        expect(published.status, 'published');
        expect(published.publishedAt, isNotNull);
        expect(published.publishedAt!.year,
            DateTime.now().year); // Published recently
      });

      test('markAsArchived sets status to archived', () {
        final archived = timetable.markAsArchived();

        expect(archived.status, 'archived');
      });

      test('softDelete sets isActive to false', () {
        final deleted = timetable.softDelete();

        expect(deleted.isActive, false);
        expect(deleted.status, timetable.status); // Status unchanged
      });

      test('reactivate sets isActive to true', () {
        final inactive = timetable.copyWith(isActive: false);
        final reactivated = inactive.reactivate();

        expect(reactivated.isActive, true);
      });
    });

    group('copyWith', () {
      test('returns same instance when no parameters provided', () {
        final copy = timetable.copyWith();
        expect(copy, timetable);
      });

      test('allows updating single field', () {
        final updated = timetable.copyWith(
          status: 'published',
        );

        expect(updated.status, 'published');
        expect(updated.id, timetable.id);
        expect(updated.examName, timetable.examName);
      });

      test('allows nullifying optional fields', () {
        final updated = timetable.copyWith(
          examCalendarId: null,
          examNumber: null,
          publishedAt: null,
          metadata: null,
        );

        expect(updated.examCalendarId, isNull);
        expect(updated.examNumber, isNull);
        expect(updated.publishedAt, isNull);
        expect(updated.metadata, isNull);
      });
    });

    group('toJson and fromJson', () {
      test('toJson serializes all fields', () {
        final json = timetable.toJson();

        expect(json['id'], 'timetable-123');
        expect(json['tenant_id'], 'tenant-456');
        expect(json['created_by'], 'admin-789');
        expect(json['exam_calendar_id'], 'calendar-111');
        expect(json['exam_name'], 'Mid-term Exams');
        expect(json['status'], 'draft');
        expect(json['is_active'], true);
      });

      test('fromJson deserializes correctly', () {
        final json = timetable.toJson();
        final deserialized = ExamTimetableEntity.fromJson(json);

        expect(deserialized.id, timetable.id);
        expect(deserialized.examName, timetable.examName);
        expect(deserialized.status, timetable.status);
        expect(deserialized.academicYear, timetable.academicYear);
      });

      test('round-trip preserves equality', () {
        final json = timetable.toJson();
        final deserialized = ExamTimetableEntity.fromJson(json);

        expect(deserialized, timetable);
      });

      test('fromJson handles default values', () {
        final minimal = {
          'id': 'timetable-1',
          'tenant_id': 'tenant-1',
          'created_by': 'admin-1',
          'exam_name': 'Test',
          'exam_type': 'mid_term',
          'academic_year': '2025-2026',
          'created_at': '2025-01-01T00:00:00.000Z',
          'updated_at': '2025-01-01T00:00:00.000Z',
        };

        final entity = ExamTimetableEntity.fromJson(minimal);

        expect(entity.status, 'draft'); // Default
        expect(entity.isActive, true); // Default
        expect(entity.examCalendarId, isNull);
        expect(entity.publishedAt, isNull);
      });
    });

    group('equality', () {
      test('two timetables with same values are equal', () {
        final timetable1 = ExamTimetableEntity(
          id: 'timetable-123',
          tenantId: 'tenant-456',
          createdBy: 'admin-789',
          examName: 'Mid-term Exams',
          examType: 'mid_term',
          academicYear: '2025-2026',
          createdAt: now,
          updatedAt: now,
        );

        final timetable2 = ExamTimetableEntity(
          id: 'timetable-123',
          tenantId: 'tenant-456',
          createdBy: 'admin-789',
          examName: 'Mid-term Exams',
          examType: 'mid_term',
          academicYear: '2025-2026',
          createdAt: now,
          updatedAt: now,
        );

        expect(timetable1, timetable2);
        expect(timetable1.hashCode, timetable2.hashCode);
      });

      test('timetables with different ids are not equal', () {
        final other = timetable.copyWith(id: 'different-id');
        expect(timetable, isNot(other));
      });

      test('timetables with different status are not equal', () {
        final other = timetable.copyWith(status: 'published');
        expect(timetable, isNot(other));
      });
    });

    group('toString', () {
      test('returns readable string representation', () {
        final str = timetable.toString();

        expect(str, contains('ExamTimetableEntity'));
        expect(str, contains('timetable-123'));
        expect(str, contains('Mid-term Exams'));
        expect(str, contains('2025-2026'));
        expect(str, contains('draft'));
      });
    });

    group('workflow validation', () {
      test('can transition from draft to published', () {
        final published = timetable.markAsPublished();

        expect(published.status, 'published');
        expect(timetable.status, 'draft'); // Original unchanged
      });

      test('can transition from published to archived', () {
        final published = timetable.markAsPublished();
        final archived = published.markAsArchived();

        expect(archived.status, 'archived');
      });

      test('draft timetable can be deleted and reactivated', () {
        final deleted = timetable.softDelete();
        final reactivated = deleted.reactivate();

        expect(deleted.isActive, false);
        expect(reactivated.isActive, true);
      });
    });

    group('immutability', () {
      test('original object unchanged after modifications', () {
        final original = timetable;
        final modified = original.copyWith(
          status: 'published',
          isActive: false,
        );

        expect(original.status, 'draft');
        expect(original.isActive, true);
        expect(modified.status, 'published');
        expect(modified.isActive, false);
      });
    });
  });
}
