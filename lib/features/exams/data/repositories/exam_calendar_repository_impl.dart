import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../../domain/entities/exam_calendar.dart';
import '../../domain/repositories/exam_calendar_repository.dart';
import '../datasources/exam_calendar_remote_datasource.dart';

/// Implementation of ExamCalendarRepository using Supabase
class ExamCalendarRepositoryImpl implements ExamCalendarRepository {
  final ExamCalendarRemoteDataSource remoteDataSource;

  ExamCalendarRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<ExamCalendar>>> getExamCalendars({
    required String tenantId,
    String? academicYear,
    bool activeOnly = true,
    bool sortByMonth = true,
  }) async {
    try {
      final calendars = await remoteDataSource.getExamCalendars(
        tenantId: tenantId,
        academicYear: academicYear,
        activeOnly: activeOnly,
        sortByMonth: sortByMonth,
      );

      return Right(calendars);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to fetch exam calendars: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, ExamCalendar?>> getExamCalendarById(String id) async {
    try {
      final calendar = await remoteDataSource.getExamCalendarById(id);
      return Right(calendar);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to fetch exam calendar: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, ExamCalendar?>> getExamCalendarByName({
    required String tenantId,
    required String examName,
  }) async {
    try {
      final calendar = await remoteDataSource.getExamCalendarByName(
        tenantId: tenantId,
        examName: examName,
      );

      return Right(calendar);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to fetch exam calendar by name: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, ExamCalendar>> createExamCalendar(
    ExamCalendar calendar,
  ) async {
    try {
      final createdCalendar = await remoteDataSource.createExamCalendar(calendar);
      return Right(createdCalendar);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to create exam calendar: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> updateExamCalendar(ExamCalendar calendar) async {
    try {
      await remoteDataSource.updateExamCalendar(calendar);
      return const Right(null);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to update exam calendar: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> deleteExamCalendar(String id) async {
    try {
      await remoteDataSource.deleteExamCalendar(id);
      return const Right(null);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to delete exam calendar: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<ExamCalendar>>> getExamsForMonth({
    required String tenantId,
    required int monthNumber,
    bool activeOnly = true,
  }) async {
    try {
      final exams = await remoteDataSource.getExamsForMonth(
        tenantId: tenantId,
        monthNumber: monthNumber,
        activeOnly: activeOnly,
      );

      return Right(exams);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to fetch exams for month: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<ExamCalendar>>> getUpcomingExams({
    required String tenantId,
    bool activeOnly = true,
  }) async {
    try {
      final exams = await remoteDataSource.getUpcomingExams(
        tenantId: tenantId,
        activeOnly: activeOnly,
      );

      return Right(exams);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to fetch upcoming exams: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> examNameExists({
    required String tenantId,
    required String examName,
  }) async {
    try {
      final exists = await remoteDataSource.examNameExists(
        tenantId: tenantId,
        examName: examName,
      );

      return Right(exists);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to check exam name: ${e.toString()}'),
      );
    }
  }
}
