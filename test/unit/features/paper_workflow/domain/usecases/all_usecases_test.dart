import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/core/domain/models/paginated_result.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/paper_status.dart';
import 'package:papercraft/features/paper_workflow/domain/repositories/question_paper_repository.dart';
import 'package:papercraft/features/paper_workflow/domain/usecases/delete_draft_usecase.dart';
import 'package:papercraft/features/paper_workflow/domain/usecases/get_all_papers_for_admin_usecase.dart';
import 'package:papercraft/features/paper_workflow/domain/usecases/get_approved_papers_paginated_usecase.dart';
import 'package:papercraft/features/paper_workflow/domain/usecases/get_approved_papers_usecase.dart';
import 'package:papercraft/features/paper_workflow/domain/usecases/get_drafts_usecase.dart';
import 'package:papercraft/features/paper_workflow/domain/usecases/get_paper_by_id_usecase.dart';
import 'package:papercraft/features/paper_workflow/domain/usecases/get_papers_for_review_usecase.dart';
import 'package:papercraft/features/paper_workflow/domain/usecases/get_user_submissions_usecase.dart';
import 'package:papercraft/features/paper_workflow/domain/usecases/pull_for_editing_usecase.dart';
import 'package:papercraft/features/paper_workflow/domain/usecases/save_draft_usecase.dart';
import 'package:papercraft/features/paper_workflow/domain/usecases/submit_paper_usecase.dart';
import '../../../../../helpers/paper_workflow_helpers.dart';

class MockQuestionPaperRepository extends Mock implements QuestionPaperRepository {}

