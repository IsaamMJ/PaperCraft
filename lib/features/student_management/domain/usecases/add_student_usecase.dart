import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/core/domain/usecases/usecase.dart';
import 'package:papercraft/features/student_management/domain/entities/student_entity.dart';
import 'package:papercraft/features/student_management/domain/repositories/student_repository.dart';

class AddStudentUseCase implements UseCase<StudentEntity, AddStudentParams> {
  final StudentRepository repository;

  AddStudentUseCase(this.repository);

  @override
  Future<Either<Failure, StudentEntity>> call(AddStudentParams params) async {
    return await repository.addStudent(
      gradeSectionId: params.gradeSectionId,
      rollNumber: params.rollNumber,
      fullName: params.fullName,
      email: params.email,
      phone: params.phone,
    );
  }
}

class AddStudentParams extends Equatable {
  final String gradeSectionId;
  final String rollNumber;
  final String fullName;
  final String? email;
  final String? phone;

  const AddStudentParams({
    required this.gradeSectionId,
    required this.rollNumber,
    required this.fullName,
    this.email,
    this.phone,
  });

  @override
  List<Object?> get props => [gradeSectionId, rollNumber, fullName, email, phone];
}
