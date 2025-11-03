import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../../domain/repositories/admin_setup_repository.dart';
import '../datasources/admin_setup_remote_datasource.dart';

/// Implementation of AdminSetupRepository
class AdminSetupRepositoryImpl implements AdminSetupRepository {
  final AdminSetupRemoteDataSource remoteDataSource;

  AdminSetupRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<int>>> getAvailableGrades(String tenantId) async {
    try {
      final grades = await remoteDataSource.getAvailableGrades(tenantId);
      return Right(grades);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getSubjectSuggestions(int gradeNumber) async {
    try {
      final subjects = await remoteDataSource.getSubjectSuggestions(gradeNumber);
      return Right(subjects);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getTenantSubjects(String tenantId) async {
    try {
      final subjects = await remoteDataSource.getTenantSubjects(tenantId);
      return Right(subjects);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> createGrades({
    required String tenantId,
    required List<int> gradeNumbers,
  }) async {
    try {
      await remoteDataSource.createGrades(
        tenantId: tenantId,
        gradeNumbers: gradeNumbers,
      );
      return const Right(null);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure('Failed to create grades: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> createSections({
    required String tenantId,
    required int gradeNumber,
    required List<String> sections,
  }) async {
    try {
      await remoteDataSource.createSections(
        tenantId: tenantId,
        gradeNumber: gradeNumber,
        sections: sections,
      );
      return const Right(null);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure('Failed to create sections: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> createSubjectsForGrade({
    required String tenantId,
    required int gradeNumber,
    required List<String> subjectNames,
  }) async {
    try {
      await remoteDataSource.createSubjectsForGrade(
        tenantId: tenantId,
        gradeNumber: gradeNumber,
        subjectNames: subjectNames,
      );
      return const Right(null);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure('Failed to create subjects: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> updateTenantDetails({
    required String tenantId,
    required String name,
    required String? address,
  }) async {
    try {
      await remoteDataSource.updateTenantDetails(
        tenantId: tenantId,
        name: name,
        address: address,
      );
      return const Right(null);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure('Failed to update tenant details: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> markTenantInitialized(String tenantId) async {
    try {
      await remoteDataSource.markTenantInitialized(tenantId);
      return const Right(null);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure('Failed to mark tenant as initialized: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getSetupSummary(
    String tenantId,
  ) async {
    try {
      final summary = await remoteDataSource.getSetupSummary(tenantId);
      return Right(summary);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure('Failed to fetch setup summary: ${e.toString()}'));
    }
  }
}
