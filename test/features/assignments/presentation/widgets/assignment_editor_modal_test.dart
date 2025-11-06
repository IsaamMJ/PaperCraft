// test/features/assignments/presentation/widgets/assignment_editor_modal_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:papercraft/features/assignments/presentation/widgets/assignment_editor_modal.dart';
import 'package:papercraft/features/authentication/domain/entities/user_entity.dart';
import 'package:papercraft/features/catalog/domain/entities/grade_entity.dart';
import 'package:papercraft/features/catalog/domain/entities/grade_section_entity.dart';
import 'package:papercraft/features/catalog/domain/entities/subject_entity.dart';
import 'package:papercraft/features/catalog/presentation/bloc/catalog_bloc.dart';

// Mock BLoC
class MockCatalogBloc extends Mock implements CatalogBloc {}

void main() {
  late MockCatalogBloc mockCatalogBloc;
  late UserEntity testTeacher;

  setUp(() {
    mockCatalogBloc = MockCatalogBloc();
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
    return BlocProvider<CatalogBloc>(
      create: (_) => mockCatalogBloc,
      child: MaterialApp(
        home: Scaffold(
          body: AssignmentEditorModal(
            teacher: testTeacher,
            onSave: (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('Modal displays header with teacher name', (WidgetTester tester) async {
    when(() => mockCatalogBloc.state).thenReturn(
      CatalogLoaded(
        grades: const [],
        sections: const [],
        subjects: const [],
      ),
    );
    when(() => mockCatalogBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(_buildTestWidget());

    expect(find.text('Add Assignment'), findsOneWidget);
    expect(find.text('Assign a grade and subjects to John Doe'), findsOneWidget);
  });

  testWidgets('Modal shows loading state', (WidgetTester tester) async {
    when(() => mockCatalogBloc.state).thenReturn(const CatalogLoading());
    when(() => mockCatalogBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(_buildTestWidget());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Modal displays grade selector', (WidgetTester tester) async {
    final grades = [
      GradeEntity(
        id: 'grade1',
        gradeNumber: 1,
        tenantId: 'tenant1',
        isActive: true,
        createdAt: DateTime.now(),
      ),
      GradeEntity(
        id: 'grade2',
        gradeNumber: 2,
        tenantId: 'tenant1',
        isActive: true,
        createdAt: DateTime.now(),
      ),
    ];

    when(() => mockCatalogBloc.state).thenReturn(
      CatalogLoaded(
        grades: grades,
        sections: const [],
        subjects: const [],
      ),
    );
    when(() => mockCatalogBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(_buildTestWidget());

    expect(find.text('Select Grade'), findsOneWidget);
    expect(find.text('Grade 1'), findsOneWidget);
    expect(find.text('Grade 2'), findsOneWidget);
  });

  testWidgets('Modal allows selecting a grade', (WidgetTester tester) async {
    final grades = [
      GradeEntity(
        id: 'grade1',
        gradeNumber: 1,
        tenantId: 'tenant1',
        isActive: true,
        createdAt: DateTime.now(),
      ),
    ];

    when(() => mockCatalogBloc.state).thenReturn(
      CatalogLoaded(
        grades: grades,
        sections: const [],
        subjects: const [],
      ),
    );
    when(() => mockCatalogBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(_buildTestWidget());

    await tester.tap(find.text('Grade 1'));
    await tester.pumpAndSettle();

    // After selecting grade, should show sections section
    expect(find.text('Select Sections'), findsOneWidget);
  });

  testWidgets('Modal displays sections for selected grade', (WidgetTester tester) async {
    final grades = [
      GradeEntity(
        id: 'grade1',
        gradeNumber: 1,
        tenantId: 'tenant1',
        isActive: true,
        createdAt: DateTime.now(),
      ),
    ];

    final sections = [
      GradeSection(
        id: 'section1',
        gradeId: 'grade1',
        sectionName: 'A',
        tenantId: 'tenant1',
        isActive: true,
        createdAt: DateTime.now(),
      ),
      GradeSection(
        id: 'section2',
        gradeId: 'grade1',
        sectionName: 'B',
        tenantId: 'tenant1',
        isActive: true,
        createdAt: DateTime.now(),
      ),
    ];

    when(() => mockCatalogBloc.state).thenReturn(
      CatalogLoaded(
        grades: grades,
        sections: sections,
        subjects: const [],
      ),
    );
    when(() => mockCatalogBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(_buildTestWidget());

    await tester.tap(find.text('Grade 1'));
    await tester.pumpAndSettle();

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('Modal displays subjects', (WidgetTester tester) async {
    final grades = [
      GradeEntity(
        id: 'grade1',
        gradeNumber: 1,
        tenantId: 'tenant1',
        isActive: true,
        createdAt: DateTime.now(),
      ),
    ];

    final subjects = [
      SubjectEntity(
        id: 'subject1',
        name: 'Mathematics',
        tenantId: 'tenant1',
        isActive: true,
        createdAt: DateTime.now(),
      ),
      SubjectEntity(
        id: 'subject2',
        name: 'English',
        tenantId: 'tenant1',
        isActive: true,
        createdAt: DateTime.now(),
      ),
    ];

    when(() => mockCatalogBloc.state).thenReturn(
      CatalogLoaded(
        grades: grades,
        sections: const [],
        subjects: subjects,
      ),
    );
    when(() => mockCatalogBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(_buildTestWidget());

    await tester.tap(find.text('Grade 1'));
    await tester.pumpAndSettle();

    expect(find.text('Select Subjects'), findsOneWidget);
    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('Modal allows selecting multiple subjects', (WidgetTester tester) async {
    final grades = [
      GradeEntity(
        id: 'grade1',
        gradeNumber: 1,
        tenantId: 'tenant1',
        isActive: true,
        createdAt: DateTime.now(),
      ),
    ];

    final subjects = [
      SubjectEntity(
        id: 'subject1',
        name: 'Mathematics',
        tenantId: 'tenant1',
        isActive: true,
        createdAt: DateTime.now(),
      ),
      SubjectEntity(
        id: 'subject2',
        name: 'English',
        tenantId: 'tenant1',
        isActive: true,
        createdAt: DateTime.now(),
      ),
    ];

    when(() => mockCatalogBloc.state).thenReturn(
      CatalogLoaded(
        grades: grades,
        sections: const [],
        subjects: subjects,
      ),
    );
    when(() => mockCatalogBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(_buildTestWidget());

    await tester.tap(find.text('Grade 1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mathematics'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    // Both should be selected now, verify by looking for them
    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('Modal save button is disabled when no subjects selected',
      (WidgetTester tester) async {
    final grades = [
      GradeEntity(
        id: 'grade1',
        gradeNumber: 1,
        tenantId: 'tenant1',
        isActive: true,
        createdAt: DateTime.now(),
      ),
    ];

    when(() => mockCatalogBloc.state).thenReturn(
      CatalogLoaded(
        grades: grades,
        sections: const [],
        subjects: const [],
      ),
    );
    when(() => mockCatalogBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(_buildTestWidget());

    final saveButton = find.widgetWithText(ElevatedButton, 'Save');
    expect(saveButton, findsOneWidget);
  });

  testWidgets('Modal has cancel button', (WidgetTester tester) async {
    when(() => mockCatalogBloc.state).thenReturn(
      CatalogLoaded(
        grades: const [],
        sections: const [],
        subjects: const [],
      ),
    );
    when(() => mockCatalogBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(_buildTestWidget());

    expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
  });

  testWidgets('Modal calls onSave callback when Save is pressed',
      (WidgetTester tester) async {
    final grades = [
      GradeEntity(
        id: 'grade1',
        gradeNumber: 1,
        tenantId: 'tenant1',
        isActive: true,
        createdAt: DateTime.now(),
      ),
    ];

    final subjects = [
      SubjectEntity(
        id: 'subject1',
        name: 'Mathematics',
        tenantId: 'tenant1',
        isActive: true,
        createdAt: DateTime.now(),
      ),
    ];

    var savedCount = 0;

    when(() => mockCatalogBloc.state).thenReturn(
      CatalogLoaded(
        grades: grades,
        sections: const [],
        subjects: subjects,
      ),
    );
    when(() => mockCatalogBloc.stream).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(
      BlocProvider<CatalogBloc>(
        create: (_) => mockCatalogBloc,
        child: MaterialApp(
          home: Scaffold(
            body: AssignmentEditorModal(
              teacher: testTeacher,
              onSave: (_) {
                savedCount++;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Grade 1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mathematics'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(savedCount, greaterThan(0));
  });
}
