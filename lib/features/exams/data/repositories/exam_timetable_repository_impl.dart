import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../../domain/entities/exam_timetable.dart';
import '../../domain/entities/exam_timetable_entry.dart';
import '../../domain/repositories/exam_timetable_repository.dart';
import '../datasources/exam_timetable_remote_datasource.dart';

/// Implementation of ExamTimetableRepository using Supabase
class ExamTimetableRepositoryImpl implements ExamTimetableRepository {
  final ExamTimetableRemoteDataSource remoteDataSource;

  ExamTimetableRepositoryImpl({required this.remoteDataSource});

  // ========== TIMETABLE CRUD ==========

  @override
  Future<Either<Failure, ExamTimetable>> createTimetable(
    ExamTimetable timetable,
  ) async {
    try {
      final createdTimetable = await remoteDataSource.createTimetable(timetable);
      return Right(createdTimetable);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to create timetable: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, ExamTimetable?>> getTimetableById(String id) async {
    try {
      final timetable = await remoteDataSource.getTimetableById(id);
      return Right(timetable);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to fetch timetable: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<ExamTimetable>>> getTimetablesForTenant({
    required String tenantId,
    String? academicYear,
    TimetableStatus? status,
    bool activeOnly = true,
  }) async {
    try {
      final timetables = await remoteDataSource.getTimetablesForTenant(
        tenantId: tenantId,
        academicYear: academicYear,
        status: status?.toShortString(),
        activeOnly: activeOnly,
      );

      return Right(timetables);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to fetch timetables: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> updateTimetable(ExamTimetable timetable) async {
    try {
      await remoteDataSource.updateTimetable(timetable);
      return const Right(null);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to update timetable: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> updateTimetableStatus({
    required String timetableId,
    required TimetableStatus status,
    DateTime? publishedAt,
  }) async {
    try {
      await remoteDataSource.updateTimetableStatus(
        timetableId: timetableId,
        status: status.toShortString(),
        publishedAt: publishedAt,
      );

      return const Right(null);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to update timetable status: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> deleteTimetable(String timetableId) async {
    try {
      await remoteDataSource.deleteTimetable(timetableId);
      return const Right(null);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to delete timetable: ${e.toString()}'),
      );
    }
  }

  // ========== TIMETABLE ENTRIES CRUD ==========

  @override
  Future<Either<Failure, ExamTimetableEntry>> addTimetableEntry(
    ExamTimetableEntry entry,
  ) async {
    try {
      final createdEntry = await remoteDataSource.addTimetableEntry(entry);
      return Right(createdEntry);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to add timetable entry: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<ExamTimetableEntry>>> getTimetableEntries(
    String timetableId,
  ) async {
    try {
      final entries = await remoteDataSource.getTimetableEntries(timetableId);
      return Right(entries);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to fetch timetable entries: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<ExamTimetableEntry>>> getTimetableEntriesByGrade({
    required String timetableId,
    required String gradeId,
  }) async {
    try {
      final entries = await remoteDataSource.getTimetableEntriesByGrade(
        timetableId: timetableId,
        gradeId: gradeId,
      );

      return Right(entries);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to fetch entries by grade: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, ExamTimetableEntry?>> getTimetableEntryById(
    String id,
  ) async {
    try {
      final entry = await remoteDataSource.getTimetableEntryById(id);
      return Right(entry);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to fetch timetable entry: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> updateTimetableEntry(
    ExamTimetableEntry entry,
  ) async {
    try {
      await remoteDataSource.updateTimetableEntry(entry);
      return const Right(null);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to update timetable entry: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> removeTimetableEntry(String entryId) async {
    try {
      await remoteDataSource.removeTimetableEntry(entryId);
      return const Right(null);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to remove timetable entry: ${e.toString()}'),
      );
    }
  }

  // ========== TIMETABLE ENTRY QUERIES ==========

  @override
  Future<Either<Failure, int>> countTimetableEntries(String timetableId) async {
    try {
      final count = await remoteDataSource.countTimetableEntries(timetableId);
      return Right(count);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to count timetable entries: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> entryExists({
    required String timetableId,
    required String gradeId,
    required String subjectId,
    required String section,
  }) async {
    try {
      final exists = await remoteDataSource.entryExists(
        timetableId: timetableId,
        gradeId: gradeId,
        subjectId: subjectId,
        section: section,
      );

      return Right(exists);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to check entry existence: ${e.toString()}'),
      );
    }
  }

  // ========== VALIDATION METHODS (PLACEHOLDER) ==========
  // These will be implemented in validation service layer

  @override
  Future<Either<Failure, PaperCountResult>> calculateExpectedPaperCount({
    required String timetableId,
  }) async {
    // TODO: Implement with teacher lookup
    return const Left(
      ServerFailure('Not yet implemented'),
    );
  }

  @override
  Future<Either<Failure, List<ValidationError>>> validateForPublishing({
    required String timetableId,
  }) async {
    // TODO: Implement validation logic
    return const Left(
      ServerFailure('Not yet implemented'),
    );
  }
}
