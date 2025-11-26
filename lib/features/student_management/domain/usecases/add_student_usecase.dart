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
      gender: params.gender,
      dateOfBirth: params.dateOfBirth,
      gradeNumber: params.gradeNumber,
      sectionName: params.sectionName,
    );
  }
}

class AddStudentParams extends Equatable {
  final String gradeSectionId;
  final String rollNumber;
  final String fullName;
  final String? email;
  final String? phone;
  final String? gender;
  final DateTime? dateOfBirth;
  final int? gradeNumber;
  final String? sectionName;

  const AddStudentParams({
    required this.gradeSectionId,
    required this.rollNumber,
    required this.fullName,
    this.email,
    this.phone,
    this.gender,
    this.dateOfBirth,
    this.gradeNumber,
    this.sectionName,
  });

  @override
  List<Object?> get props => [
        gradeSectionId,
        rollNumber,
        fullName,
        email,
        phone,
        gender,
        dateOfBirth,
        gradeNumber,
        sectionName,
      ];
}
