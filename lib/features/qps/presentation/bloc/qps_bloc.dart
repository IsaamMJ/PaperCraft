// presentation/bloc/qps_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../domain/entities/subject_entity.dart';
import '../../domain/usecases/get_exam_types.dart';
import '../../domain/usecases/get_subjects.dart';

part 'qps_event.dart';
part 'qps_state.dart';

class QpsBloc extends Bloc<QpsEvent, QpsState> {
  final GetExamTypes getExamTypes;
  final GetSubjects getSubjects;

  QpsBloc({required this.getExamTypes, required this.getSubjects}) : super(QpsLoading()) {
    on<LoadQpsData>((event, emit) async {
      emit(QpsLoading());
      try {
        final examTypes = await getExamTypes();
        final subjects = await getSubjects();
        emit(QpsLoaded(examTypes: examTypes, subjects: subjects));
      } catch (e) {
        emit(QpsError(error: e.toString()));
      }
    });
  }
}
