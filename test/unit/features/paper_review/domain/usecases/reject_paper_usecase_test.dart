import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/core/domain/interfaces/i_logger.dart';
import 'package:papercraft/features/notifications/domain/entities/notification_entity.dart';
import 'package:papercraft/features/notifications/domain/usecases/create_notification_usecase.dart';
import 'package:papercraft/features/paper_review/domain/usecases/reject_paper_usecase.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/paper_status.dart';
import 'package:papercraft/features/paper_workflow/domain/repositories/question_paper_repository.dart';
import '../../../../../helpers/paper_workflow_helpers.dart';

NotificationEntity _createMockNotification() => NotificationEntity(
  id: 'notif-1',
  userId: 'user-1',
  tenantId: 'tenant-1',
  type: NotificationType.paperRejected,
  title: 'Test',
  message: 'Test message',
  isRead: false,
  createdAt: DateTime.now(),
);

class MockQuestionPaperRepository extends Mock implements QuestionPaperRepository {}
class MockCreateNotificationUseCase extends Mock implements CreateNotificationUseCase {}
class MockLogger extends Mock implements ILogger {}

void main() {
  late RejectPaperUseCase useCase;
  late MockQuestionPaperRepository mockRepository;
  late MockCreateNotificationUseCase mockCreateNotification;
  late MockLogger mockLogger;

  setUpAll(() => registerFallbackValue(LogCategory.paper));

  setUp(() {
    mockRepository = MockQuestionPaperRepository();
    mockCreateNotification = MockCreateNotificationUseCase();
    mockLogger = MockLogger();
    when(() => mockLogger.info(any(), category: any(named: 'category'), context: any(named: 'context'))).thenReturn(null);
    when(() => mockLogger.warning(any(), category: any(named: 'category'), context: any(named: 'context'))).thenReturn(null);
    useCase = RejectPaperUseCase(mockRepository, mockCreateNotification, mockLogger);
  });

  group('RejectPaperUseCase - Success Cases', () {
    test('returns Right when paper is rejected successfully with valid reason', () async {
      final rejectedPaper = createMockPaper(status: PaperStatus.rejected, userId: 'user-1', tenantId: 'tenant-1',
          rejectionReason: 'Incomplete answers');

      when(() => mockRepository.rejectPaper(any(), any())).thenAnswer((_) async => Right(rejectedPaper));
      when(() => mockCreateNotification(userId: any(named: 'userId'), tenantId: any(named: 'tenantId'),
          type: any(named: 'type'), title: any(named: 'title'), message: any(named: 'message'),
          data: any(named: 'data'))).thenAnswer((_) async => Right(_createMockNotification()));

      final result = await useCase('paper-123', 'Incomplete answers');

      expect(result.isRight(), true);
      verify(() => mockRepository.rejectPaper('paper-123', 'Incomplete answers')).called(1);
    });

    test('trims whitespace from rejection reason before processing', () async {
      final rejectedPaper = createMockPaper(status: PaperStatus.rejected, userId: null, tenantId: null);

      when(() => mockRepository.rejectPaper(any(), any())).thenAnswer((_) async => Right(rejectedPaper));

      await useCase('paper-123', '   Trimmed reason   ');

      verify(() => mockRepository.rejectPaper('paper-123', 'Trimmed reason')).called(1);
    });
  });

  group('RejectPaperUseCase - Validation Failures', () {
    test('returns Left when rejection reason is empty', () async {
      final result = await useCase('paper-123', '');

      expect(result.isLeft(), true);
      result.fold((failure) => expect(failure, isA<ValidationFailure>()), (paper) => fail('Should not succeed'));
      verifyNever(() => mockRepository.rejectPaper(any(), any()));
    });

    test('returns Left when rejection reason is too short (less than 10 chars)', () async {
      final result = await useCase('paper-123', 'Too short');

      expect(result.isLeft(), true);
      result.fold((failure) => expect(failure, isA<ValidationFailure>()), (paper) => fail('Should not succeed'));
    });

    test('returns Left when rejection reason exceeds 500 characters', () async {
      final longReason = 'A' * 501;

      final result = await useCase('paper-123', longReason);

      expect(result.isLeft(), true);
      result.fold((failure) => expect(failure, isA<ValidationFailure>()), (paper) => fail('Should not succeed'));
    });

    test('accepts rejection reason with exactly 10 characters', () async {
      final rejectedPaper = createMockPaper(userId: null, tenantId: null);
      when(() => mockRepository.rejectPaper(any(), any())).thenAnswer((_) async => Right(rejectedPaper));

      final result = await useCase('paper-123', 'Exactly10!');

      expect(result.isRight(), true);
    });
  });

  group('RejectPaperUseCase - Notification Handling', () {
    test('succeeds even when notification fails', () async {
      final rejectedPaper = createMockPaper(status: PaperStatus.rejected, userId: 'user-1', tenantId: 'tenant-1');

      when(() => mockRepository.rejectPaper(any(), any())).thenAnswer((_) async => Right(rejectedPaper));
      when(() => mockCreateNotification(userId: any(named: 'userId'), tenantId: any(named: 'tenantId'),
          type: any(named: 'type'), title: any(named: 'title'), message: any(named: 'message'),
          data: any(named: 'data'))).thenThrow(Exception('Notification failed'));

      final result = await useCase('paper-123', 'Valid reason here');

      expect(result.isRight(), true);
    });

    test('does not send notification when userId is null', () async {
      final rejectedPaper = createMockPaper(userId: null, tenantId: 'tenant-1');

      when(() => mockRepository.rejectPaper(any(), any())).thenAnswer((_) async => Right(rejectedPaper));

      await useCase('paper-123', 'Valid reason');

      verifyNever(() => mockCreateNotification(userId: any(named: 'userId'), tenantId: any(named: 'tenantId'),
          type: any(named: 'type'), title: any(named: 'title'), message: any(named: 'message'),
          data: any(named: 'data')));
    });
  });

  group('RejectPaperUseCase - Repository Failures', () {
    test('returns Left when repository returns PermissionFailure', () async {
      when(() => mockRepository.rejectPaper(any(), any()))
          .thenAnswer((_) async => Left(PermissionFailure('Admin required')));

      final result = await useCase('paper-123', 'Valid reason');

      expect(result.isLeft(), true);
      result.fold((failure) => expect(failure, isA<PermissionFailure>()), (paper) => fail('Should not succeed'));
    });
  });
}
