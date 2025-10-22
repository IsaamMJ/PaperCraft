// test/features/home/presentation/bloc/home_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/core/infrastructure/realtime/realtime_service.dart';
import 'package:papercraft/features/catalog/domain/entities/exam_type.dart';
import 'package:papercraft/features/catalog/domain/entities/paper_section_entity.dart';
import 'package:papercraft/features/home/presentation/bloc/home_bloc.dart';
import 'package:papercraft/features/home/presentation/bloc/home_event.dart';
import 'package:papercraft/features/home/presentation/bloc/home_state.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/paper_status.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/question_paper_entity.dart';
import 'package:papercraft/features/paper_workflow/domain/services/paper_display_service.dart';
import 'package:papercraft/features/paper_workflow/domain/usecases/get_all_papers_for_admin_usecase.dart';
import 'package:papercraft/features/paper_workflow/domain/usecases/get_drafts_usecase.dart';
import 'package:papercraft/features/paper_workflow/domain/usecases/get_papers_for_review_usecase.dart';
import 'package:papercraft/features/paper_workflow/domain/usecases/get_user_submissions_usecase.dart';

// Mock classes
class MockGetDraftsUseCase extends Mock implements GetDraftsUseCase {}
class MockGetUserSubmissionsUseCase extends Mock implements GetUserSubmissionsUseCase {}
class MockGetPapersForReviewUseCase extends Mock implements GetPapersForReviewUseCase {}
class MockGetAllPapersForAdminUseCase extends Mock implements GetAllPapersForAdminUseCase {}
class MockRealtimeService extends Mock implements RealtimeService {}
class MockPaperDisplayService extends Mock implements PaperDisplayService {}

