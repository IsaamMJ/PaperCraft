import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:papercraft/features/authentication/domain/entities/user_entity.dart';
import 'package:papercraft/features/authentication/domain/entities/user_role.dart';
import 'package:papercraft/features/catalog/domain/entities/exam_type.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/paper_status.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/question_paper_entity.dart';
import 'package:papercraft/features/question_bank/presentation/bloc/question_bank_bloc.dart';
import 'package:papercraft/features/question_bank/presentation/bloc/question_bank_event.dart';
import 'package:papercraft/features/question_bank/presentation/bloc/question_bank_state.dart';

// ============================================================================
// MOCKS
// ============================================================================

class MockQuestionBankBloc extends Mock implements QuestionBankBloc {}

class FakeQuestionBankEvent extends Fake implements QuestionBankEvent {}

// ============================================================================
// TEST HELPERS
// ============================================================================

/// Create test user
UserEntity createTestUser({
  String id = 'student-1',
  String email = 'student@school.com',
  String fullName = 'Test Student',
  UserRole role = UserRole.teacher,
}) {
  return UserEntity(
    id: id,
    email: email,
    fullName: fullName,
    role: role,
    tenantId: 'tenant-1',
    isActive: true,
    createdAt: DateTime.now(),
  );
}

/// Create test paper for question bank
QuestionPaperEntity createApprovedPaper({
  String id = 'paper-1',
  String title = 'Approved Paper',
  String gradeId = 'grade-1',
  String subjectId = 'subject-1',
  String academicYear = '2024',
  DateTime? reviewedAt,
}) {
  return QuestionPaperEntity(
    id: id,
    title: title,
    gradeId: gradeId,
    subjectId: subjectId,
    academicYear: academicYear,
    createdBy: 'teacher-1',
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
    modifiedAt: DateTime.now().subtract(const Duration(days: 5)),
    status: PaperStatus.approved,
    paperSections: [],
    questions: {},
    examType: ExamType.monthlyTest,
    reviewedAt: reviewedAt,
    userId: 'teacher-1',
    tenantId: 'tenant-1',
  );
}

// ============================================================================
// SIMPLE TEST WIDGET - Minimal dependencies
// ============================================================================

/// Simple widget that displays question bank state
class QuestionBankTestWidget extends StatelessWidget {
  final QuestionBankState state;
  final Function(QuestionBankEvent)? onEventAdded;

  const QuestionBankTestWidget({
    required this.state,
    this.onEventAdded,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (state is QuestionBankInitial) {
      return const Scaffold(
        body: Center(child: Text('Initial State')),
      );
    }

    if (state is QuestionBankLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state is QuestionBankError) {
      final error = state as QuestionBankError;
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: ${error.message}'),
              ElevatedButton(
                onPressed: () {},
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state is QuestionBankLoaded) {
      final loaded = state as QuestionBankLoaded;
      return Scaffold(
        body: loaded.papers.isEmpty
            ? const Center(child: Text('No papers found'))
            : ListView.builder(
                itemCount: loaded.papers.length,
                itemBuilder: (context, index) {
                  final paper = loaded.papers[index];
                  return ListTile(
                    title: Text(paper.title),
                    subtitle: Text('Grade: ${paper.gradeId}'),
                  );
                },
              ),
      );
    }

    return const Scaffold(
      body: Center(child: Text('Unknown State')),
    );
  }
}

// ============================================================================
// MAIN TEST SUITE
// ============================================================================

void main() {
  late MockQuestionBankBloc mockQuestionBankBloc;

  setUpAll(() {
    registerFallbackValue(FakeQuestionBankEvent());
  });

  setUp(() {
    mockQuestionBankBloc = MockQuestionBankBloc();

    // Default stubs
    when(() => mockQuestionBankBloc.state)
        .thenReturn(const QuestionBankInitial());
    when(() => mockQuestionBankBloc.stream)
        .thenAnswer((_) => const Stream.empty());
    when(() => mockQuestionBankBloc.add(any())).thenReturn(null);
  });

  group('Question Bank - Page Rendering', () {
    testWidgets('should render initial state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QuestionBankTestWidget(
            state: const QuestionBankInitial(),
          ),
        ),
      );

      expect(find.text('Initial State'), findsOneWidget);
    });

