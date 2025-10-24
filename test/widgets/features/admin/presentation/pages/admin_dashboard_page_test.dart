// test/features/paper_workflow/presentation/pages/admin_dashboard_page_test.dart

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:papercraft/core/presentation/routes/app_routes.dart';
import 'package:papercraft/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:papercraft/features/authentication/domain/services/user_state_service.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/paper_status.dart';
import 'package:papercraft/features/paper_workflow/domain/services/user_info_service.dart';
import 'package:papercraft/features/paper_workflow/presentation/bloc/question_paper_bloc.dart';

import '../../../../../features/admin/presentation/pages/admin_dashboard_page_test_mocks.dart';


void main() {
  late MockQuestionPaperBloc mockBloc;
  late MockUserStateService mockUserStateService;
  late MockUserInfoService mockUserInfoService;
  late MockNavigatorObserver mockNavigatorObserver;
  late GetIt sl;

  setUpAll(() {
    // Register fallback values for Mocktail
    registerFallbackValue(FakeQuestionPaperEvent());
    registerFallbackValue(FakeQuestionPaperState());
    registerFallbackValue(FakeRoute());
  });

  setUp(() {
    // Create fresh mocks for each test
    mockBloc = MockQuestionPaperBloc();
    mockUserStateService = MockUserStateService();
    mockUserInfoService = MockUserInfoService();
    mockNavigatorObserver = MockNavigatorObserver();

    // Setup GetIt
    sl = GetIt.asNewInstance();
    sl.registerSingleton<UserStateService>(mockUserStateService);
    sl.registerSingleton<UserInfoService>(mockUserInfoService);

    // Default mock behaviors
    when(() => mockUserStateService.isAdmin).thenReturn(true);
    when(() => mockUserInfoService.getUserFullName(any()))
        .thenAnswer((_) async => 'John Doe');
    when(() => mockBloc.stream).thenAnswer((_) => Stream.value(QuestionPaperInitial()));
    when(() => mockBloc.state).thenReturn(QuestionPaperInitial());
  });

  tearDown(() {
    sl.reset();
  });

  // Helper function to create the widget under test
  Widget createWidgetUnderTest({
    QuestionPaperState? initialState,
  }) {
    if (initialState != null) {
      when(() => mockBloc.state).thenReturn(initialState);
    }

    return MaterialApp(
      home: BlocProvider<QuestionPaperBloc>.value(
        value: mockBloc,
        child: const AdminDashboardPage(),
      ),
      navigatorObservers: [mockNavigatorObserver],
    );
  }

  // Helper for creating widget with GoRouter
  Widget createWidgetWithRouter({
    QuestionPaperState? initialState,
  }) {
    if (initialState != null) {
      when(() => mockBloc.state).thenReturn(initialState);
    }

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => BlocProvider<QuestionPaperBloc>.value(
            value: mockBloc,
            child: const AdminDashboardPage(),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('Home Page')),
        ),
        GoRoute(
          path: AppRoutes.questionPaperCreate,
          builder: (context, state) => const Scaffold(body: Text('Create Paper')),
        ),
        GoRoute(
          path: '${AppRoutes.questionPaperView}/:id',
          builder: (context, state) => Scaffold(
            body: Text('View Paper: ${state.pathParameters['id']}'),
          ),
        ),
      ],
      observers: [mockNavigatorObserver],
    );

    return MaterialApp.router(
      routerConfig: router,
    );
  }

  group('AdminDashboardPage - Initialization', () {
    testWidgets('renders correctly for admin user', (tester) async {
      when(() => mockUserStateService.isAdmin).thenReturn(true);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('All Papers'), findsOneWidget);
      expect(find.text('Create Paper'), findsOneWidget);
      verify(() => mockBloc.add(const LoadAllPapersForAdmin())).called(1);
    });

    testWidgets('redirects non-admin to home page', (tester) async {
      when(() => mockUserStateService.isAdmin).thenReturn(false);

      await tester.pumpWidget(createWidgetWithRouter());
      await tester.pumpAndSettle();

      expect(find.text('Home Page'), findsOneWidget);
    });

    testWidgets('loads papers on init', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      verify(() => mockBloc.add(const LoadAllPapersForAdmin())).called(1);
    });
  });

  group('AdminDashboardPage - Loading States', () {
    testWidgets('shows loading indicator when papers are loading', (tester) async {
      when(() => mockBloc.state).thenReturn(const QuestionPaperLoading());
      whenListen(
        mockBloc,
        Stream.value(const QuestionPaperLoading()),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading papers...'), findsOneWidget);
    });

    testWidgets('does not show loading indicator during refresh', (tester) async {
      final papers = TestDataFactory.createPaperList(count: 3);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(allPapersForAdmin: papers));

      await tester.pumpWidget(createWidgetUnderTest(
        initialState: QuestionPaperLoaded(allPapersForAdmin: papers),
      ));
      await tester.pumpAndSettle();

      // Papers should be visible
      expect(find.text('Test Paper 0'), findsOneWidget);
    });
  });

  group('AdminDashboardPage - Paper List Display', () {
    testWidgets('displays papers when loaded', (tester) async {
      final papers = TestDataFactory.createPaperList(count: 3);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(allPapersForAdmin: papers));
      whenListen(
        mockBloc,
        Stream.value(QuestionPaperLoaded(allPapersForAdmin: papers)),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Test Paper 0'), findsOneWidget);
      expect(find.text('Test Paper 1'), findsOneWidget);
      expect(find.text('Test Paper 2'), findsOneWidget);
      expect(find.text('3 Papers in All Papers'), findsOneWidget);
    });

    testWidgets('displays paper cards with correct information', (tester) async {
      final paper = TestDataFactory.createPaper(
        title: 'Mathematics Final Test',
        subject: 'Mathematics',
        totalQuestions: 15,
        totalMarks: 75,
        status: PaperStatus.submitted,
      );

      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: [paper],
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Mathematics Final Test'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('15'), findsOneWidget); // Questions count
      expect(find.text('75'), findsOneWidget); // Marks
    });

    testWidgets('displays different status badges correctly', (tester) async {
      final papers = TestDataFactory.createMixedStatusPapers();
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: papers,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('APPROVED'), findsOneWidget);
      expect(find.text('REJECTED'), findsOneWidget);
    });

    testWidgets('shows creator name from UserInfoService', (tester) async {
      final paper = TestDataFactory.createPaper(createdBy: 'user-123');
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: [paper],
      ));
      when(() => mockUserInfoService.getUserFullName('user-123'))
          .thenAnswer((_) async => 'Jane Smith');

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Created by Jane Smith'), findsOneWidget);
    });

    testWidgets('shows formatted date', (tester) async {
      final paper = TestDataFactory.createPaper(
        createdAt: DateTime(2024, 3, 15),
      );
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: [paper],
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('15/3/2024'), findsOneWidget);
    });
  });

  group('AdminDashboardPage - Empty State', () {
    testWidgets('shows empty state when no papers', (tester) async {
      when(() => mockBloc.state).thenReturn(const QuestionPaperLoaded(
        allPapersForAdmin: [],
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('No Papers Found'), findsOneWidget);
      expect(find.text('No papers have been submitted yet\nPull down to refresh'), findsOneWidget);
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    });

    testWidgets('shows empty state when all papers filtered out', (tester) async {
      final papers = TestDataFactory.createPaperList(count: 3);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: papers,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Enter search query that matches nothing
      await tester.enterText(
        find.byType(TextField).first,
        'Nonexistent Paper',
      );
      await tester.pumpAndSettle();

      expect(find.text('No Papers Found'), findsOneWidget);
      expect(find.text('No papers match your current filters'), findsOneWidget);
    });
  });

  group('AdminDashboardPage - Error State', () {
    testWidgets('shows error state with retry button', (tester) async {
      when(() => mockBloc.state).thenReturn(
        const QuestionPaperError('Failed to load papers'),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Failed to load papers'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('retry button triggers reload', (tester) async {
      when(() => mockBloc.state).thenReturn(
        const QuestionPaperError('Failed to load papers'),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      verify(() => mockBloc.add(const LoadAllPapersForAdmin())).called(2); // Once on init, once on retry
    });
  });

  group('AdminDashboardPage - Search Functionality', () {
    testWidgets('search field is present', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Search papers...'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('filters papers by title', (tester) async {
      final papers = [
        TestDataFactory.createPaper(id: '1', title: 'Mathematics Test'),
        TestDataFactory.createPaper(id: '2', title: 'Physics Quiz'),
        TestDataFactory.createPaper(id: '3', title: 'Chemistry Lab'),
      ];

      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: papers,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Initially all papers visible
      expect(find.text('Mathematics Test'), findsOneWidget);
      expect(find.text('Physics Quiz'), findsOneWidget);

      // Search for "Physics"
      await tester.enterText(
        find.byType(TextField).first,
        'Physics',
      );
      await tester.pumpAndSettle();

      // Only Physics paper should be visible
      expect(find.text('Physics Quiz'), findsOneWidget);
      expect(find.text('Mathematics Test'), findsNothing);
    });

    testWidgets('search is case-insensitive', (tester) async {
      final papers = [
        TestDataFactory.createPaper(title: 'Mathematics Test'),
      ];

      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: papers,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        'mathematics',
      );
      await tester.pumpAndSettle();

      expect(find.text('Mathematics Test'), findsOneWidget);
    });

    testWidgets('clear button appears when searching', (tester) async {
      final papers = TestDataFactory.createPaperList(count: 2);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: papers,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Clear button should not be visible initially
      expect(find.byIcon(Icons.clear), findsNothing);

      // Enter search text
      await tester.enterText(
        find.byType(TextField).first,
        'Test',
      );
      await tester.pumpAndSettle();

      // Clear button should appear
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('clear button clears search', (tester) async {
      final papers = TestDataFactory.createPaperList(count: 2);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: papers,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Enter search
      await tester.enterText(
        find.byType(TextField).first,
        'Test',
      );
      await tester.pumpAndSettle();

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // Search should be cleared
      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.controller?.text, isEmpty);
    });
  });

  group('AdminDashboardPage - Subject Filter', () {
    testWidgets('subject dropdown is present', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Subject'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets('filters papers by subject', (tester) async {
      final papers = [
        TestDataFactory.createPaper(id: '1', subject: 'Mathematics'),
        TestDataFactory.createPaper(id: '2', subject: 'Physics'),
        TestDataFactory.createPaper(id: '3', subject: 'Mathematics'),
      ];

      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: papers,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Open dropdown
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      // Select Mathematics
      await tester.tap(find.text('Mathematics').last);
      await tester.pumpAndSettle();

      // Only 2 Mathematics papers should be visible
      expect(find.text('Test Paper 0'), findsOneWidget);
      expect(find.text('Test Paper 2'), findsOneWidget);
      expect(find.text('Test Paper 1'), findsNothing);
    });

    testWidgets('clear filters button appears when filters applied', (tester) async {
      final papers = TestDataFactory.createPaperList(count: 3);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: papers,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Clear button should not be visible initially
      expect(find.text('Clear'), findsNothing);

      // Apply subject filter
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mathematics').last);
      await tester.pumpAndSettle();

      // Clear button should appear
      expect(find.text('Clear'), findsOneWidget);
    });

    testWidgets('clear filters button clears all filters', (tester) async {
      final papers = TestDataFactory.createPaperList(count: 3);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: papers,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Apply filters
      await tester.enterText(find.byType(TextField).first, 'Test');
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mathematics').last);
      await tester.pumpAndSettle();

      // Tap clear filters
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      // All papers should be visible again
      expect(find.text('Test Paper 0'), findsOneWidget);
      expect(find.text('Test Paper 1'), findsOneWidget);
      expect(find.text('Test Paper 2'), findsOneWidget);
    });
  });

  group('AdminDashboardPage - Pull to Refresh', () {
    testWidgets('can pull to refresh', (tester) async {
      final papers = TestDataFactory.createPaperList(count: 2);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: papers,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Find the RefreshIndicator
      final refreshFinder = find.byType(RefreshIndicator);
      expect(refreshFinder, findsOneWidget);

      // Perform pull-to-refresh gesture
      await tester.drag(refreshFinder, const Offset(0, 300));
      await tester.pumpAndSettle();

      // Verify reload was triggered (init + refresh)
      verify(() => mockBloc.add(const LoadAllPapersForAdmin())).called(2);
    });
  });

  group('AdminDashboardPage - Action Buttons', () {
    testWidgets('view button is always visible', (tester) async {
      final paper = TestDataFactory.createPaper(status: PaperStatus.submitted);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: [paper],
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('approve and reject buttons shown for submitted papers', (tester) async {
      final paper = TestDataFactory.createPaper(status: PaperStatus.submitted);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: [paper],
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('approve and reject buttons hidden for approved papers', (tester) async {
      final paper = TestDataFactory.createPaper(status: PaperStatus.approved);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: [paper],
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('view button navigates to paper detail', (tester) async {
      final paper = TestDataFactory.createPaper(id: 'paper-123');
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: [paper],
      ));

      await tester.pumpWidget(createWidgetWithRouter());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();

      expect(find.text('View Paper: paper-123'), findsOneWidget);
    });
  });

  group('AdminDashboardPage - Approve Paper Dialog', () {
    testWidgets('shows confirmation dialog when approve tapped', (tester) async {
      final paper = TestDataFactory.createPaper(status: PaperStatus.submitted);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: [paper],
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(find.text('Approve Paper'), findsOneWidget);
      expect(find.text('Are you sure you want to approve this paper?'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('approves paper when confirmed', (tester) async {
      final paper = TestDataFactory.createPaper(id: 'paper-123', status: PaperStatus.submitted);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: [paper],
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap approve button
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      // Confirm in dialog
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      verify(() => mockBloc.add(const ApprovePaper('paper-123'))).called(1);
    });

    testWidgets('does not approve when cancelled', (tester) async {
      final paper = TestDataFactory.createPaper(id: 'paper-123', status: PaperStatus.submitted);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: [paper],
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap approve button
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      // Cancel in dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => mockBloc.add(any(that: isA<ApprovePaper>())));
    });
  });

  group('AdminDashboardPage - Reject Paper Dialog', () {
    testWidgets('shows rejection dialog when reject tapped', (tester) async {
      final paper = TestDataFactory.createPaper(
        title: 'Test Paper',
        status: PaperStatus.submitted,
      );
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: [paper],
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Reject Paper'), findsOneWidget);
      expect(find.text('Paper: Test Paper'), findsOneWidget);
      expect(find.text('Rejection reason:'), findsOneWidget);
      expect(find.text('Enter reason...'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('rejects paper with reason when confirmed', (tester) async {
      final paper = TestDataFactory.createPaper(
        id: 'paper-123',
        title: 'Test Paper',
        status: PaperStatus.submitted,
      );
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: [paper],
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap reject button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Enter rejection reason
      await tester.enterText(
        find.byType(TextField).last,
        'Incomplete answers',
      );
      await tester.pumpAndSettle();

      // Confirm rejection
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      verify(() => mockBloc.add(
        const RejectPaper('paper-123', 'Incomplete answers'),
      )).called(1);
    });

    testWidgets('does not reject when cancelled', (tester) async {
      final paper = TestDataFactory.createPaper(status: PaperStatus.submitted);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: [paper],
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap reject button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => mockBloc.add(any(that: isA<RejectPaper>())));
    });

    testWidgets('does not reject with empty reason', (tester) async {
      final paper = TestDataFactory.createPaper(
        id: 'paper-123',
        status: PaperStatus.submitted,
      );
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: [paper],
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap reject button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Try to reject without entering reason
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      verifyNever(() => mockBloc.add(any(that: isA<RejectPaper>())));
    });
  });

  group('AdminDashboardPage - BLoC Listener', () {
    testWidgets('shows success message on QuestionPaperSuccess', (tester) async {
      final papers = TestDataFactory.createPaperList(count: 1);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: papers,
      ));

      whenListen(
        mockBloc,
        Stream.fromIterable([
          QuestionPaperLoaded(allPapersForAdmin: papers),
          const QuestionPaperSuccess('Paper approved successfully'),
        ]),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump();

      expect(find.text('Paper approved successfully'), findsOneWidget);
    });

    testWidgets('shows error message on QuestionPaperError', (tester) async {
      final papers = TestDataFactory.createPaperList(count: 1);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: papers,
      ));

      whenListen(
        mockBloc,
        Stream.fromIterable([
          QuestionPaperLoaded(allPapersForAdmin: papers),
          const QuestionPaperError('Failed to approve paper'),
        ]),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump();

      expect(find.text('Failed to approve paper'), findsOneWidget);
    });

    testWidgets('reloads data after success', (tester) async {
      final papers = TestDataFactory.createPaperList(count: 1);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: papers,
      ));

      whenListen(
        mockBloc,
        Stream.fromIterable([
          QuestionPaperLoaded(allPapersForAdmin: papers),
          const QuestionPaperSuccess('Paper approved'),
        ]),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump();

      // Should reload after success (init + success)
      verify(() => mockBloc.add(const LoadAllPapersForAdmin())).called(2);
    });
  });

  group('AdminDashboardPage - Floating Action Button', () {
    testWidgets('FAB is present', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Create Paper'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('FAB navigates to create paper page', (tester) async {
      await tester.pumpWidget(createWidgetWithRouter());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Create Paper'), findsWidgets);
    });
  });

  group('AdminDashboardPage - Combined Filters', () {
    testWidgets('filters by both search and subject', (tester) async {
      final papers = [
        TestDataFactory.createPaper(
          id: '1',
          title: 'Math Quiz',
          subject: 'Mathematics',
        ),
        TestDataFactory.createPaper(
          id: '2',
          title: 'Math Test',
          subject: 'Mathematics',
        ),
        TestDataFactory.createPaper(
          id: '3',
          title: 'Physics Quiz',
          subject: 'Physics',
        ),
      ];

      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: papers,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Apply subject filter
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mathematics').last);
      await tester.pumpAndSettle();

      // Apply search filter
      await tester.enterText(find.byType(TextField).first, 'Quiz');
      await tester.pumpAndSettle();

      // Only Math Quiz should be visible
      expect(find.text('Math Quiz'), findsOneWidget);
      expect(find.text('Math Test'), findsNothing);
      expect(find.text('Physics Quiz'), findsNothing);
    });
  });

  group('AdminDashboardPage - Performance', () {
    testWidgets('handles large list efficiently', (tester) async {
      final papers = TestDataFactory.createPaperList(count: 50);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: papers,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Verify list is rendered
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.text('50 Papers in All Papers'), findsOneWidget);

      // Scroll performance check - should complete without issues
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();

      // Papers should still be visible
      expect(find.byType(CustomScrollView), findsOneWidget);
    });

    testWidgets('filter performance with many papers', (tester) async {
      final papers = TestDataFactory.createPaperList(count: 100);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: papers,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final stopwatch = Stopwatch()..start();

      // Apply filter
      await tester.enterText(find.byType(TextField).first, 'Test');
      await tester.pumpAndSettle();

      stopwatch.stop();

      // Filter should complete quickly (within 100ms)
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });

  group('AdminDashboardPage - User Name Caching', () {
    testWidgets('caches user names to avoid redundant calls', (tester) async {
      final papers = [
        TestDataFactory.createPaper(id: '1', createdBy: 'user-123'),
        TestDataFactory.createPaper(id: '2', createdBy: 'user-123'),
        TestDataFactory.createPaper(id: '3', createdBy: 'user-456'),
      ];

      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: papers,
      ));

      when(() => mockUserInfoService.getUserFullName('user-123'))
          .thenAnswer((_) async => 'John Doe');
      when(() => mockUserInfoService.getUserFullName('user-456'))
          .thenAnswer((_) async => 'Jane Smith');

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Should call getUserFullName only once per unique user
      verify(() => mockUserInfoService.getUserFullName('user-123')).called(1);
      verify(() => mockUserInfoService.getUserFullName('user-456')).called(1);
    });

    testWidgets('shows fallback name on error', (tester) async {
      final paper = TestDataFactory.createPaper(createdBy: 'user-999');
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: [paper],
      ));

      when(() => mockUserInfoService.getUserFullName('user-999'))
          .thenThrow(Exception('Network error'));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Created by User user-999'), findsOneWidget);
    });
  });

  group('AdminDashboardPage - Responsive Layout', () {
    testWidgets('adjusts layout for small screens', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final paper = TestDataFactory.createPaper();
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: [paper],
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // On small screens, metrics should show abbreviated labels
      expect(find.text('Q'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
    });

    testWidgets('shows full labels on larger screens', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final paper = TestDataFactory.createPaper();
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: [paper],
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // On larger screens, full labels should be visible
      expect(find.text('Questions'), findsOneWidget);
      expect(find.text('Marks'), findsOneWidget);
    });
  });

  group('AdminDashboardPage - Stats Header', () {
    testWidgets('shows correct paper count in header', (tester) async {
      final papers = TestDataFactory.createPaperList(count: 7);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: papers,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('7 Papers in All Papers'), findsOneWidget);
      expect(find.text('Manage and review submissions'), findsOneWidget);
    });

    testWidgets('updates count when filters applied', (tester) async {
      final papers = [
        TestDataFactory.createPaper(id: '1', subject: 'Mathematics'),
        TestDataFactory.createPaper(id: '2', subject: 'Mathematics'),
        TestDataFactory.createPaper(id: '3', subject: 'Physics'),
      ];

      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: papers,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Initially shows all papers
      expect(find.text('3 Papers in All Papers'), findsOneWidget);

      // Apply filter
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mathematics').last);
      await tester.pumpAndSettle();

      // Count should update to filtered count
      expect(find.text('2 Papers in All Papers'), findsOneWidget);
    });
  });

  group('AdminDashboardPage - Edge Cases', () {
    testWidgets('handles null subject gracefully', (tester) async {
      final paper = TestDataFactory.createPaper(subject: null);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: [paper],
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Unknown Subject'), findsOneWidget);
    });

    testWidgets('handles very long paper titles', (tester) async {
      final paper = TestDataFactory.createPaper(
        title: 'This is a very long paper title that should be truncated properly to avoid layout issues',
      );
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: [paper],
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Title should be present (even if truncated)
      expect(find.textContaining('This is a very long'), findsOneWidget);
    });

    testWidgets('handles rapid filter changes', (tester) async {
      final papers = TestDataFactory.createPaperList(count: 5);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: papers,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Rapidly change search
      for (int i = 0; i < 5; i++) {
        await tester.enterText(find.byType(TextField).first, 'Query $i');
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();

      // Should not crash
      expect(find.byType(AdminDashboardPage), findsOneWidget);
    });

    testWidgets('handles papers with zero questions', (tester) async {
      final paper = TestDataFactory.createPaper(totalQuestions: 0, totalMarks: 0);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: [paper],
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('0'), findsWidgets);
    });
  });

  group('AdminDashboardPage - Memory Management', () {
    testWidgets('cleans up resources on dispose', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Replace with different widget to trigger dispose
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Text('Different Page')),
      ));
      await tester.pumpAndSettle();

      // Should not crash
      expect(find.text('Different Page'), findsOneWidget);
    });
  });

  group('AdminDashboardPage - Refresh Timeout', () {
    testWidgets('handles refresh timeout gracefully', (tester) async {
      final papers = TestDataFactory.createPaperList(count: 1);
      when(() => mockBloc.state).thenReturn(QuestionPaperLoaded(
        allPapersForAdmin: papers,
      ));

      // Simulate long-running state that never completes
      when(() => mockBloc.stream).thenAnswer(
            (_) => Stream.value(const QuestionPaperLoading()).asBroadcastStream(),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Trigger refresh
      await tester.drag(find.byType(RefreshIndicator), const Offset(0, 300));

      // Wait for timeout (10 seconds in real code, but pump cycles here)
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();

      // Should not crash and papers should still be visible
      expect(find.byType(AdminDashboardPage), findsOneWidget);
    });
  });
}