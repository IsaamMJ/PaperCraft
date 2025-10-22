import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/core/domain/interfaces/i_logger.dart';
import 'package:papercraft/core/domain/models/paginated_result.dart';
import 'package:papercraft/features/authentication/domain/services/user_state_service.dart';
import 'package:papercraft/features/paper_workflow/data/datasources/paper_cloud_data_source.dart';
import 'package:papercraft/features/paper_workflow/data/datasources/paper_local_data_source.dart';
import 'package:papercraft/features/paper_workflow/data/models/question_paper_model.dart';
import 'package:papercraft/features/paper_workflow/data/repositories/question_paper_repository_impl.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/paper_status.dart';
import '../../../../../helpers/paper_workflow_helpers.dart';

class MockPaperLocalDataSource extends Mock implements PaperLocalDataSource {}
class MockPaperCloudDataSource extends Mock implements PaperCloudDataSource {}
class MockLogger extends Mock implements ILogger {}
class MockUserStateService extends Mock implements UserStateService {}

void main() {
  late QuestionPaperRepositoryImpl repository;
  late MockPaperLocalDataSource mockLocalDataSource;
  late MockPaperCloudDataSource mockCloudDataSource;
  late MockLogger mockLogger;
  late MockUserStateService mockUserStateService;

  setUpAll(() {
    registerFallbackValue(LogCategory.paper);
    registerFallbackValue(QuestionPaperModel.fromEntity(createMockPaper()));
  });

  setUp(() {
    mockLocalDataSource = MockPaperLocalDataSource();
    mockCloudDataSource = MockPaperCloudDataSource();
    mockLogger = MockLogger();
    mockUserStateService = MockUserStateService();
    when(() => mockLogger.debug(any(), category: any(named: 'category'), context: any(named: 'context'))).thenReturn(null);
    when(() => mockLogger.info(any(), category: any(named: 'category'), context: any(named: 'context'))).thenReturn(null);
    when(() => mockLogger.error(any(), category: any(named: 'category'), error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'), context: any(named: 'context'))).thenReturn(null);
    repository = QuestionPaperRepositoryImpl(mockLocalDataSource, mockCloudDataSource, mockLogger, mockUserStateService);
  });

  group('QuestionPaperRepository - saveDraft', () {
    test('returns Right when draft is saved successfully', () async {
      final paper = createMockPaper(status: PaperStatus.draft);
      when(() => mockLocalDataSource.saveDraft(any())).thenAnswer((_) async => Future.value());

      final result = await repository.saveDraft(paper);

      expect(result.isRight(), true);
      verify(() => mockLocalDataSource.saveDraft(any())).called(1);
    });

    test('returns Left with ValidationFailure when paper is not draft', () async {
      final paper = createMockPaper(status: PaperStatus.submitted);

      final result = await repository.saveDraft(paper);

      expect(result.isLeft(), true);
      result.fold((failure) => expect(failure, isA<ValidationFailure>()), (_) => fail('Should fail'));
    });
  });

  group('QuestionPaperRepository - getDrafts', () {
    test('returns Right with list of drafts', () async {
      final models = [QuestionPaperModel.fromEntity(createMockPaper())];
      when(() => mockLocalDataSource.getDrafts()).thenAnswer((_) async => models);

      final result = await repository.getDrafts();

      expect(result.isRight(), true);
      result.fold((_) => fail('Should not fail'), (drafts) => expect(drafts.length, 1));
    });
  });

  group('QuestionPaperRepository - submitPaper', () {
    test('returns Right when paper is submitted successfully', () async {
      final paper = createMockPaper(status: PaperStatus.draft);
      final submittedModel = QuestionPaperModel.fromEntity(createMockPaper(status: PaperStatus.submitted));

      when(() => mockUserStateService.currentTenantId).thenReturn('tenant-1');
      when(() => mockUserStateService.currentUserId).thenReturn('user-1');
      when(() => mockUserStateService.canCreatePapers()).thenReturn(true);
      when(() => mockCloudDataSource.getPaperById(any())).thenAnswer((_) async => null);
      when(() => mockCloudDataSource.submitPaper(any())).thenAnswer((_) async => submittedModel);
      when(() => mockLocalDataSource.deleteDraft(any())).thenAnswer((_) async => Future.value());

      final result = await repository.submitPaper(paper);

      expect(result.isRight(), true);
      verify(() => mockCloudDataSource.submitPaper(any())).called(1);
    });

    test('returns Left with AuthFailure when user not authenticated', () async {
      final paper = createMockPaper();
      when(() => mockUserStateService.currentTenantId).thenReturn(null);

      final result = await repository.submitPaper(paper);

      expect(result.isLeft(), true);
      result.fold((failure) => expect(failure, isA<AuthFailure>()), (_) => fail('Should fail'));
    });
  });

  group('QuestionPaperRepository - getPapersForReview', () {
    test('returns Right with papers for review when admin', () async {
      final models = [QuestionPaperModel.fromEntity(createMockPaper())];
      when(() => mockUserStateService.currentTenantId).thenReturn('tenant-1');
      when(() => mockUserStateService.canApprovePapers()).thenReturn(true);
      when(() => mockCloudDataSource.getPapersForReview(any())).thenAnswer((_) async => models);

      final result = await repository.getPapersForReview();

      expect(result.isRight(), true);
    });

    test('returns Left with PermissionFailure when not admin', () async {
      when(() => mockUserStateService.currentTenantId).thenReturn('tenant-1');
      when(() => mockUserStateService.canApprovePapers()).thenReturn(false);

      final result = await repository.getPapersForReview();

      expect(result.isLeft(), true);
      result.fold((failure) => expect(failure, isA<PermissionFailure>()), (_) => fail('Should fail'));
    });
  });

  group('QuestionPaperRepository - approvePaper', () {
    test('returns Right when paper is approved', () async {
      final approvedModel = QuestionPaperModel.fromEntity(createMockPaper(status: PaperStatus.approved));
      when(() => mockUserStateService.currentUserId).thenReturn('admin-1');
      when(() => mockUserStateService.canApprovePapers()).thenReturn(true);
      when(() => mockCloudDataSource.updatePaperStatus(any(), any(), reviewerId: any(named: 'reviewerId')))
          .thenAnswer((_) async => approvedModel);

      final result = await repository.approvePaper('paper-123');

      expect(result.isRight(), true);
    });
  });

  group('QuestionPaperRepository - rejectPaper', () {
    test('returns Right when paper is rejected', () async {
      final rejectedModel = QuestionPaperModel.fromEntity(createMockPaper(status: PaperStatus.rejected));
      when(() => mockUserStateService.currentUserId).thenReturn('admin-1');
      when(() => mockUserStateService.canApprovePapers()).thenReturn(true);
      when(() => mockCloudDataSource.updatePaperStatus(any(), any(), reason: any(named: 'reason'),
          reviewerId: any(named: 'reviewerId'))).thenAnswer((_) async => rejectedModel);

      final result = await repository.rejectPaper('paper-123', 'Needs improvement');

      expect(result.isRight(), true);
    });

    test('returns Left with ValidationFailure when reason is empty', () async {
      when(() => mockUserStateService.currentUserId).thenReturn('admin-1');
      when(() => mockUserStateService.canApprovePapers()).thenReturn(true);

      final result = await repository.rejectPaper('paper-123', '  ');

      expect(result.isLeft(), true);
      result.fold((failure) => expect(failure, isA<ValidationFailure>()), (_) => fail('Should fail'));
    });
  });
}
