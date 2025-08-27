import 'package:equatable/equatable.dart';

abstract class QpsEvent extends Equatable {
  const QpsEvent();

  @override
  List<Object> get props => [];
}

class LoadQpsData extends QpsEvent {}

class ValidatePermissions extends QpsEvent {
  final String subjectId;
  final int gradeLevel;

  const ValidatePermissions(this.subjectId, this.gradeLevel);

  @override
  List<Object> get props => [subjectId, gradeLevel];
}