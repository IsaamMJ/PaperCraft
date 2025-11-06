// test/features/assignments/presentation/pages/teacher_assignment_detail_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:papercraft/features/assignments/domain/entities/teacher_subject_assignment_entity.dart';
import 'package:papercraft/features/assignments/presentation/bloc/teacher_assignment_bloc.dart';
import 'package:papercraft/features/assignments/presentation/pages/teacher_assignment_detail_page_new.dart';
import 'package:papercraft/features/authentication/domain/entities/user_entity.dart';

// Mock BLoC
class MockTeacherAssignmentBloc
    extends Mock
    implements TeacherAssignmentBloc {}

void main() {
  late MockTeacherAssignmentBloc mockBloc;
  late UserEntity testTeacher;

  setUp(() {
    mockBloc = MockTeacherAssignmentBloc();
    testTeacher = UserEntity(
      id: 'teacher1',
      email: 'john@example.com',
      fullName: 'John Doe',
      role: 'teacher',
      tenantId: 'tenant1',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  });

  Widget _buildTestWidget() {
    return BlocProvider<TeacherAssignmentBloc>(
      create: (_) => mockBloc,
      child: MaterialApp(
        home: TeacherAssignmentDetailPageNew(teacher: testTeacher),
      ),
    );
  }

  testWidgets('Detail page displays loading state', (WidgetTester tester) async {
    when(() => mockBloc.state)
        .thenReturn(const TeacherAssignmentsLoading());
    when(() => mockBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(_buildTestWidget());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Detail page displays error state', (WidgetTester tester) async {
    when(() => mockBloc.state).thenReturn(
      const TeacherAssignmentError(errorMessage: 'Failed to load'),
    );
    when(() => mockBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(_buildTestWidget());

    expect(find.text('Failed to load'), findsOneWidget);
  });

  testWidgets('Detail page displays empty state', (WidgetTester tester) async {
    when(() => mockBloc.state).thenReturn(
      TeacherAssignmentsLoaded(
        assignments: const [],
        stats: const {},
      ),
    );
    when(() => mockBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(_buildTestWidget());

    expect(find.text('No Assignments'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('Detail page groups assignments by grade+section',
      (WidgetTester tester) async {
    final testAssignments = [
      TeacherSubjectAssignmentEntity(
        id: '1',
        tenantId: 'tenant1',
        teacherId: 'teacher1',
        gradeId: 'grade1',
        subjectId: 'subject1',
        teacherName: 'John Doe',
        teacherEmail: 'john@example.com',
        gradeNumber: 1,
        section: 'A',
        subjectName: 'Mathematics',
        academicYear: '2025-2026',
        isActive: true,
        createdAt: DateTime.now(),
      ),
      TeacherSubjectAssignmentEntity(
        id: '2',
        tenantId: 'tenant1',
        teacherId: 'teacher1',
        gradeId: 'grade1',
        subjectId: 'subject2',
        teacherName: 'John Doe',
        teacherEmail: 'john@example.com',
        gradeNumber: 1,
        section: 'A',
        subjectName: 'English',
        academicYear: '2025-2026',
        isActive: true,
        createdAt: DateTime.now(),
      ),
      TeacherSubjectAssignmentEntity(
        id: '3',
        tenantId: 'tenant1',
        teacherId: 'teacher1',
        gradeId: 'grade1',
        subjectId: 'subject1',
        teacherName: 'John Doe',
        teacherEmail: 'john@example.com',
        gradeNumber: 1,
        section: 'B',
        subjectName: 'Mathematics',
        academicYear: '2025-2026',
        isActive: true,
        createdAt: DateTime.now(),
      ),
    ];

    when(() => mockBloc.state).thenReturn(
      TeacherAssignmentsLoaded(
        assignments: testAssignments,
        stats: const {},
      ),
    );
    when(() => mockBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(_buildTestWidget());

    // Should find Grade 1 headers
    expect(find.text('Grade 1:A'), findsOneWidget);
    expect(find.text('Grade 1:B'), findsOneWidget);
  });

  testWidgets('Detail page displays all subjects in a group',
      (WidgetTester tester) async {
    final testAssignments = [
      TeacherSubjectAssignmentEntity(
        id: '1',
        tenantId: 'tenant1',
        teacherId: 'teacher1',
        gradeId: 'grade1',
        subjectId: 'subject1',
        teacherName: 'John Doe',
        teacherEmail: 'john@example.com',
        gradeNumber: 1,
        section: 'A',
        subjectName: 'Mathematics',
        academicYear: '2025-2026',
        isActive: true,
        createdAt: DateTime.now(),
      ),
      TeacherSubjectAssignmentEntity(
        id: '2',
        tenantId: 'tenant1',
        teacherId: 'teacher1',
        gradeId: 'grade1',
        subjectId: 'subject2',
        teacherName: 'John Doe',
        teacherEmail: 'john@example.com',
        gradeNumber: 1,
        section: 'A',
        subjectName: 'English',
        academicYear: '2025-2026',
        isActive: true,
        createdAt: DateTime.now(),
      ),
    ];

    when(() => mockBloc.state).thenReturn(
      TeacherAssignmentsLoaded(
        assignments: testAssignments,
        stats: const {},
      ),
    );
    when(() => mockBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(_buildTestWidget());

    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('Detail page shows subject count in header', (WidgetTester tester) async {
    final testAssignments = [
      TeacherSubjectAssignmentEntity(
        id: '1',
        tenantId: 'tenant1',
        teacherId: 'teacher1',
        gradeId: 'grade1',
        subjectId: 'subject1',
        teacherName: 'John Doe',
        teacherEmail: 'john@example.com',
        gradeNumber: 1,
        section: 'A',
        subjectName: 'Mathematics',
        academicYear: '2025-2026',
        isActive: true,
        createdAt: DateTime.now(),
      ),
      TeacherSubjectAssignmentEntity(
        id: '2',
        tenantId: 'tenant1',
        teacherId: 'teacher1',
        gradeId: 'grade1',
        subjectId: 'subject2',
        teacherName: 'John Doe',
        teacherEmail: 'john@example.com',
        gradeNumber: 1,
        section: 'A',
        subjectName: 'English',
        academicYear: '2025-2026',
        isActive: true,
        createdAt: DateTime.now(),
      ),
    ];

    when(() => mockBloc.state).thenReturn(
      TeacherAssignmentsLoaded(
        assignments: testAssignments,
        stats: const {},
      ),
    );
    when(() => mockBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(_buildTestWidget());

    // Count for Grade 1:A should be 2
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('Detail page has delete button on subjects', (WidgetTester tester) async {
    final testAssignments = [
      TeacherSubjectAssignmentEntity(
        id: '1',
        tenantId: 'tenant1',
        teacherId: 'teacher1',
        gradeId: 'grade1',
        subjectId: 'subject1',
        teacherName: 'John Doe',
        teacherEmail: 'john@example.com',
        gradeNumber: 1,
        section: 'A',
        subjectName: 'Mathematics',
        academicYear: '2025-2026',
        isActive: true,
        createdAt: DateTime.now(),
      ),
    ];

    when(() => mockBloc.state).thenReturn(
      TeacherAssignmentsLoaded(
        assignments: testAssignments,
        stats: const {},
      ),
    );
    when(() => mockBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(_buildTestWidget());

    // Find close icon (delete button)
    expect(find.byIcon(Icons.close), findsWidgets);
  });

  testWidgets('Detail page has Add Assignment FAB', (WidgetTester tester) async {
    when(() => mockBloc.state).thenReturn(
      TeacherAssignmentsLoaded(
        assignments: const [],
        stats: const {},
      ),
    );
    when(() => mockBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(_buildTestWidget());

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Add Assignment'), findsOneWidget);
  });

  testWidgets('Detail page shows teacher name in app bar', (WidgetTester tester) async {
    when(() => mockBloc.state).thenReturn(
      TeacherAssignmentsLoaded(
        assignments: const [],
        stats: const {},
      ),
    );
    when(() => mockBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(_buildTestWidget());

    expect(find.text('John Doe'), findsOneWidget);
  });

  testWidgets('Detail page sends LoadTeacherAssignmentsEvent on init',
      (WidgetTester tester) async {
    when(() => mockBloc.state).thenReturn(const TeacherAssignmentInitial());
    when(() => mockBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(_buildTestWidget());

    // Verify LoadTeacherAssignmentsEvent was sent with teacher ID
    verify(() => mockBloc.add(any<LoadTeacherAssignmentsEvent>())).called(1);
  });

  testWidgets('Detail page shows snackbar on assignment saved',
      (WidgetTester tester) async {
    when(() => mockBloc.state)
        .thenReturn(const AssignmentSaved());
    when(() => mockBloc.stream).thenAnswer((_) => Stream.value(
          const AssignmentSaved(),
        ));

    await tester.pumpWidget(_buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
  });
}
