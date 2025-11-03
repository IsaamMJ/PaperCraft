import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../repositories/admin_setup_repository.dart';

/// Use case to get available grades for a tenant
class GetAvailableGradesUseCase {
  final AdminSetupRepository repository;

  GetAvailableGradesUseCase({required this.repository});

  Future<Either<Failure, List<int>>> call({required String tenantId}) {
    return repository.getAvailableGrades(tenantId);
  }
}
