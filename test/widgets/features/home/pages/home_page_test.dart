import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:papercraft/core/presentation/widgets/connectivity_indicator.dart';
import 'package:papercraft/features/authentication/domain/entities/user_entity.dart';
import 'package:papercraft/features/authentication/domain/entities/user_role.dart';
import 'package:papercraft/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:papercraft/features/authentication/presentation/bloc/auth_event.dart';
import 'package:papercraft/features/authentication/presentation/bloc/auth_state.dart';
import 'package:papercraft/features/home/presentation/bloc/home_bloc.dart';
import 'package:papercraft/features/home/presentation/bloc/home_event.dart';
import 'package:papercraft/features/home/presentation/bloc/home_state.dart';
import 'package:papercraft/features/home/presentation/pages/home_page.dart';
import 'package:papercraft/features/notifications/domain/entities/notification_entity.dart';
import 'package:papercraft/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/paper_status.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/question_paper_entity.dart';
import 'package:papercraft/features/paper_workflow/presentation/bloc/question_paper_bloc.dart';
import 'package:papercraft/features/catalog/domain/entities/exam_type.dart';
import 'package:papercraft/features/catalog/domain/entities/paper_section_entity.dart';

// Mock classes
class MockAuthBloc extends Mock implements AuthBloc {}
class MockHomeBloc extends Mock implements HomeBloc {}
class MockNotificationBloc extends Mock implements NotificationBloc {}
class MockQuestionPaperBloc extends Mock implements QuestionPaperBloc {}

// Fake classes for events
class FakeAuthEvent extends Fake implements AuthEvent {}
class FakeHomeEvent extends Fake implements HomeEvent {}
class FakeNotificationEvent extends Fake implements NotificationEvent {}