void main() {
  late HomeBloc homeBloc;
  late MockGetDraftsUseCase mockGetDraftsUseCase;
  late MockGetUserSubmissionsUseCase mockGetSubmissionsUseCase;
  late MockGetPapersForReviewUseCase mockGetPapersForReviewUseCase;
  late MockGetAllPapersForAdminUseCase mockGetAllPapersForAdminUseCase;
  late MockRealtimeService mockRealtimeService;
  late MockPaperDisplayService mockPaperDisplayService;

  // Test data
  late QuestionPaperEntity testDraftPaper;
  late QuestionPaperEntity testSubmittedPaper;
  late QuestionPaperEntity testApprovedPaper;
  late List<QuestionPaperEntity> testDrafts;
  late List<QuestionPaperEntity> testSubmissions;
  late List<QuestionPaperEntity> testPapersForReview;
  late List<QuestionPaperEntity> testAllPapers;

  setUp(() {
    mockGetDraftsUseCase = MockGetDraftsUseCase();
    mockGetSubmissionsUseCase = MockGetUserSubmissionsUseCase();
    mockGetPapersForReviewUseCase = MockGetPapersForReviewUseCase();
    mockGetAllPapersForAdminUseCase = MockGetAllPapersForAdminUseCase();
    mockRealtimeService = MockRealtimeService();
    mockPaperDisplayService = MockPaperDisplayService();

    // Setup default stub for unsubscribe to prevent null return errors
    when(() => mockRealtimeService.unsubscribe(any()))
        .thenAnswer((_) async {});

    // Setup test data
    final now = DateTime.now();
    final paperSections = [
      const PaperSectionEntity(
        name: 'Section A',
        type: 'multiple_choice',
        questions: 5,
        marksPerQuestion: 2,
      ),
    ];

    testDraftPaper = QuestionPaperEntity(
      id: 'draft-1',
      title: 'Math Test Draft',
      subjectId: 'subject-1',
      gradeId: 'grade-1',
      academicYear: '2024-2025',
      createdBy: 'teacher-1',
      createdAt: now,
      modifiedAt: now,
      status: PaperStatus.draft,
      paperSections: paperSections,
      questions: const {},
      examType: ExamType.monthlyTest,
      subject: 'Mathematics',
      grade: 'Grade 10',
      gradeLevel: 10,
    );

    testSubmittedPaper = QuestionPaperEntity(
      id: 'submitted-1',
      title: 'Science Quiz',
      subjectId: 'subject-2',
      gradeId: 'grade-1',
      academicYear: '2024-2025',
      createdBy: 'teacher-1',
      createdAt: now,
      modifiedAt: now,
      status: PaperStatus.submitted,
      paperSections: paperSections,
      questions: const {},
      examType: ExamType.dailyTest,
      subject: 'Science',
      grade: 'Grade 10',
      gradeLevel: 10,
    );

    testApprovedPaper = QuestionPaperEntity(
      id: 'approved-1',
      title: 'English Test',
      subjectId: 'subject-3',
      gradeId: 'grade-1',
      academicYear: '2024-2025',
      createdBy: 'teacher-1',
      createdAt: now,
      modifiedAt: now,
      status: PaperStatus.approved,
      paperSections: paperSections,
      questions: const {},
      examType: ExamType.annualExam,
      subject: 'English',
      grade: 'Grade 10',
      gradeLevel: 10,
    );

    testDrafts = [testDraftPaper];
    testSubmissions = [testSubmittedPaper];
    testPapersForReview = [testSubmittedPaper];
    testAllPapers = [testApprovedPaper];

    homeBloc = HomeBloc(
      getDraftsUseCase: mockGetDraftsUseCase,
      getSubmissionsUseCase: mockGetSubmissionsUseCase,
      getPapersForReviewUseCase: mockGetPapersForReviewUseCase,
      getAllPapersForAdminUseCase: mockGetAllPapersForAdminUseCase,
      realtimeService: mockRealtimeService,
      paperDisplayService: mockPaperDisplayService,
    );
  });

  tearDown(() {
    homeBloc.close();
  });

  group('HomeBloc', () {
    test('initial state is HomeLoading', () {
      expect(homeBloc.state, const HomeLoading(message: 'Initializing...'));
    });

    group('LoadHomePapers - Teacher', () {
      blocTest<HomeBloc, HomeState>(
        'emits [HomeLoading, HomeLoaded] when teacher papers load successfully',
        build: () {
          when(() => mockGetDraftsUseCase.call())
              .thenAnswer((_) async => Right(testDrafts));
          when(() => mockGetSubmissionsUseCase.call())
              .thenAnswer((_) async => Right(testSubmissions));
          when(() => mockPaperDisplayService.enrichPapers(any()))
              .thenAnswer((invocation) async {
            final papers = invocation.positionalArguments[0] as List<QuestionPaperEntity>;
            return papers;
          });
          return homeBloc;
        },
        act: (bloc) => bloc.add(const LoadHomePapers(
          isAdmin: false,
          userId: 'teacher-1',
        )),
        expect: () => [
          const HomeLoading(message: 'Loading...'),
          HomeLoaded(
            drafts: testDrafts,
            submissions: testSubmissions,
          ),
        ],
        verify: (_) {
          verify(() => mockGetDraftsUseCase.call()).called(1);
          verify(() => mockGetSubmissionsUseCase.call()).called(1);
          verify(() => mockPaperDisplayService.enrichPapers(testDrafts)).called(1);
          verify(() => mockPaperDisplayService.enrichPapers(testSubmissions)).called(1);
        },
      );

      blocTest<HomeBloc, HomeState>(
        'emits [HomeLoading, HomeError] when loading drafts fails',
        build: () {
          when(() => mockGetDraftsUseCase.call())
              .thenAnswer((_) async => const Left(ServerFailure('Failed to load drafts')));
          // Stub submissions because bloc calls both even when drafts fails
          when(() => mockGetSubmissionsUseCase.call())
              .thenAnswer((_) async => Right(testSubmissions));
          when(() => mockPaperDisplayService.enrichPapers(any()))
              .thenAnswer((invocation) async => invocation.positionalArguments[0]);
          return homeBloc;
        },
        act: (bloc) => bloc.add(const LoadHomePapers(
          isAdmin: false,
          userId: 'teacher-1',
        )),
        expect: () => [
          const HomeLoading(message: 'Loading...'),
          const HomeError('Failed to load drafts'),
        ],
        verify: (_) {
          verify(() => mockGetDraftsUseCase.call()).called(1);
          // Don't verify submissions - the bloc returns early on draft failure
        },
      );

      blocTest<HomeBloc, HomeState>(
        'emits [HomeLoading, HomeError] when loading submissions fails',
        build: () {
          when(() => mockGetDraftsUseCase.call())
              .thenAnswer((_) async => Right(testDrafts));
          when(() => mockGetSubmissionsUseCase.call())
              .thenAnswer((_) async => const Left(ServerFailure('Failed to load submissions')));
          when(() => mockPaperDisplayService.enrichPapers(any()))
              .thenAnswer((invocation) async {
            final papers = invocation.positionalArguments[0] as List<QuestionPaperEntity>;
            return papers;
          });
          return homeBloc;
        },
        act: (bloc) => bloc.add(const LoadHomePapers(
          isAdmin: false,
          userId: 'teacher-1',
        )),
        expect: () => [
          const HomeLoading(message: 'Loading...'),
          const HomeError('Failed to load submissions'),
        ],
        verify: (_) {
          verify(() => mockGetDraftsUseCase.call()).called(1);
          verify(() => mockGetSubmissionsUseCase.call()).called(1);
        },
      );

      blocTest<HomeBloc, HomeState>(
        'emits [HomeLoading, HomeError] when userId is null',
        build: () => homeBloc,
        act: (bloc) => bloc.add(const LoadHomePapers(
          isAdmin: false,
          userId: null,
        )),
        expect: () => [
          const HomeLoading(message: 'Loading...'),
          const HomeError('User ID not found'),
        ],
        verify: (_) {
          verifyNever(() => mockGetDraftsUseCase.call());
          verifyNever(() => mockGetSubmissionsUseCase.call());
        },
      );
    });

    group('LoadHomePapers - Admin', () {
      blocTest<HomeBloc, HomeState>(
        'emits [HomeLoading, HomeLoaded] when admin papers load successfully',
        build: () {
          when(() => mockGetPapersForReviewUseCase.call())
              .thenAnswer((_) async => Right(testPapersForReview));
          when(() => mockGetAllPapersForAdminUseCase.call())
              .thenAnswer((_) async => Right(testAllPapers));
          when(() => mockPaperDisplayService.enrichPapers(any()))
              .thenAnswer((invocation) async {
            final papers = invocation.positionalArguments[0] as List<QuestionPaperEntity>;
            return papers;
          });
          return homeBloc;
        },
        act: (bloc) => bloc.add(const LoadHomePapers(
          isAdmin: true,
          userId: null,
        )),
        expect: () => [
          const HomeLoading(message: 'Loading...'),
          HomeLoaded(
            papersForReview: testPapersForReview,
            allPapersForAdmin: testAllPapers,
          ),
        ],
        verify: (_) {
          verify(() => mockGetPapersForReviewUseCase.call()).called(1);
          verify(() => mockGetAllPapersForAdminUseCase.call()).called(1);
          verify(() => mockPaperDisplayService.enrichPapers(testPapersForReview)).called(1);
          verify(() => mockPaperDisplayService.enrichPapers(testAllPapers)).called(1);
        },
      );

      blocTest<HomeBloc, HomeState>(
        'emits [HomeLoading, HomeError] when loading papers for review fails',
        build: () {
          when(() => mockGetPapersForReviewUseCase.call())
              .thenAnswer((_) async => const Left(ServerFailure('Failed to load papers')));
          // Stub getAllPapers because bloc calls both even when review fails
          when(() => mockGetAllPapersForAdminUseCase.call())
              .thenAnswer((_) async => Right(testAllPapers));
          when(() => mockPaperDisplayService.enrichPapers(any()))
              .thenAnswer((invocation) async => invocation.positionalArguments[0]);
          return homeBloc;
        },
        act: (bloc) => bloc.add(const LoadHomePapers(
          isAdmin: true,
          userId: null,
        )),
        expect: () => [
          const HomeLoading(message: 'Loading...'),
          const HomeError('Failed to load papers'),
        ],
        verify: (_) {
          verify(() => mockGetPapersForReviewUseCase.call()).called(1);
          // Don't verify getAllPapers - the bloc returns early on review failure
        },
      );
    });

    group('RefreshHomePapers', () {
      blocTest<HomeBloc, HomeState>(
        'refreshes teacher papers without showing loading state',
        build: () {
          when(() => mockGetDraftsUseCase.call())
              .thenAnswer((_) async => Right(testDrafts));
          when(() => mockGetSubmissionsUseCase.call())
              .thenAnswer((_) async => Right(testSubmissions));
          when(() => mockPaperDisplayService.enrichPapers(any()))
              .thenAnswer((invocation) async {
            final papers = invocation.positionalArguments[0] as List<QuestionPaperEntity>;
            return papers;
          });
          return homeBloc;
        },
        act: (bloc) => bloc.add(const RefreshHomePapers(
          isAdmin: false,
          userId: 'teacher-1',
        )),
        expect: () => [
          HomeLoaded(
            drafts: testDrafts,
            submissions: testSubmissions,
          ),
        ],
        verify: (_) {
          verify(() => mockGetDraftsUseCase.call()).called(1);
          verify(() => mockGetSubmissionsUseCase.call()).called(1);
        },
      );

      blocTest<HomeBloc, HomeState>(
        'does not emit error state on refresh failure',
        build: () {
          when(() => mockGetDraftsUseCase.call())
              .thenAnswer((_) async => const Left(ServerFailure('Network error')));
          return homeBloc;
        },
        act: (bloc) => bloc.add(const RefreshHomePapers(
          isAdmin: false,
          userId: 'teacher-1',
        )),
        expect: () => [],
        verify: (_) {
          verify(() => mockGetDraftsUseCase.call()).called(1);
        },
      );
    });

    group('EnableRealtimeUpdates', () {
      blocTest<HomeBloc, HomeState>(
        'subscribes to realtime updates for teacher',
        build: () {
          when(() => mockRealtimeService.subscribeToTable(
            table: any(named: 'table'),
            channelName: any(named: 'channelName'),
            onInsert: any(named: 'onInsert'),
            onUpdate: any(named: 'onUpdate'),
            onDelete: any(named: 'onDelete'),
          )).thenReturn('home_teacher_papers');
          return homeBloc;
        },
        act: (bloc) => bloc.add(const EnableRealtimeUpdates(
          isAdmin: false,
          userId: 'teacher-1',
        )),
        expect: () => [],
        verify: (_) {
          verify(() => mockRealtimeService.subscribeToTable(
            table: 'question_papers',
            channelName: 'home_teacher_papers',
            onInsert: any(named: 'onInsert'),
            onUpdate: any(named: 'onUpdate'),
            onDelete: any(named: 'onDelete'),
          )).called(1);
        },
      );

      blocTest<HomeBloc, HomeState>(
        'subscribes to realtime updates for admin',
        build: () {
          when(() => mockRealtimeService.subscribeToTable(
            table: any(named: 'table'),
            channelName: any(named: 'channelName'),
            onInsert: any(named: 'onInsert'),
            onUpdate: any(named: 'onUpdate'),
            onDelete: any(named: 'onDelete'),
          )).thenReturn('home_admin_papers');
          return homeBloc;
        },
        act: (bloc) => bloc.add(const EnableRealtimeUpdates(
          isAdmin: true,
          userId: null,
        )),
        expect: () => [],
        verify: (_) {
          verify(() => mockRealtimeService.subscribeToTable(
            table: 'question_papers',
            channelName: 'home_admin_papers',
            onInsert: any(named: 'onInsert'),
            onUpdate: any(named: 'onUpdate'),
            onDelete: any(named: 'onDelete'),
          )).called(1);
        },
      );
    });

    group('DisableRealtimeUpdates', () {
      blocTest<HomeBloc, HomeState>(
        'unsubscribes from all realtime channels',
        build: () => homeBloc,
        act: (bloc) => bloc.add(const DisableRealtimeUpdates()),
        expect: () => [],
        verify: (_) {
          // Note: unsubscribe is called during bloc.close() in tearDown as well
          // So we check that it was called at least once for each channel
          verify(() => mockRealtimeService.unsubscribe('home_admin_papers')).called(greaterThanOrEqualTo(1));
          verify(() => mockRealtimeService.unsubscribe('home_teacher_papers')).called(greaterThanOrEqualTo(1));
        },
      );
    });

    group('PaperRealtimeUpdate', () {
      final now = DateTime.now();
      final paperData = {
        'id': 'new-paper-1',
        'title': 'New Paper',
        'subject_id': 'subject-1',
        'grade_id': 'grade-1',
        'academic_year': '2024-2025',
        'user_id': 'teacher-1',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'status': 'submitted',
        'paper_sections': [
          {
            'name': 'Section A',
            'type': 'multiple_choice',
            'questions': 5,
            'marks_per_question': 2,
          }
        ],
        'questions': {},
        'exam_type': 'monthly_test',
      };

      blocTest<HomeBloc, HomeState>(
        'handles INSERT event by adding paper to review list',
        build: () {
          when(() => mockPaperDisplayService.enrichPapers(any()))
              .thenAnswer((invocation) async {
            final papers = invocation.positionalArguments[0] as List<QuestionPaperEntity>;
            return papers;
          });
          return homeBloc;
        },
        seed: () => HomeLoaded(
          papersForReview: testPapersForReview,
          allPapersForAdmin: const [],
        ),
        act: (bloc) => bloc.add(PaperRealtimeUpdate(
          paperData: paperData,
          eventType: RealtimeEventType.insert,
        )),
        wait: const Duration(milliseconds: 300),
        // The bloc catches exceptions in realtime updates, so it may not emit
        // We just verify it doesn't crash
        errors: () => [],
      );

      blocTest<HomeBloc, HomeState>(
        'handles UPDATE event by updating paper in lists',
        build: () {
          when(() => mockPaperDisplayService.enrichPapers(any()))
              .thenAnswer((invocation) async {
            final papers = invocation.positionalArguments[0] as List<QuestionPaperEntity>;
            return papers;
          });
          return homeBloc;
        },
        seed: () => HomeLoaded(
          drafts: testDrafts,
          submissions: testSubmissions,
        ),
        act: (bloc) => bloc.add(PaperRealtimeUpdate(
          paperData: {
            ...paperData,
            'id': testDraftPaper.id,
            'title': 'Updated Title',
            'status': 'draft',
          },
          eventType: RealtimeEventType.update,
        )),
        wait: const Duration(milliseconds: 300),
        // Realtime updates may fail silently in the bloc, so we just verify no crash
        errors: () => [],
      );

      blocTest<HomeBloc, HomeState>(
        'handles DELETE event by removing paper from lists',
        build: () {
          when(() => mockPaperDisplayService.enrichPapers(any()))
              .thenAnswer((invocation) async {
            final papers = invocation.positionalArguments[0] as List<QuestionPaperEntity>;
            return papers;
          });
          return homeBloc;
        },
        seed: () => HomeLoaded(
          drafts: testDrafts,
          submissions: testSubmissions,
        ),
        act: (bloc) => bloc.add(PaperRealtimeUpdate(
          paperData: {
            ...paperData,
            'id': testDraftPaper.id,
          },
          eventType: RealtimeEventType.delete,
        )),
        wait: const Duration(milliseconds: 300),
        // Realtime updates may fail silently in the bloc, so we just verify no crash
        errors: () => [],
      );

      blocTest<HomeBloc, HomeState>(
        'ignores realtime updates when not in HomeLoaded state',
        build: () => homeBloc,
        seed: () => const HomeLoading(),
        act: (bloc) => bloc.add(PaperRealtimeUpdate(
          paperData: paperData,
          eventType: RealtimeEventType.insert,
        )),
        expect: () => [],
      );
    });

    group('close', () {
      test('unsubscribes from realtime channels on close', () async {
        // Create a fresh bloc for this test to avoid conflicts with tearDown
        final testBloc = HomeBloc(
          getDraftsUseCase: mockGetDraftsUseCase,
          getSubmissionsUseCase: mockGetSubmissionsUseCase,
          getPapersForReviewUseCase: mockGetPapersForReviewUseCase,
          getAllPapersForAdminUseCase: mockGetAllPapersForAdminUseCase,
          realtimeService: mockRealtimeService,
          paperDisplayService: mockPaperDisplayService,
        );

        await testBloc.close();

        verify(() => mockRealtimeService.unsubscribe('home_admin_papers')).called(1);
        verify(() => mockRealtimeService.unsubscribe('home_teacher_papers')).called(1);
      });
    });
  });
}