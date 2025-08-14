part of 'qps_bloc.dart';

abstract class QpsState {}
class QpsLoading extends QpsState {}
class QpsLoaded extends QpsState {
  final List<ExamTypeEntity> examTypes;
  final List<SubjectEntity> subjects;

  QpsLoaded({required this.examTypes, required this.subjects});
}
class QpsError extends QpsState {
  final String error;
  QpsError({required this.error});
}
