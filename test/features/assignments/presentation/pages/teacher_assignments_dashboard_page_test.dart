// test/features/assignments/presentation/pages/teacher_assignments_dashboard_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:papercraft/features/assignments/domain/entities/teacher_subject_assignment_entity.dart';
import 'package:papercraft/features/assignments/presentation/bloc/teacher_assignment_bloc.dart';
import 'package:papercraft/features/assignments/presentation/pages/teacher_assignments_dashboard_page.dart';

// Mock BLoC
class MockTeacherAssignmentBloc
    extends Mock
    implements TeacherAssignmentBloc {}

void main() {
  late MockTeacherAssignmentBloc mockBloc;

  setUp(() {
    mockBloc = MockTeacherAssignmentBloc();
  });

  Widget _buildTestWidget() {
    return BlocProvider<TeacherAssignmentBloc>(
      create: (_) => mockBloc,
      child: const MaterialApp(
        home: TeacherAssignmentsDashboardPage(),
      ),
    );
  }

  testWidgets('Dashboard displays loading state', (WidgetTester tester) async {
    when(() => mockBloc.state)
        .thenReturn(const TeacherAssignmentsLoading());
    when(() => mockBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(_buildTestWidget());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Dashboard displays error state', (WidgetTester tester) async {
    when(() => mockBloc.state).thenReturn(
      const TeacherAssignmentError(errorMessage: 'Failed to load'),
    );
    when(() => mockBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(_buildTestWidget());

    expect(find.text('Failed to load'), findsOneWidget);
  });

  testWidgets('Dashboard displays empty state', (WidgetTester tester) async {
    when(() => mockBloc.state).thenReturn(
      TeacherAssignmentsLoaded(
        assignments: const [],
        stats: const {},
      ),
    );
    when(() => mockBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(_buildTestWidget());

    expect(find.text('No teachers found'), findsOneWidget);
  });

  testWidgets('Dashboard displays list of teachers', (WidgetTester tester) async {
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
        teacherId: 'teacher2',
        gradeId: 'grade1',
        subjectId: 'subject2',
        teacherName: 'Jane Smith',
        teacherEmail: 'jane@example.com',
        gradeNumber: 1,
        section: 'B',
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

    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('Jane Smith'), findsOneWidget);
  });

  testWidgets('Dashboard search filters teachers', (WidgetTester tester) async {
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
        teacherId: 'teacher2',
        gradeId: 'grade1',
        subjectId: 'subject2',
        teacherName: 'Jane Smith',
        teacherEmail: 'jane@example.com',
        gradeNumber: 1,
        section: 'B',
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

    // Type in search field
    await tester.enterText(find.byType(TextField), 'John');
    await tester.pumpWidget(_buildTestWidget());

    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('Jane Smith'), findsNothing);
  });

  testWidgets('Dashboard shows assignment counts', (WidgetTester tester) async {
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
        gradeId: 'grade2',
        subjectId: 'subject1',
        teacherName: 'John Doe',
        teacherEmail: 'john@example.com',
        gradeNumber: 2,
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

    // Should show count of 2 grades
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('Dashboard sends LoadTeacherAssignmentsEvent on init',
      (WidgetTester tester) async {
    when(() => mockBloc.state).thenReturn(const TeacherAssignmentInitial());
    when(() => mockBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(_buildTestWidget());

    verify(() => mockBloc.add(any<LoadTeacherAssignmentsEvent>())).called(1);
  });
}
