import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/core/domain/interfaces/i_logger.dart';
import 'package:papercraft/features/notifications/domain/entities/notification_entity.dart';
import 'package:papercraft/features/notifications/domain/usecases/create_notification_usecase.dart';
import 'package:papercraft/features/paper_review/domain/usecases/approve_paper_usecase.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/paper_status.dart';
import 'package:papercraft/features/paper_workflow/domain/repositories/question_paper_repository.dart';
import '../../../../../helpers/paper_workflow_helpers.dart';

NotificationEntity _createMockNotification() => NotificationEntity(
  id: 'notif-1',
  userId: 'user-1',
  tenantId: 'tenant-1',
  type: NotificationType.paperApproved,
  title: 'Test',
  message: 'Test message',
  isRead: false,
  createdAt: DateTime.now(),
);

class MockQuestionPaperRepository extends Mock implements QuestionPaperRepository {}
class MockCreateNotificationUseCase extends Mock implements CreateNotificationUseCase {}
class MockLogger extends Mock implements ILogger {}

void main() {
  late ApprovePaperUseCase useCase;
  late MockQuestionPaperRepository mockRepository;
  late MockCreateNotificationUseCase mockCreateNotification;
  late MockLogger mockLogger;

  setUpAll(() {
    registerFallbackValue(LogCategory.paper);
  });

  setUp(() {
    mockRepository = MockQuestionPaperRepository();
    mockCreateNotification = MockCreateNotificationUseCase();
    mockLogger = MockLogger();
    when(() => mockLogger.info(any(), category: any(named: 'category'), context: any(named: 'context'))).thenReturn(null);
    when(() => mockLogger.warning(any(), category: any(named: 'category'), context: any(named: 'context'))).thenReturn(null);
    useCase = ApprovePaperUseCase(mockRepository, mockCreateNotification, mockLogger);
  });

  group('ApprovePaperUseCase - Success Cases', () {
    test('returns Right when paper is approved successfully', () async {
      final approvedPaper = createMockPaper(status: PaperStatus.approved, userId: 'user-1', tenantId: 'tenant-1');

      when(() => mockRepository.approvePaper(any())).thenAnswer((_) async => Right(approvedPaper));
      when(() => mockCreateNotification(
            userId: any(named: 'userId'),
            tenantId: any(named: 'tenantId'),
            type: any(named: 'type'),
            title: any(named: 'title'),
            message: any(named: 'message'),
            data: any(named: 'data'),
          )).thenAnswer((_) async => Right(_createMockNotification()));

      final result = await useCase('paper-123');

      expect(result.isRight(), true);
      result.fold((failure) => fail('Should not fail'), (paper) {
        expect(paper.status, PaperStatus.approved);
        expect(paper.id, 'paper-123');
      });
      verify(() => mockRepository.approvePaper('paper-123')).called(1);
    });

    test('logs approval notification sent', () async {
      final approvedPaper = createMockPaper(status: PaperStatus.approved, userId: 'user-1', tenantId: 'tenant-1');

      when(() => mockRepository.approvePaper(any())).thenAnswer((_) async => Right(approvedPaper));
      when(() => mockCreateNotification(
            userId: any(named: 'userId'),
            tenantId: any(named: 'tenantId'),
            type: any(named: 'type'),
            title: any(named: 'title'),
            message: any(named: 'message'),
            data: any(named: 'data'),
          )).thenAnswer((_) async => Right(_createMockNotification()));

      await useCase('paper-123');

      verify(() => mockLogger.info('Approval notification sent', category: LogCategory.paper,
          context: {'paperId': 'paper-123', 'userId': 'user-1'})).called(1);
    });
  });

  group('ApprovePaperUseCase - Without Notification', () {
    test('succeeds even when userId is null', () async {
      final approvedPaper = createMockPaper(status: PaperStatus.approved, userId: null, tenantId: 'tenant-1');

      when(() => mockRepository.approvePaper(any())).thenAnswer((_) async => Right(approvedPaper));

      final result = await useCase('paper-123');

      expect(result.isRight(), true);
      verifyNever(() => mockCreateNotification(
            userId: any(named: 'userId'),
            tenantId: any(named: 'tenantId'),
            type: any(named: 'type'),
            title: any(named: 'title'),
            message: any(named: 'message'),
            data: any(named: 'data'),
          ));
    });

    test('succeeds even when tenantId is null', () async {
      final approvedPaper = createMockPaper(status: PaperStatus.approved, userId: 'user-1', tenantId: null);

      when(() => mockRepository.approvePaper(any())).thenAnswer((_) async => Right(approvedPaper));

      final result = await useCase('paper-123');

      expect(result.isRight(), true);
      verifyNever(() => mockCreateNotification(
            userId: any(named: 'userId'),
            tenantId: any(named: 'tenantId'),
            type: any(named: 'type'),
            title: any(named: 'title'),
            message: any(named: 'message'),
            data: any(named: 'data'),
          ));
    });
  });

  group('ApprovePaperUseCase - Notification Failures', () {
    test('succeeds even when notification fails', () async {
      final approvedPaper = createMockPaper(status: PaperStatus.approved, userId: 'user-1', tenantId: 'tenant-1');

      when(() => mockRepository.approvePaper(any())).thenAnswer((_) async => Right(approvedPaper));
      when(() => mockCreateNotification(
            userId: any(named: 'userId'),
            tenantId: any(named: 'tenantId'),
            type: any(named: 'type'),
            title: any(named: 'title'),
            message: any(named: 'message'),
            data: any(named: 'data'),
          )).thenThrow(Exception('Notification service down'));

      final result = await useCase('paper-123');

      expect(result.isRight(), true);
    });

    test('logs warning when notification fails', () async {
      final approvedPaper = createMockPaper(status: PaperStatus.approved, userId: 'user-1', tenantId: 'tenant-1');

      when(() => mockRepository.approvePaper(any())).thenAnswer((_) async => Right(approvedPaper));
      when(() => mockCreateNotification(
            userId: any(named: 'userId'),
            tenantId: any(named: 'tenantId'),
            type: any(named: 'type'),
            title: any(named: 'title'),
            message: any(named: 'message'),
            data: any(named: 'data'),
          )).thenThrow(Exception('Service error'));

      await useCase('paper-123');

      verify(() => mockLogger.warning('Failed to send approval notification',
          category: LogCategory.system, context: any(named: 'context'))).called(1);
    });
  });

  group('ApprovePaperUseCase - Repository Failures', () {
    test('returns Left when repository returns PermissionFailure', () async {
      when(() => mockRepository.approvePaper(any()))
          .thenAnswer((_) async => Left(PermissionFailure('Admin required')));

      final result = await useCase('paper-123');

      expect(result.isLeft(), true);
      result.fold((failure) => expect(failure, isA<PermissionFailure>()), (paper) => fail('Should not succeed'));
    });

    test('returns Left when repository returns ServerFailure', () async {
      when(() => mockRepository.approvePaper(any()))
          .thenAnswer((_) async => Left(ServerFailure('Database error')));

      final result = await useCase('paper-123');

      expect(result.isLeft(), true);
      result.fold((failure) => expect(failure, isA<ServerFailure>()), (paper) => fail('Should not succeed'));
    });
  });
}