void main() {
  late MockQuestionPaperRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(createMockPaper());
  });

  setUp(() => mockRepository = MockQuestionPaperRepository());

  group('SaveDraftUseCase', () {
    late SaveDraftUseCase useCase;
    setUp(() => useCase = SaveDraftUseCase(mockRepository));

    test('returns Right when draft is saved successfully', () async {
      final paper = createMockPaper();
      when(() => mockRepository.saveDraft(any())).thenAnswer((_) async => Right(paper));

      final result = await useCase(paper);

      expect(result.isRight(), true);
      verify(() => mockRepository.saveDraft(any())).called(1);
    });

    test('returns Left when title is empty', () async {
      final paper = createMockPaper(title: '');

      final result = await useCase(paper);

      expect(result.isLeft(), true);
      result.fold((failure) => expect(failure, isA<ValidationFailure>()), (_) => fail('Should fail'));
    });
  });

  group('SubmitPaperUseCase', () {
    late SubmitPaperUseCase useCase;
    setUp(() => useCase = SubmitPaperUseCase(mockRepository));

    test('returns Right when paper is submitted successfully', () async {
      final paper = createMockPaper();
      final submittedPaper = createMockPaper(status: PaperStatus.submitted);
      when(() => mockRepository.submitPaper(any())).thenAnswer((_) async => Right(submittedPaper));

      final result = await useCase(paper);

      expect(result.isRight(), true);
    });
  });

  group('DeleteDraftUseCase', () {
    late DeleteDraftUseCase useCase;
    setUp(() => useCase = DeleteDraftUseCase(mockRepository));

    test('returns Right when draft is deleted', () async {
      when(() => mockRepository.deleteDraft(any())).thenAnswer((_) async => const Right(null));

      final result = await useCase('draft-123');

      expect(result.isRight(), true);
      verify(() => mockRepository.deleteDraft('draft-123')).called(1);
    });
  });

  group('GetDraftsUseCase', () {
    late GetDraftsUseCase useCase;
    setUp(() => useCase = GetDraftsUseCase(mockRepository));

    test('returns Right with list of drafts', () async {
      final drafts = [createMockPaper(), createMockPaper(id: 'paper-2')];
      when(() => mockRepository.getDrafts()).thenAnswer((_) async => Right(drafts));

      final result = await useCase();

      expect(result.isRight(), true);
      result.fold((_) => fail('Should not fail'), (papers) => expect(papers.length, 2));
    });
  });

  group('GetPaperByIdUseCase', () {
    late GetPaperByIdUseCase useCase;
    setUp(() => useCase = GetPaperByIdUseCase(mockRepository));

    test('returns Right with paper when found', () async {
      final paper = createMockPaper();
      when(() => mockRepository.getPaperById(any())).thenAnswer((_) async => Right(paper));

      final result = await useCase('paper-123');

      expect(result.isRight(), true);
    });
  });

  group('GetUserSubmissionsUseCase', () {
    late GetUserSubmissionsUseCase useCase;
    setUp(() => useCase = GetUserSubmissionsUseCase(mockRepository));

    test('returns Right with submissions', () async {
      final papers = [createMockPaper(status: PaperStatus.submitted)];
      when(() => mockRepository.getUserSubmissions()).thenAnswer((_) async => Right(papers));

      final result = await useCase();

      expect(result.isRight(), true);
    });
  });

  group('GetPapersForReviewUseCase', () {
    late GetPapersForReviewUseCase useCase;
    setUp(() => useCase = GetPapersForReviewUseCase(mockRepository));

    test('returns Right with papers for review', () async {
      final papers = [createMockPaper(status: PaperStatus.submitted)];
      when(() => mockRepository.getPapersForReview()).thenAnswer((_) async => Right(papers));

      final result = await useCase();

      expect(result.isRight(), true);
    });
  });

  group('GetAllPapersForAdminUseCase', () {
    late GetAllPapersForAdminUseCase useCase;
    setUp(() => useCase = GetAllPapersForAdminUseCase(mockRepository));

    test('returns Right with all papers', () async {
      final papers = [createMockPaper(), createMockPaper(id: 'paper-2')];
      when(() => mockRepository.getAllPapersForAdmin()).thenAnswer((_) async => Right(papers));

      final result = await useCase();

      expect(result.isRight(), true);
    });
  });

  group('GetApprovedPapersUseCase', () {
    late GetApprovedPapersUseCase useCase;
    setUp(() => useCase = GetApprovedPapersUseCase(mockRepository));

    test('returns Right with approved papers', () async {
      final papers = [createMockPaper(status: PaperStatus.approved)];
      when(() => mockRepository.getApprovedPapers()).thenAnswer((_) async => Right(papers));

      final result = await useCase();

      expect(result.isRight(), true);
    });
  });

  group('GetApprovedPapersPaginatedUseCase', () {
    late GetApprovedPapersPaginatedUseCase useCase;
    setUp(() => useCase = GetApprovedPapersPaginatedUseCase(mockRepository));

    test('returns Right with paginated results', () async {
      final papers = [createMockPaper(status: PaperStatus.approved)];
      final paginatedResult = PaginatedResult(
        items: papers,
        currentPage: 1,
        totalPages: 5,
        totalItems: 50,
        hasMore: true,
        pageSize: 10,
      );
      when(() => mockRepository.getApprovedPapersPaginated(
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
            searchQuery: any(named: 'searchQuery'),
            subjectFilter: any(named: 'subjectFilter'),
            gradeFilter: any(named: 'gradeFilter'),
          )).thenAnswer((_) async => Right(paginatedResult));

      final result = await useCase(page: 1, pageSize: 10);

      expect(result.isRight(), true);
    });
  });

  group('PullForEditingUseCase', () {
    late PullForEditingUseCase useCase;
    setUp(() => useCase = PullForEditingUseCase(mockRepository));

    test('returns Right when paper is pulled for editing', () async {
      final draftPaper = createMockPaper(status: PaperStatus.draft);
      when(() => mockRepository.pullForEditing(any())).thenAnswer((_) async => Right(draftPaper));

      final result = await useCase('paper-123');

      expect(result.isRight(), true);
    });

    test('returns Left when paper ID is empty', () async {
      final result = await useCase('');

      expect(result.isLeft(), true);
      result.fold((failure) => expect(failure, isA<ValidationFailure>()), (_) => fail('Should fail'));
    });
  });
}
