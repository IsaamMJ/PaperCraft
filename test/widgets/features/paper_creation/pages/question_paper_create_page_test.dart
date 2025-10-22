import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:papercraft/core/infrastructure/di/injection_container.dart';
import 'package:papercraft/features/authentication/domain/entities/user_entity.dart';
import 'package:papercraft/features/authentication/domain/entities/user_role.dart';
import 'package:papercraft/features/authentication/domain/services/user_state_service.dart';
import 'package:papercraft/features/catalog/domain/entities/grade_entity.dart';
import 'package:papercraft/features/catalog/domain/entities/subject_entity.dart';
import 'package:papercraft/features/catalog/presentation/bloc/grade_bloc.dart';
import 'package:papercraft/features/catalog/presentation/bloc/subject_bloc.dart';
import 'package:papercraft/features/catalog/presentation/bloc/teacher_pattern_bloc.dart';
import 'package:papercraft/features/catalog/presentation/bloc/teacher_pattern_state.dart';
import 'package:papercraft/features/paper_creation/presentation/pages/question_paper_create_page.dart';

class MockGradeBloc extends Mock implements GradeBloc {}
class MockSubjectBloc extends Mock implements SubjectBloc {}
class MockTeacherPatternBloc extends Mock implements TeacherPatternBloc {}
class MockUserStateService extends Mock implements UserStateService {}

