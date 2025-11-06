import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/features/assignments/data/datasources/teacher_assignment_datasource.dart';
import 'package:papercraft/features/assignments/data/repositories/teacher_assignment_repository_impl.dart';
import 'package:papercraft/features/assignments/domain/entities/teacher_subject_assignment_entity.dart';

class MockTeacherAssignmentDataSource extends Mock
    implements TeacherAssignmentDataSource {}

class FakeTeacherSubjectAssignmentEntity extends Fake
    implements TeacherSubjectAssignmentEntity {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeTeacherSubjectAssignmentEntity());
  });
  final now = DateTime(2025, 1, 15, 10, 30, 0);

  final testAssignment = TeacherSubjectAssignmentEntity(
    id: 'assign-123',
    tenantId: 'tenant-456',
    teacherId: 'teacher-789',
    gradeId: 'grade-101',
    subjectId: 'subject-202',
    teacherName: 'John Doe',
    teacherEmail: 'john@school.com',
    gradeNumber: 2,
    section: 'A',
    subjectName: 'Mathematics',
    academicYear: '2025-2026',
    isActive: true,
    createdAt: now,
  );

  test('getTeacherAssignments returns assignments', () async {
    final mock = MockTeacherAssignmentDataSource();
    final repo = TeacherAssignmentRepositoryImpl(dataSource: mock);

    when(() => mock.getTeacherAssignments(
      tenantId: 'tenant-456',
      teacherId: 'teacher-789',
      academicYear: '2025-2026',
      activeOnly: true,
    )).thenAnswer((_) async => [testAssignment]);

    final result = await repo.getTeacherAssignments(
      tenantId: 'tenant-456',
      teacherId: 'teacher-789',
    );

    expect(result.isRight(), true);
    expect(result.fold((f) => null, (a) => a.length), 1);
  });

  test('getTeacherAssignments handles empty list', () async {
    final mock = MockTeacherAssignmentDataSource();
    final repo = TeacherAssignmentRepositoryImpl(dataSource: mock);

    when(() => mock.getTeacherAssignments(
      tenantId: 'tenant-456',
      teacherId: null,
      academicYear: '2025-2026',
      activeOnly: true,
    )).thenAnswer((_) async => []);

    final result = await repo.getTeacherAssignments(tenantId: 'tenant-456');

    expect(result.isRight(), true);
    expect(result.fold((f) => -1, (a) => a.length), 0);
  });

  test('getTeacherAssignments handles exceptions', () async {
    final mock = MockTeacherAssignmentDataSource();
    final repo = TeacherAssignmentRepositoryImpl(dataSource: mock);

    when(() => mock.getTeacherAssignments(
      tenantId: 'tenant-456',
      teacherId: null,
      academicYear: '2025-2026',
      activeOnly: true,
    )).thenThrow(Exception('Database error'));

    final result = await repo.getTeacherAssignments(tenantId: 'tenant-456');

    expect(result.isLeft(), true);
    expect(result.fold((f) => f.runtimeType, (a) => null), ServerFailure);
  });

  test('getAssignmentStats returns stats', () async {
    final mock = MockTeacherAssignmentDataSource();
    final repo = TeacherAssignmentRepositoryImpl(dataSource: mock);

    when(() => mock.getAssignmentStats(
      tenantId: 'tenant-456',
      academicYear: '2025-2026',
    )).thenAnswer((_) async => {'2:A': 3, '2:B': 2});

    final result = await repo.getAssignmentStats(tenantId: 'tenant-456');

    expect(result.isRight(), true);
    result.fold(
      (f) => fail('Should be right'),
      (stats) => expect(stats.length, 2),
    );
  });

  test('getAssignmentStats handles empty map', () async {
    final mock = MockTeacherAssignmentDataSource();
    final repo = TeacherAssignmentRepositoryImpl(dataSource: mock);

    when(() => mock.getAssignmentStats(
      tenantId: 'tenant-456',
      academicYear: '2025-2026',
    )).thenAnswer((_) async => {});

    final result = await repo.getAssignmentStats(tenantId: 'tenant-456');

    expect(result.isRight(), true);
    expect(result.fold((f) => -1, (s) => s.length), 0);
  });

  test('saveAssignment saves valid assignment', () async {
    final mock = MockTeacherAssignmentDataSource();
    final repo = TeacherAssignmentRepositoryImpl(dataSource: mock);

    when(() => mock.saveAssignment(any())).thenAnswer((_) async {});

    final result = await repo.saveAssignment(testAssignment);

    expect(result.isRight(), true);
    verify(() => mock.saveAssignment(testAssignment)).called(1);
  });

  test('saveAssignment rejects invalid assignment', () async {
    final mock = MockTeacherAssignmentDataSource();
    final repo = TeacherAssignmentRepositoryImpl(dataSource: mock);

    // Create invalid assignment without gradeNumber
    final invalid = TeacherSubjectAssignmentEntity(
      id: 'assign-invalid',
      tenantId: 'tenant-456',
      teacherId: 'teacher-789',
      gradeId: 'grade-101',
      subjectId: 'subject-202',
      teacherName: 'John Doe',
      teacherEmail: 'john@school.com',
      gradeNumber: null, // Missing required field
      section: 'A',
      subjectName: 'Mathematics',
      academicYear: '2025-2026',
      isActive: true,
      createdAt: DateTime.now(),
    );

    final result = await repo.saveAssignment(invalid);

    expect(result.isLeft(), true);
    expect(result.fold((f) => f.runtimeType, (u) => null), ValidationFailure);
    verifyNever(() => mock.saveAssignment(any()));
  });

  test('saveAssignment handles datasource exception', () async {
    final mock = MockTeacherAssignmentDataSource();
    final repo = TeacherAssignmentRepositoryImpl(dataSource: mock);

    when(() => mock.saveAssignment(any()))
        .thenThrow(Exception('Save failed'));

    final result = await repo.saveAssignment(testAssignment);

    expect(result.isLeft(), true);
    expect(result.fold((f) => f.runtimeType, (u) => null), ServerFailure);
  });

  test('deleteAssignment deletes successfully', () async {
    final mock = MockTeacherAssignmentDataSource();
    final repo = TeacherAssignmentRepositoryImpl(dataSource: mock);

    when(() => mock.deleteAssignment(any())).thenAnswer((_) async {});

    final result = await repo.deleteAssignment('assign-123');

    expect(result.isRight(), true);
    verify(() => mock.deleteAssignment('assign-123')).called(1);
  });

  test('deleteAssignment handles exception', () async {
    final mock = MockTeacherAssignmentDataSource();
    final repo = TeacherAssignmentRepositoryImpl(dataSource: mock);

    when(() => mock.deleteAssignment(any()))
        .thenThrow(Exception('Delete failed'));

    final result = await repo.deleteAssignment('assign-123');

    expect(result.isLeft(), true);
    expect(result.fold((f) => f.runtimeType, (u) => null), ServerFailure);
  });

  test('getAssignmentById returns assignment', () async {
    final mock = MockTeacherAssignmentDataSource();
    final repo = TeacherAssignmentRepositoryImpl(dataSource: mock);

    when(() => mock.getAssignmentById(any()))
        .thenAnswer((_) async => testAssignment);

    final result = await repo.getAssignmentById('assign-123');

    expect(result.isRight(), true);
    expect(result.fold((f) => null, (a) => a?.id), 'assign-123');
  });

  test('getAssignmentById returns null when not found', () async {
    final mock = MockTeacherAssignmentDataSource();
    final repo = TeacherAssignmentRepositoryImpl(dataSource: mock);

    when(() => mock.getAssignmentById(any())).thenAnswer((_) async => null);

    final result = await repo.getAssignmentById('nonexistent');

    expect(result.isRight(), true);
    expect(result.fold((f) => 'error', (a) => a), isNull);
  });

  test('getAssignmentsForTeacher returns assignments', () async {
    final mock = MockTeacherAssignmentDataSource();
    final repo = TeacherAssignmentRepositoryImpl(dataSource: mock);

    when(() => mock.getAssignmentsForTeacher(
      tenantId: 'tenant-456',
      teacherId: 'teacher-789',
      academicYear: '2025-2026',
    )).thenAnswer((_) async => [testAssignment]);

    final result = await repo.getAssignmentsForTeacher(
      tenantId: 'tenant-456',
      teacherId: 'teacher-789',
    );

    expect(result.isRight(), true);
    expect(result.fold((f) => -1, (a) => a.length), 1);
  });

  test('getAssignmentsForTeacher returns empty list', () async {
    final mock = MockTeacherAssignmentDataSource();
    final repo = TeacherAssignmentRepositoryImpl(dataSource: mock);

    when(() => mock.getAssignmentsForTeacher(
      tenantId: 'tenant-456',
      teacherId: 'teacher-789',
      academicYear: '2025-2026',
    )).thenAnswer((_) async => []);

    final result = await repo.getAssignmentsForTeacher(
      tenantId: 'tenant-456',
      teacherId: 'teacher-789',
    );

    expect(result.isRight(), true);
    expect(result.fold((f) => -1, (a) => a.length), 0);
  });

  test('assignment lifecycle: save, fetch, delete', () async {
    final mock = MockTeacherAssignmentDataSource();
    final repo = TeacherAssignmentRepositoryImpl(dataSource: mock);

    // Save
    when(() => mock.saveAssignment(testAssignment))
        .thenAnswer((_) async {});
    var result = await repo.saveAssignment(testAssignment);
    expect(result.isRight(), true);

    // Fetch
    when(() => mock.getAssignmentById('assign-123'))
        .thenAnswer((_) async => testAssignment);
    result = await repo.getAssignmentById('assign-123');
    expect(result.isRight(), true);

    // Delete
    when(() => mock.deleteAssignment('assign-123'))
        .thenAnswer((_) async {});
    result = await repo.deleteAssignment('assign-123');
    expect(result.isRight(), true);
  });

  test('multi-grade assignments retrieved correctly', () async {
    final mock = MockTeacherAssignmentDataSource();
    final repo = TeacherAssignmentRepositoryImpl(dataSource: mock);

    final assign2A = testAssignment;
    final assign2B = testAssignment.copyWith(id: 'assign-124', section: 'B');
    final assign5A = testAssignment.copyWith(
      id: 'assign-125',
      gradeNumber: 5,
      gradeId: 'grade-102',
      section: 'A',
    );

    when(() => mock.getTeacherAssignments(
      tenantId: 'tenant-456',
      teacherId: 'teacher-789',
      academicYear: '2025-2026',
      activeOnly: true,
    )).thenAnswer((_) async => [assign2A, assign2B, assign5A]);

    final result = await repo.getTeacherAssignments(
      tenantId: 'tenant-456',
      teacherId: 'teacher-789',
    );

    expect(result.isRight(), true);
    result.fold(
      (f) => fail('Should be right'),
      (assignments) {
        expect(assignments.length, 3);
        expect(assignments[0].gradeSection, '2:A');
        expect(assignments[1].gradeSection, '2:B');
        expect(assignments[2].gradeSection, '5:A');
      },
    );
  });
}
