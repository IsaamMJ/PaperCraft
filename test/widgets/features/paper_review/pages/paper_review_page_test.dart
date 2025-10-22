import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:papercraft/features/authentication/domain/entities/user_entity.dart';
import 'package:papercraft/features/authentication/domain/entities/user_role.dart';
import 'package:papercraft/features/authentication/domain/services/user_state_service.dart';
import 'package:papercraft/features/catalog/domain/entities/exam_type.dart';
import 'package:papercraft/features/catalog/domain/entities/paper_section_entity.dart';
import 'package:papercraft/features/paper_review/presentation/pages/paper_review_page.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/paper_status.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/question_entity.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/question_paper_entity.dart';
import 'package:papercraft/features/paper_workflow/presentation/bloc/question_paper_bloc.dart';


class MockQuestionPaperBloc extends Mock implements QuestionPaperBloc {}
class MockUserStateService extends Mock implements UserStateService {}

void main() {
  late MockQuestionPaperBloc mockQuestionPaperBloc;
  late MockUserStateService mockUserStateService;

  setUp(() {
    mockQuestionPaperBloc = MockQuestionPaperBloc();
    mockUserStateService = MockUserStateService();

    // Register UserStateService in GetIt
    if (!GetIt.instance.isRegistered<UserStateService>()) {
      GetIt.instance.registerSingleton<UserStateService>(mockUserStateService);
    }

    // Setup default user state service behavior
    when(() => mockUserStateService.currentUser).thenReturn(UserEntity(
      id: 'test-user-1',
      email: 'test@example.com',
      fullName: 'Test User',
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
      lastLoginAt: DateTime(2024, 1, 1),
    ));
    when(() => mockUserStateService.canApprovePapers()).thenReturn(true);
    when(() => mockUserStateService.isAdmin).thenReturn(true);

    when(() => mockQuestionPaperBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockQuestionPaperBloc.close()).thenAnswer((_) async {});
    registerFallbackValue(const LoadPaperById('test-id'));
  });

  tearDown(() async {
    await mockQuestionPaperBloc.close();
    await GetIt.instance.reset();
  });

  Widget createWidgetUnderTest({required QuestionPaperState state}) {
    when(() => mockQuestionPaperBloc.state).thenReturn(state);

    return MaterialApp(
      home: BlocProvider<QuestionPaperBloc>.value(
        value: mockQuestionPaperBloc,
        child: const PaperReviewPage(paperId: 'test-paper-id'),
      ),
    );
  }

  group('PaperReviewPage Widget Tests', () {
    testWidgets('shows loading indicator when paper is loading', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(state: QuestionPaperLoading()),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows paper details when loaded', (tester) async {
      final paper = QuestionPaperEntity(
        id: 'test-paper-id',
        title: 'Mathematics Final Exam',
        subjectId: 'subject-1',
        gradeId: 'grade-1',
        academicYear: '2024-2025',
        createdBy: 'teacher-1',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        status: PaperStatus.submitted,
        examType: ExamType.annualExam,
        paperSections: const [
          PaperSectionEntity(
            name: 'Section A',
            type: 'multiple_choice',
            questions: 10,
            marksPerQuestion: 2,
          ),
        ],
        questions: const {
          'Section A': [
            Question(
              text: 'What is 2+2?',
              type: 'multiple_choice',
              options: ['2', '3', '4', '5'],
              correctAnswer: '4',
              marks: 2,
            ),
          ],
        },
      );

      await tester.pumpWidget(
        createWidgetUnderTest(state: QuestionPaperLoaded(currentPaper: paper)),
      );
      await tester.pumpAndSettle();

      // Should show paper title
      expect(find.text('Mathematics Final Exam'), findsOneWidget);

      // Should show section
      expect(find.text('Section A'), findsOneWidget);

      // Should show question
      expect(find.textContaining('What is 2+2?'), findsOneWidget);
    });

    testWidgets('shows error message when loading fails', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          state: QuestionPaperError('Failed to load paper'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load paper'), findsOneWidget);
    });

    testWidgets('shows approve and reject buttons for submitted papers', (tester) async {
      final paper = QuestionPaperEntity(
        id: 'test-paper-id',
        title: 'Mathematics Test',
        subjectId: 'subject-1',
        gradeId: 'grade-1',
        academicYear: '2024-2025',
        createdBy: 'teacher-1',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        status: PaperStatus.submitted,
        examType: ExamType.monthlyTest,
        paperSections: const [
          PaperSectionEntity(
            name: 'Section A',
            type: 'multiple_choice',
            questions: 1,
            marksPerQuestion: 2,
          ),
        ],
        questions: const {
          'Section A': [
            Question(
              text: 'Question 1',
              type: 'multiple_choice',
              options: ['A', 'B'],
              correctAnswer: 'A',
              marks: 2,
            ),
          ],
        },
      );

      await tester.pumpWidget(
        createWidgetUnderTest(state: QuestionPaperLoaded(currentPaper: paper)),
      );
      await tester.pumpAndSettle();

      // Should show action buttons (approve/reject)
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });

    testWidgets('has back button', (tester) async {
      final paper = QuestionPaperEntity(
        id: 'test-paper-id',
        title: 'Test Paper',
        subjectId: 'subject-1',
        gradeId: 'grade-1',
        academicYear: '2024-2025',
        createdBy: 'teacher-1',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        status: PaperStatus.submitted,
        examType: ExamType.monthlyTest,
        paperSections: const [],
        questions: const {},
      );

      await tester.pumpWidget(
        createWidgetUnderTest(state: QuestionPaperLoaded(currentPaper: paper)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });
}