void main() {
  late MockGradeBloc mockGradeBloc;
  late MockSubjectBloc mockSubjectBloc;
  late MockTeacherPatternBloc mockTeacherPatternBloc;
  late MockUserStateService mockUserStateService;

  setUp(() {
    mockGradeBloc = MockGradeBloc();
    mockSubjectBloc = MockSubjectBloc();
    mockTeacherPatternBloc = MockTeacherPatternBloc();
    mockUserStateService = MockUserStateService();

    // Register UserStateService in GetIt
    if (!GetIt.instance.isRegistered<UserStateService>()) {
      GetIt.instance.registerSingleton<UserStateService>(mockUserStateService);
    }

    // Register TeacherPatternBloc factory in GetIt
    if (!GetIt.instance.isRegistered<TeacherPatternBloc>()) {
      GetIt.instance.registerFactory<TeacherPatternBloc>(() => mockTeacherPatternBloc);
    }

    // Setup default user state service behavior
    when(() => mockUserStateService.currentUser).thenReturn(UserEntity(
      id: 'test-user-1',
      email: 'test@example.com',
      fullName: 'Test User',
      role: UserRole.teacher,
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
      lastLoginAt: DateTime(2024, 1, 1),
    ));
    when(() => mockUserStateService.currentAcademicYear).thenReturn('2024-2025');

    when(() => mockGradeBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockSubjectBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockTeacherPatternBloc.stream).thenAnswer((_) => const Stream.empty());

    // Stub close methods
    when(() => mockGradeBloc.close()).thenAnswer((_) async {});
    when(() => mockSubjectBloc.close()).thenAnswer((_) async {});
    when(() => mockTeacherPatternBloc.close()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await mockGradeBloc.close();
    await mockSubjectBloc.close();
    await mockTeacherPatternBloc.close();
    await GetIt.instance.reset();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<GradeBloc>.value(value: mockGradeBloc),
          BlocProvider<SubjectBloc>.value(value: mockSubjectBloc),
          BlocProvider<TeacherPatternBloc>.value(value: mockTeacherPatternBloc),
        ],
        child: const QuestionPaperCreatePage(),
      ),
    );
  }

  group('QuestionPaperCreatePage Widget Tests', () {
    testWidgets('shows loading state initially', (tester) async {
      when(() => mockGradeBloc.state).thenReturn(GradeLoading());
      when(() => mockSubjectBloc.state).thenReturn(SubjectLoading());
      when(() => mockTeacherPatternBloc.state).thenReturn(TeacherPatternLoading());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows step 1 form when data loaded', (tester) async {
      final grades = [
        GradeEntity(
          id: 'grade-1',
          gradeNumber: 1,
          tenantId: 'tenant-1',
          isActive: true,
          createdAt: DateTime(2024, 1, 1),
        ),
      ];

      final subjects = [
        SubjectEntity(
          id: 'subject-1',
          catalogSubjectId: 'catalog-1',
          name: 'Mathematics',
          tenantId: 'tenant-1',
          isActive: true,
          createdAt: DateTime(2024, 1, 1),
        ),
      ];

      when(() => mockGradeBloc.state).thenReturn(GradesLoaded(grades));
      when(() => mockSubjectBloc.state).thenReturn(SubjectsLoaded(subjects));
      when(() => mockTeacherPatternBloc.state).thenReturn(const TeacherPatternLoaded(patterns: []));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Should show step indicator
      expect(find.text('Step 1 of 2'), findsOneWidget);

      // Should show form fields
      expect(find.text('Paper Details'), findsOneWidget);
    });

    testWidgets('shows subject dropdown with loaded subjects', (tester) async {
      final grades = [
        GradeEntity(
          id: 'grade-1',
          gradeNumber: 1,
          tenantId: 'tenant-1',
          isActive: true,
          createdAt: DateTime(2024, 1, 1),
        ),
      ];

      final subjects = [
        SubjectEntity(
          id: 'subject-1',
          catalogSubjectId: 'catalog-1',
          name: 'Mathematics',
          tenantId: 'tenant-1',
          isActive: true,
          createdAt: DateTime(2024, 1, 1),
        ),
        SubjectEntity(
          id: 'subject-2',
          catalogSubjectId: 'catalog-2',
          name: 'Science',
          tenantId: 'tenant-1',
          isActive: true,
          createdAt: DateTime(2024, 1, 1),
        ),
      ];

      when(() => mockGradeBloc.state).thenReturn(GradesLoaded(grades));
      when(() => mockSubjectBloc.state).thenReturn(SubjectsLoaded(subjects));
      when(() => mockTeacherPatternBloc.state).thenReturn(const TeacherPatternLoaded(patterns: []));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Find subject dropdown
      expect(find.text('Subject'), findsOneWidget);
    });

    testWidgets('shows grade dropdown with loaded grades', (tester) async {
      final grades = [
        GradeEntity(
          id: 'grade-1',
          gradeNumber: 1,
          tenantId: 'tenant-1',
          isActive: true,
          createdAt: DateTime(2024, 1, 1),
        ),
        GradeEntity(
          id: 'grade-2',
          gradeNumber: 2,
          tenantId: 'tenant-1',
          isActive: true,
          createdAt: DateTime(2024, 1, 1),
        ),
      ];

      final subjects = [
        SubjectEntity(
          id: 'subject-1',
          catalogSubjectId: 'catalog-1',
          name: 'Mathematics',
          tenantId: 'tenant-1',
          isActive: true,
          createdAt: DateTime(2024, 1, 1),
        ),
      ];

      when(() => mockGradeBloc.state).thenReturn(GradesLoaded(grades));
      when(() => mockSubjectBloc.state).thenReturn(SubjectsLoaded(subjects));
      when(() => mockTeacherPatternBloc.state).thenReturn(const TeacherPatternLoaded(patterns: []));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Find grade dropdown
      expect(find.text('Grade'), findsOneWidget);
    });

    testWidgets('shows error state when loading fails', (tester) async {
      when(() => mockGradeBloc.state).thenReturn(GradeError('Failed to load grades'));
      when(() => mockSubjectBloc.state).thenReturn(SubjectInitial());
      when(() => mockTeacherPatternBloc.state).thenReturn(TeacherPatternInitial());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Failed to load grades'), findsOneWidget);
    });

    testWidgets('has back button', (tester) async {
      final grades = [
        GradeEntity(
          id: 'grade-1',
          gradeNumber: 1,
          tenantId: 'tenant-1',
          isActive: true,
          createdAt: DateTime(2024, 1, 1),
        ),
      ];

      final subjects = [
        SubjectEntity(
          id: 'subject-1',
          catalogSubjectId: 'catalog-1',
          name: 'Mathematics',
          tenantId: 'tenant-1',
          isActive: true,
          createdAt: DateTime(2024, 1, 1),
        ),
      ];

      when(() => mockGradeBloc.state).thenReturn(GradesLoaded(grades));
      when(() => mockSubjectBloc.state).thenReturn(SubjectsLoaded(subjects));
      when(() => mockTeacherPatternBloc.state).thenReturn(const TeacherPatternLoaded(patterns: []));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Should have back button
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });
}