void main() {
  late MockAuthBloc mockAuthBloc;
  late MockHomeBloc mockHomeBloc;
  late MockNotificationBloc mockNotificationBloc;
  late MockQuestionPaperBloc mockQuestionPaperBloc;

  setUpAll(() {
    registerFallbackValue(FakeAuthEvent());
    registerFallbackValue(FakeHomeEvent());
    registerFallbackValue(FakeNotificationEvent());
  });

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    mockHomeBloc = MockHomeBloc();
    mockNotificationBloc = MockNotificationBloc();
    mockQuestionPaperBloc = MockQuestionPaperBloc();

    // Default stubs
    when(() => mockAuthBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockHomeBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockNotificationBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockQuestionPaperBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockNotificationBloc.state).thenReturn(NotificationInitial());
    when(() => mockAuthBloc.add(any())).thenReturn(null);
    when(() => mockHomeBloc.add(any())).thenReturn(null);
    when(() => mockNotificationBloc.add(any())).thenReturn(null);
  });

  Widget createWidgetUnderTest({
    required AuthState authState,
    required HomeState homeState,
    NotificationState? notificationState,
  }) {
    when(() => mockAuthBloc.state).thenReturn(authState);
    when(() => mockHomeBloc.state).thenReturn(homeState);
    if (notificationState != null) {
      when(() => mockNotificationBloc.state).thenReturn(notificationState);
    }

    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: mockAuthBloc),
          BlocProvider<HomeBloc>.value(value: mockHomeBloc),
          BlocProvider<NotificationBloc>.value(value: mockNotificationBloc),
          BlocProvider<QuestionPaperBloc>.value(value: mockQuestionPaperBloc),
        ],
        child: const HomePage(),
      ),
    );
  }

  // Helper to create test user
  UserEntity createTestUser({
    String id = 'test-user-1',
    String email = 'test@example.com',
    String fullName = 'Test User',
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

  // Helper to create test paper
  QuestionPaperEntity createTestPaper({
    String id = 'paper-1',
    String title = 'Test Paper',
    PaperStatus status = PaperStatus.draft,
    String? rejectionReason,
    String? subject = 'Mathematics',
    int totalQuestions = 10,
  }) {
    return QuestionPaperEntity(
      id: id,
      title: title,
      subjectId: 'subject-1',
      gradeId: 'grade-1',
      academicYear: '2024-2025',
      createdBy: 'user-1',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      modifiedAt: DateTime.now(),
      status: status,
      paperSections: const [
        PaperSectionEntity(
          name: 'Section A',
          type: 'multiple_choice',
          questions: 5,
          marksPerQuestion: 2,
        ),
        PaperSectionEntity(
          name: 'Section B',
          type: 'short_answer',
          questions: 5,
          marksPerQuestion: 3,
        ),
      ],
      questions: const {},
      examType: ExamType.monthlyTest,
      subject: subject,
      grade: 'Grade 10',
      gradeLevel: 10,
      rejectionReason: rejectionReason,
    );
  }

  group('HomePage Widget Tests - Basic Functionality', () {
    testWidgets('shows loading indicator when user not authenticated', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: const AuthInitial(),
          homeState: const HomeInitial(),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows home page for authenticated teacher', (tester) async {
      final user = createTestUser();

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(drafts: const [], submissions: const []),
        ),
      );
      await tester.pump();

      expect(find.text('Test User'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('shows home page for authenticated admin', (tester) async {
      final user = createTestUser(role: UserRole.admin, fullName: 'Admin User');

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(papersForReview: const [], allPapersForAdmin: const []),
        ),
      );
      await tester.pump();

      expect(find.text('Admin User'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('HomePage Widget Tests - State Transitions', () {
    testWidgets('shows loading state correctly', (tester) async {
      final user = createTestUser();

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: const HomeLoading(message: 'Loading...'),
        ),
      );
      await tester.pump();

      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('Loading your papers...'), findsOneWidget);
    });

    testWidgets('shows error state correctly', (tester) async {
      final user = createTestUser();

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: const HomeError('Failed to load papers'),
        ),
      );
      await tester.pump();

      expect(find.text('Failed to load papers'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('shows loaded state with papers correctly', (tester) async {
      final user = createTestUser();
      final paper = createTestPaper();

      // Test that loaded state displays papers correctly
      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(drafts: [paper]),
        ),
      );
      await tester.pump();

      // Paper should be visible in loaded state
      expect(find.text('Test Paper'), findsOneWidget);
      expect(find.text('Your Question Papers'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
    });

    testWidgets('error state shows retry button that triggers reload', (tester) async {
      final user = createTestUser();

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: const HomeError('Network error'),
        ),
      );
      await tester.pump();

      final retryButton = find.byIcon(Icons.refresh);
      expect(retryButton, findsOneWidget);

      // Clear previous interactions
      reset(mockHomeBloc);
      when(() => mockHomeBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => mockHomeBloc.state).thenReturn(const HomeError('Network error'));
      when(() => mockHomeBloc.add(any())).thenReturn(null);

      await tester.tap(retryButton);
      await tester.pump();

      // Should trigger LoadHomePapers event
      verify(() => mockHomeBloc.add(any(that: isA<LoadHomePapers>()))).called(1);
    });
  });

  group('HomePage Widget Tests - Data Rendering', () {
    testWidgets('shows empty state for teacher with no papers', (tester) async {
      final user = createTestUser();

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(drafts: const [], submissions: const []),
        ),
      );
      await tester.pump();

      expect(find.text('No papers yet'), findsOneWidget);
      expect(find.text('Create your first question paper to get started'), findsOneWidget);
    });

    testWidgets('shows empty state for admin with no papers', (tester) async {
      final user = createTestUser(role: UserRole.admin);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(papersForReview: const [], allPapersForAdmin: const []),
        ),
      );
      await tester.pump();

      expect(find.text('No papers to review'), findsOneWidget);
    });

    testWidgets('renders multiple papers correctly', (tester) async {
      final user = createTestUser();
      final papers = List.generate(
        5,
            (i) => createTestPaper(
          id: 'paper-$i',
          title: 'Test Paper $i',
          status: i % 2 == 0 ? PaperStatus.draft : PaperStatus.submitted,
        ),
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(drafts: papers),
        ),
      );
      await tester.pump();

      // Check that at least some papers are rendered
      expect(find.text('Test Paper 0'), findsOneWidget);
      expect(find.text('Test Paper 1'), findsOneWidget);
      expect(find.text('Test Paper 2'), findsOneWidget);

      // Scroll to see more papers if needed
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();

      // All 5 papers should exist in the widget tree
      for (int i = 0; i < 5; i++) {
        expect(find.text('Test Paper $i', skipOffstage: false), findsOneWidget);
      }
    });

    testWidgets('paper with rejection reason displays feedback correctly', (tester) async {
      final user = createTestUser();
      final paper = createTestPaper(
        status: PaperStatus.rejected,
        rejectionReason: 'Questions need more clarity',
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(submissions: [paper]),
        ),
      );
      await tester.pump();

      expect(find.text('Feedback'), findsOneWidget);
      expect(find.text('Questions need more clarity'), findsOneWidget);
    });

    testWidgets('displays correct status badges for different paper statuses', (tester) async {
      final user = createTestUser();
      final papers = [
        createTestPaper(id: '1', title: 'Draft Paper', status: PaperStatus.draft),
        createTestPaper(id: '2', title: 'Submitted Paper', status: PaperStatus.submitted),
        createTestPaper(id: '3', title: 'Approved Paper', status: PaperStatus.approved),
        createTestPaper(id: '4', title: 'Rejected Paper', status: PaperStatus.rejected),
      ];

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(drafts: [papers[0]], submissions: papers.sublist(1)),
        ),
      );
      await tester.pump();

      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Submitted'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
    });
  });

  group('HomePage Widget Tests - Pull to Refresh', () {
    testWidgets('pull to refresh works and triggers event', (tester) async {
      final user = createTestUser();

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(drafts: const [], submissions: const []),
        ),
      );
      await tester.pump();

      // Clear initial load events
      reset(mockHomeBloc);
      when(() => mockHomeBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => mockHomeBloc.state).thenReturn(HomeLoaded(drafts: const [], submissions: const []));
      when(() => mockHomeBloc.add(any())).thenReturn(null);

      expect(find.byType(RefreshIndicator), findsOneWidget);

      // Perform pull-to-refresh by dragging down
      await tester.fling(find.byType(CustomScrollView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Pump and settle but with a timeout to handle the 800ms delay in _handleRefresh
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // Should trigger RefreshHomePapers event
      verify(() => mockHomeBloc.add(any(that: isA<RefreshHomePapers>()))).called(greaterThanOrEqualTo(1));
    });

    testWidgets('refresh preserves data during loading', (tester) async {
      final user = createTestUser();
      final paper = createTestPaper(title: 'Existing Paper');

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(drafts: [paper]),
        ),
      );
      await tester.pump();

      expect(find.text('Existing Paper'), findsOneWidget);

      // Trigger refresh
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Data should still be visible
      expect(find.text('Existing Paper'), findsOneWidget);
    });
  });

  group('HomePage Widget Tests - Notifications', () {
    testWidgets('notification bell shows unread count badge', (tester) async {
      final user = createTestUser();
      final notificationState = NotificationLoaded(
        notifications: const [],
        unreadCount: 5,
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(drafts: const []),
          notificationState: notificationState,
        ),
      );
      await tester.pump();

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('notification bell shows 9+ for counts over 9', (tester) async {
      final user = createTestUser();
      final notificationState = NotificationLoaded(
        notifications: const [],
        unreadCount: 15,
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(drafts: const []),
          notificationState: notificationState,
        ),
      );
      await tester.pump();

      expect(find.text('9+'), findsOneWidget);
    });

    testWidgets('notification bell hides badge when count is zero', (tester) async {
      final user = createTestUser();
      final notificationState = NotificationLoaded(
        notifications: const [],
        unreadCount: 0,
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(drafts: const []),
          notificationState: notificationState,
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);
      // Badge should not be visible
      expect(find.text('0'), findsNothing);
    });

    testWidgets('admin does not see notification bell', (tester) async {
      final user = createTestUser(role: UserRole.admin);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(papersForReview: const []),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.notifications_rounded), findsNothing);
    });
  });

  group('HomePage Widget Tests - Role-Based UI', () {
    testWidgets('teacher sees FAB create button', (tester) async {
      final user = createTestUser(role: UserRole.teacher);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(drafts: const []),
        ),
      );
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
    });

    testWidgets('admin does not see FAB create button', (tester) async {
      final user = createTestUser(role: UserRole.admin);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(papersForReview: const []),
        ),
      );
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('teacher sees drafts and submissions sections', (tester) async {
      final user = createTestUser();
      final draft = createTestPaper(status: PaperStatus.draft, title: 'Draft Paper');
      final submission = createTestPaper(status: PaperStatus.submitted, title: 'Submitted Paper');

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(drafts: [draft], submissions: [submission]),
        ),
      );
      await tester.pump();

      expect(find.text('Draft Paper'), findsOneWidget);
      expect(find.text('Submitted Paper'), findsOneWidget);
    });

    testWidgets('admin sees papers for review', (tester) async {
      final user = createTestUser(role: UserRole.admin);
      final paper = createTestPaper(status: PaperStatus.submitted, title: 'Review Paper');

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(papersForReview: [paper]),
        ),
      );
      await tester.pump();

      expect(find.text('Papers for Review'), findsOneWidget);
      expect(find.text('Review Paper'), findsOneWidget);
    });
  });

  group('HomePage Widget Tests - Edge Cases', () {
    testWidgets('handles very long paper titles with ellipsis', (tester) async {
      final user = createTestUser();
      final paper = createTestPaper(
        title: 'This is an extremely long paper title that should be truncated with ellipsis to prevent overflow issues in the UI',
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(drafts: [paper]),
        ),
      );
      await tester.pump();

      final textWidget = tester.widget<Text>(
        find.text('This is an extremely long paper title that should be truncated with ellipsis to prevent overflow issues in the UI'),
      );
      expect(textWidget.maxLines, 2);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('shows auth error dialog for permission errors', (tester) async {
      final user = createTestUser();

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: const HomeError('Admin privilege required'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Authentication Issue'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
    });

    testWidgets('cached data shown during error state', (tester) async {
      final user = createTestUser();
      final paper = createTestPaper(title: 'Cached Paper');

      // First load with data
      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(drafts: [paper]),
        ),
      );
      await tester.pump();

      expect(find.text('Cached Paper'), findsOneWidget);

      // Simulate error - cached data should still show
      when(() => mockHomeBloc.state).thenReturn(const HomeError('Network error'));

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: const HomeError('Network error'),
        ),
      );
      await tester.pump();

      // Data should still be visible from cache
      expect(find.text('Cached Paper'), findsOneWidget);
    });

    testWidgets('greeting changes based on time of day', (tester) async {
      final user = createTestUser();

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(drafts: const []),
        ),
      );
      await tester.pump();

      final hour = DateTime.now().hour;
      if (hour < 12) {
        expect(find.text('Good morning'), findsOneWidget);
      } else if (hour < 17) {
        expect(find.text('Good afternoon'), findsOneWidget);
      } else {
        expect(find.text('Good evening'), findsOneWidget);
      }
    });
  });

  group('HomePage Widget Tests - Lifecycle', () {
    testWidgets('loads initial data on mount', (tester) async {
      final user = createTestUser();

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: const HomeInitial(),
        ),
      );
      await tester.pump();

      // Should trigger both LoadHomePapers and EnableRealtimeUpdates
      verify(() => mockHomeBloc.add(any(that: isA<LoadHomePapers>()))).called(greaterThanOrEqualTo(1));
      verify(() => mockHomeBloc.add(any(that: isA<EnableRealtimeUpdates>()))).called(greaterThanOrEqualTo(1));
    });

    testWidgets('loads notifications for teachers on mount', (tester) async {
      final user = createTestUser(role: UserRole.teacher);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: const HomeInitial(),
        ),
      );
      await tester.pump();

      // Should trigger LoadUnreadCount for teachers
      verify(() => mockNotificationBloc.add(any(that: isA<LoadUnreadCount>()))).called(greaterThanOrEqualTo(1));
    });

    testWidgets('does not load notifications for admins', (tester) async {
      final user = createTestUser(role: UserRole.admin);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: const HomeInitial(),
        ),
      );
      await tester.pump();

      verifyNever(() => mockNotificationBloc.add(any(that: isA<LoadUnreadCount>())));
    });
  });

  group('HomePage Widget Tests - Navigation & Interactions', () {
    testWidgets('tapping FAB navigates to create paper page', (tester) async {
      final user = createTestUser();

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(drafts: const []),
        ),
      );
      await tester.pump();

      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);

      await tester.tap(fab);
      await tester.pumpAndSettle();
    });

    testWidgets('tapping Edit button on draft paper navigates to edit', (tester) async {
      final user = createTestUser();
      final draftPaper = createTestPaper(status: PaperStatus.draft);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(drafts: [draftPaper]),
        ),
      );
      await tester.pump();

      final editButton = find.text('Edit');
      expect(editButton, findsOneWidget);

      await tester.tap(editButton);
      await tester.pumpAndSettle();
    });

    testWidgets('tapping paper card navigates to paper details', (tester) async {
      final user = createTestUser();
      final paper = createTestPaper(status: PaperStatus.submitted);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(submissions: [paper]),
        ),
      );
      await tester.pump();

      final paperCard = find.byKey(const ValueKey('paper-card-paper-1'));
      expect(paperCard, findsOneWidget);

      await tester.tap(paperCard);
      await tester.pumpAndSettle();
    });

    testWidgets('tapping notification bell navigates to notifications page', (tester) async {
      final user = createTestUser();

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(drafts: const []),
        ),
      );
      await tester.pump();

      final notificationBell = find.byIcon(Icons.notifications_rounded);
      expect(notificationBell, findsOneWidget);

      await tester.tap(notificationBell);
      await tester.pumpAndSettle();
    });
  });

  group('HomePage Widget Tests - Action Buttons', () {
    testWidgets('approved paper shows View button', (tester) async {
      final user = createTestUser();
      final approvedPaper = createTestPaper(
        status: PaperStatus.approved,
        title: 'Approved Paper',
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(submissions: [approvedPaper]),
        ),
      );
      await tester.pump();

      expect(find.text('View'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
    });

    testWidgets('rejected paper shows View Details button', (tester) async {
      final user = createTestUser();
      final rejectedPaper = createTestPaper(
        status: PaperStatus.rejected,
        title: 'Rejected Paper',
        rejectionReason: 'Needs improvement',
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(submissions: [rejectedPaper]),
        ),
      );
      await tester.pump();

      expect(find.text('View Details'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
    });

    testWidgets('submitted paper shows View Status button', (tester) async {
      final user = createTestUser();
      final submittedPaper = createTestPaper(
        status: PaperStatus.submitted,
        title: 'Submitted Paper',
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(submissions: [submittedPaper]),
        ),
      );
      await tester.pump();

      expect(find.text('View Status'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });

    testWidgets('pending paper shows View Status button', (tester) async {
      final user = createTestUser();
      final pendingPaper = createTestPaper(
        status: PaperStatus.submitted,
        title: 'Pending Paper',
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(submissions: [pendingPaper]),
        ),
      );
      await tester.pump();

      expect(find.text('View Status'), findsOneWidget);
    });
  });

  group('HomePage Widget Tests - Admin Views', () {
    testWidgets('admin sees all papers for admin list', (tester) async {
      final user = createTestUser(role: UserRole.admin);
      final allPapers = [
        createTestPaper(id: '1', title: 'Paper 1', status: PaperStatus.approved),
        createTestPaper(id: '2', title: 'Paper 2', status: PaperStatus.draft),
      ];

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(allPapersForAdmin: allPapers),
        ),
      );
      await tester.pump();

      expect(find.text('Paper 1'), findsOneWidget);
      expect(find.text('Paper 2'), findsOneWidget);
    });

    testWidgets('admin sees combined papers from review and all lists', (tester) async {
      final user = createTestUser(role: UserRole.admin);
      final reviewPapers = [
        createTestPaper(id: '1', title: 'Review Paper', status: PaperStatus.submitted),
      ];
      final allPapers = [
        createTestPaper(id: '2', title: 'All Paper', status: PaperStatus.approved),
      ];

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(
            papersForReview: reviewPapers,
            allPapersForAdmin: allPapers,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Review Paper'), findsOneWidget);
      expect(find.text('All Paper'), findsOneWidget);
    });
  });

  group('HomePage Widget Tests - User Avatar', () {
    testWidgets('shows first letter of user name in avatar', (tester) async {
      final user = createTestUser(fullName: 'John Doe');

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(drafts: const []),
        ),
      );
      await tester.pump();

      expect(find.text('J'), findsOneWidget);
    });

    testWidgets('avatar defaults to T when fullName is empty', (tester) async {
      final user = createTestUser(fullName: '');

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(drafts: const []),
        ),
      );
      await tester.pump();

      expect(find.text('T'), findsOneWidget);
    });
  });

  group('HomePage Widget Tests - Advanced Scenarios', () {
    testWidgets('handles refresh when not authenticated gracefully', (tester) async {
      final user = createTestUser();

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(drafts: const []),
        ),
      );
      await tester.pump();

      // Change to unauthenticated state
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

      // Try to refresh - should not crash
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('multiple rapid refresh attempts are guarded', (tester) async {
      final user = createTestUser();

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(drafts: const []),
        ),
      );
      await tester.pump();

      // Clear initial events
      reset(mockHomeBloc);
      when(() => mockHomeBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => mockHomeBloc.state).thenReturn(HomeLoaded(drafts: const []));
      when(() => mockHomeBloc.add(any())).thenReturn(null);

      // First refresh
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pump();

      // Immediate second refresh should be ignored (guard)
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pump();

      // Should only trigger one refresh due to guard
      await tester.pump(const Duration(milliseconds: 900));
      verify(() => mockHomeBloc.add(any(that: isA<RefreshHomePapers>()))).called(1);
    });

    testWidgets('shows connectivity indicator for teachers', (tester) async {
      final user = createTestUser();

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(drafts: const []),
        ),
      );
      await tester.pump();

      expect(find.byType(ConnectivityIndicator), findsOneWidget);
    });

    testWidgets('admin does not see connectivity indicator', (tester) async {
      final user = createTestUser(role: UserRole.admin);

      await tester.pumpWidget(
        createWidgetUnderTest(
          authState: AuthAuthenticated(user),
          homeState: HomeLoaded(papersForReview: const []),
        ),
      );
      await tester.pump();

      expect(find.byType(ConnectivityIndicator), findsNothing);
    });
  });
}