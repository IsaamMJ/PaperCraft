/// Test helpers and utilities for all tests

import 'package:flutter/material.dart';
import 'package:mockito/mockito.dart';

/// Base mock class helper
class MockHelper {
  /// Create a mock that implements an interface
  static T createMock<T>() {
    return Mock() as T;
  }
}

/// Common test data
class TestData {
  static const String testTenantId = 'tenant-test-123';
  static const String testTeacherId = 'teacher-test-123';
  static const String testAdminId = 'admin-test-123';
  static const String testGradeId = 'Grade 5';
  static const String testSubjectId = 'Maths';
  static const String testSection = 'A';
  static const String testAcademicYear = '2024-2025';

  static DateTime get testDateTime => DateTime(2024, 6, 15);
  static DateTime get futureDateTime => DateTime(2025, 6, 15);
}

/// Test data builders
class GradeSectionBuilder {
  String id = 'grade-section-1';
  String tenantId = TestData.testTenantId;
  String gradeId = TestData.testGradeId;
  String sectionName = 'A';
  int displayOrder = 1;
  bool isActive = true;
  late DateTime createdAt = TestData.testDateTime;
  late DateTime updatedAt = TestData.testDateTime;

  GradeSectionBuilder withSectionName(String value) {
    sectionName = value;
    return this;
  }

  GradeSectionBuilder withGradeId(String value) {
    gradeId = value;
    return this;
  }

  GradeSectionBuilder withIsActive(bool value) {
    isActive = value;
    return this;
  }

  Map<String, dynamic> buildJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'grade_id': gradeId,
      'section_name': sectionName,
      'display_order': displayOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class ExamTimetableBuilder {
  String id = 'timetable-1';
  String tenantId = TestData.testTenantId;
  String createdBy = TestData.testAdminId;
  String? examCalendarId = 'calendar-1';
  String examName = 'June Monthly Test';
  String examType = 'monthlyTest';
  int? examNumber = null;
  String academicYear = TestData.testAcademicYear;
  String status = 'draft';
  DateTime? publishedAt = null;
  bool isActive = true;
  Map<String, dynamic>? metadata = null;
  late DateTime createdAt = TestData.testDateTime;
  late DateTime updatedAt = TestData.testDateTime;

  ExamTimetableBuilder withStatus(String value) {
    status = value;
    return this;
  }

  ExamTimetableBuilder asAdHoc() {
    examCalendarId = null;
    examNumber = 1;
    return this;
  }

  ExamTimetableBuilder withExamName(String value) {
    examName = value;
    return this;
  }

  Map<String, dynamic> buildJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'created_by': createdBy,
      'exam_calendar_id': examCalendarId,
      'exam_name': examName,
      'exam_type': examType,
      'exam_number': examNumber,
      'academic_year': academicYear,
      'status': status,
      'published_at': publishedAt?.toIso8601String(),
      'is_active': isActive,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class ExamTimetableEntryBuilder {
  String id = 'entry-1';
  String tenantId = TestData.testTenantId;
  String timetableId = 'timetable-1';
  String gradeId = TestData.testGradeId;
  String subjectId = TestData.testSubjectId;
  String section = TestData.testSection;
  late DateTime examDate = TestData.futureDateTime;
  String startTime = '09:00';
  String endTime = '10:30';
  int durationMinutes = 90;
  bool isActive = true;
  late DateTime createdAt = TestData.testDateTime;
  late DateTime updatedAt = TestData.testDateTime;

  ExamTimetableEntryBuilder withGradeSubjectSection(
    String grade,
    String subject,
    String sec,
  ) {
    gradeId = grade;
    subjectId = subject;
    section = sec;
    return this;
  }

  ExamTimetableEntryBuilder withTimes(String start, String end) {
    startTime = start;
    endTime = end;
    return this;
  }

  Map<String, dynamic> buildJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'timetable_id': timetableId,
      'grade_id': gradeId,
      'subject_id': subjectId,
      'section': section,
      'exam_date': examDate.toIso8601String().split('T')[0],
      'start_time': startTime,
      'end_time': endTime,
      'duration_minutes': durationMinutes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class TeacherSubjectBuilder {
  String id = 'teacher-subject-1';
  String tenantId = TestData.testTenantId;
  String teacherId = TestData.testTeacherId;
  String gradeId = TestData.testGradeId;
  String subjectId = TestData.testSubjectId;
  String section = TestData.testSection;
  String academicYear = TestData.testAcademicYear;
  bool isActive = true;
  late DateTime createdAt = TestData.testDateTime;
  late DateTime updatedAt = TestData.testDateTime;

  TeacherSubjectBuilder withTeacherId(String value) {
    teacherId = value;
    return this;
  }

  TeacherSubjectBuilder withGradeSubjectSection(
    String grade,
    String subject,
    String sec,
  ) {
    gradeId = grade;
    subjectId = subject;
    section = sec;
    return this;
  }

  TeacherSubjectBuilder withAcademicYear(String value) {
    academicYear = value;
    return this;
  }

  TeacherSubjectBuilder withIsActive(bool value) {
    isActive = value;
    return this;
  }

  Map<String, dynamic> buildJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'teacher_id': teacherId,
      'grade_id': gradeId,
      'subject_id': subjectId,
      'section': section,
      'academic_year': academicYear,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class ExamCalendarBuilder {
  String id = 'calendar-1';
  String tenantId = TestData.testTenantId;
  String examName = 'June Monthly Test';
  String examType = 'monthlyTest';
  int monthNumber = 6;
  late DateTime plannedStartDate = TestData.futureDateTime;
  late DateTime plannedEndDate = TestData.futureDateTime.add(Duration(days: 5));
  DateTime? paperSubmissionDeadline;
  int displayOrder = 1;
  Map<String, dynamic>? metadata;
  bool isActive = true;
  late DateTime createdAt = TestData.testDateTime;
  late DateTime updatedAt = TestData.testDateTime;

  ExamCalendarBuilder withExamName(String value) {
    examName = value;
    return this;
  }

  ExamCalendarBuilder withMonthNumber(int value) {
    monthNumber = value;
    return this;
  }

  ExamCalendarBuilder withPlannedDates(DateTime start, DateTime end) {
    plannedStartDate = start;
    plannedEndDate = end;
    return this;
  }

  ExamCalendarBuilder withPaperSubmissionDeadline(DateTime? value) {
    paperSubmissionDeadline = value;
    return this;
  }

  ExamCalendarBuilder withDisplayOrder(int value) {
    displayOrder = value;
    return this;
  }

  ExamCalendarBuilder withIsActive(bool value) {
    isActive = value;
    return this;
  }

  Map<String, dynamic> buildJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'exam_name': examName,
      'exam_type': examType,
      'month_number': monthNumber,
      'planned_start_date': plannedStartDate.toIso8601String().split('T')[0],
      'planned_end_date': plannedEndDate.toIso8601String().split('T')[0],
      'paper_submission_deadline': paperSubmissionDeadline?.toIso8601String().split('T')[0],
      'display_order': displayOrder,
      'metadata': metadata,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