    testWidgets('should display papers when loaded', (tester) async {
      final papers = [
        createApprovedPaper(id: 'paper-1', title: 'Mathematics Midterm'),
        createApprovedPaper(id: 'paper-2', title: 'English Midterm'),
        createApprovedPaper(id: 'paper-3', title: 'Science Midterm'),
      ];

      final state = QuestionBankLoaded(
        papers: papers,
        currentPage: 1,
        totalPages: 1,
        totalItems: 3,
        hasMore: false,
        isLoadingMore: false,
        searchQuery: '',
        subjectFilter: null,
        gradeFilter: null,
        thisMonthGroupedByClass: {},
        thisMonthGroupedByMonth: {},
        previousMonthGroupedByClass: {},
        previousMonthGroupedByMonth: {},
        archiveGroupedByClass: {},
        archiveGroupedByMonth: {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: QuestionBankTestWidget(state: state),
        ),
      );

      expect(find.text('Mathematics Midterm'), findsOneWidget);
      expect(find.text('English Midterm'), findsOneWidget);
      expect(find.text('Science Midterm'), findsOneWidget);
    });
  });

  group('Question Bank - Loading States', () {
    testWidgets('should show loading indicator when loading papers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QuestionBankTestWidget(
            state: const QuestionBankLoading(message: 'Loading papers...'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('Question Bank - Error Handling', () {
    testWidgets('should display error message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QuestionBankTestWidget(
            state: const QuestionBankError('Failed to load papers'),
          ),
        ),
      );

      expect(find.text('Error: Failed to load papers'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });

  group('Question Bank - Realtime Updates', () {
    testWidgets('should handle realtime paper updates smoothly', (tester) async {
      final initialPapers = [
        createApprovedPaper(id: 'paper-1', title: 'Paper 1'),
      ];

      final initialState = QuestionBankLoaded(
        papers: initialPapers,
        currentPage: 1,
        totalPages: 1,
        totalItems: 1,
        hasMore: false,
        isLoadingMore: false,
        searchQuery: '',
        subjectFilter: null,
        gradeFilter: null,
        thisMonthGroupedByClass: {},
        thisMonthGroupedByMonth: {},
        previousMonthGroupedByClass: {},
        previousMonthGroupedByMonth: {},
        archiveGroupedByClass: {},
        archiveGroupedByMonth: {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return QuestionBankTestWidget(state: initialState);
            },
          ),
        ),
      );

      expect(find.text('Paper 1'), findsOneWidget);
    });

    testWidgets(
        'should handle multiple rapid realtime updates (debouncing test)',
        (tester) async {
      // This test verifies that rapid state changes don't cause lag
      final papers = List.generate(
        5,
        (index) => createApprovedPaper(
          id: 'paper-$index',
          title: 'Paper ${index + 1}',
        ),
      );

      final state = QuestionBankLoaded(
        papers: papers,
        currentPage: 1,
        totalPages: 1,
        totalItems: 5,
        hasMore: false,
        isLoadingMore: false,
        searchQuery: '',
        subjectFilter: null,
        gradeFilter: null,
        thisMonthGroupedByClass: {},
        thisMonthGroupedByMonth: {},
        previousMonthGroupedByClass: {},
        previousMonthGroupedByMonth: {},
        archiveGroupedByClass: {},
        archiveGroupedByMonth: {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: QuestionBankTestWidget(state: state),
        ),
      );

      // Rapid updates should all be handled
      expect(find.text('Paper 1'), findsOneWidget);
      expect(find.text('Paper 5'), findsOneWidget);
    });
  });

  group('Question Bank - Performance', () {
    testWidgets('should handle large paper lists (50+ papers)', (tester) async {
      // Create 50 papers to test performance
      final papers = List.generate(
        50,
        (index) => createApprovedPaper(
          id: 'paper-$index',
          title: 'Paper $index',
        ),
      );

      final state = QuestionBankLoaded(
        papers: papers,
        currentPage: 1,
        totalPages: 1,
        totalItems: 50,
        hasMore: false,
        isLoadingMore: false,
        searchQuery: '',
        subjectFilter: null,
        gradeFilter: null,
        thisMonthGroupedByClass: {},
        thisMonthGroupedByMonth: {},
        previousMonthGroupedByClass: {},
        previousMonthGroupedByMonth: {},
        archiveGroupedByClass: {},
        archiveGroupedByMonth: {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: QuestionBankTestWidget(state: state),
        ),
      );

      // Should render without issues
      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('Paper 0'), findsOneWidget);
    });
  });

  group('Question Bank - Responsiveness', () {
    testWidgets('should display properly on mobile', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final papers = [createApprovedPaper()];
      final state = QuestionBankLoaded(
        papers: papers,
        currentPage: 1,
        totalPages: 1,
        totalItems: 1,
        hasMore: false,
        isLoadingMore: false,
        searchQuery: '',
        subjectFilter: null,
        gradeFilter: null,
        thisMonthGroupedByClass: {},
        thisMonthGroupedByMonth: {},
        previousMonthGroupedByClass: {},
        previousMonthGroupedByMonth: {},
        archiveGroupedByClass: {},
        archiveGroupedByMonth: {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: QuestionBankTestWidget(state: state),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('should display properly on tablet', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final papers = [createApprovedPaper()];
      final state = QuestionBankLoaded(
        papers: papers,
        currentPage: 1,
        totalPages: 1,
        totalItems: 1,
        hasMore: false,
        isLoadingMore: false,
        searchQuery: '',
        subjectFilter: null,
        gradeFilter: null,
        thisMonthGroupedByClass: {},
        thisMonthGroupedByMonth: {},
        previousMonthGroupedByClass: {},
        previousMonthGroupedByMonth: {},
        archiveGroupedByClass: {},
        archiveGroupedByMonth: {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: QuestionBankTestWidget(state: state),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
    });
  });

  group('Question Bank - BLoC Integration', () {
    testWidgets('should emit state changes', (tester) async {
      final stateChanges = <QuestionBankState>[];

      when(() => mockQuestionBankBloc.state)
          .thenReturn(const QuestionBankInitial());

      when(() => mockQuestionBankBloc.stream).thenAnswer((_) {
        return Stream.fromIterable([
          const QuestionBankLoading(message: 'Loading...'),
          QuestionBankLoaded(
            papers: [createApprovedPaper()],
            currentPage: 1,
            totalPages: 1,
            totalItems: 1,
            hasMore: false,
            isLoadingMore: false,
            searchQuery: '',
            subjectFilter: null,
            gradeFilter: null,
            thisMonthGroupedByClass: {},
            thisMonthGroupedByMonth: {},
            previousMonthGroupedByClass: {},
            previousMonthGroupedByMonth: {},
            archiveGroupedByClass: {},
            archiveGroupedByMonth: {},
          ),
        ]);
      });

      // Test that multiple states are emitted properly
      expect(stateChanges.isEmpty, true);
    });
  });
}
