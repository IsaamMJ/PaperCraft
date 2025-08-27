import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../domain/entities/subject_entity.dart';
import '../../domain/entities/grade_entity.dart';
import '../../domain/entities/user_permissions_entity.dart';
import '../../domain/usecases/get_exam_types.dart';
import '../../domain/usecases/get_subjects.dart';
import '../../domain/usecases/get_grades.dart';
import '../../domain/usecases/get_user_permissions.dart';
import '../../domain/usecases/get_filtered_subjects.dart';
import '../../domain/usecases/get_filtered_grades.dart';
import '../../domain/usecases/can_create_paper.dart';
import 'qps_event.dart';
import 'qps_state.dart';

class QpsBloc extends Bloc<QpsEvent, QpsState> {
  final GetExamTypes getExamTypes;
  final GetSubjects getSubjects;
  final GetGrades getGrades;
  final GetUserPermissions getUserPermissions;
  final GetFilteredSubjects getFilteredSubjects;
  final GetFilteredGrades getFilteredGrades;
  final CanCreatePaper canCreatePaper;

  QpsBloc({
    required this.getExamTypes,
    required this.getSubjects,
    required this.getGrades,
    required this.getUserPermissions,
    required this.getFilteredSubjects,
    required this.getFilteredGrades,
    required this.canCreatePaper,
  }) : super(QpsInitial()) {
    on<LoadQpsData>(_onLoadQpsData);
    on<ValidatePermissions>(_onValidatePermissions);
  }

  Future<void> _onLoadQpsData(LoadQpsData event, Emitter<QpsState> emit) async {
    emit(QpsLoading());

    try {
      // Load all data concurrently
      final results = await Future.wait([
        getExamTypes(),
        getSubjects(),
        getGrades(),
        getFilteredSubjects(),
        getFilteredGrades(),
        getUserPermissions(),
      ]);

      final examTypes = results[0] as List<ExamTypeEntity>;
      final subjects = results[1] as List<SubjectEntity>;
      final grades = results[2] as List<GradeEntity>;
      final filteredSubjects = results[3] as List<SubjectEntity>;
      final filteredGrades = results[4] as List<GradeEntity>;
      final userPermissions = results[5] as UserPermissionsEntity?;

      // Determine if user is admin (has access to all subjects and grades)
      final isAdmin = filteredSubjects.length == subjects.length &&
          filteredGrades.length == grades.length;

      emit(QpsLoaded(
        examTypes: examTypes,
        subjects: subjects,
        grades: grades,
        filteredSubjects: filteredSubjects,
        filteredGrades: filteredGrades,
        userPermissions: userPermissions,
        isAdmin: isAdmin,
      ));
    } catch (e) {
      emit(QpsError(error: 'Failed to load QPS data: ${e.toString()}'));
    }
  }

  Future<void> _onValidatePermissions(
      ValidatePermissions event,
      Emitter<QpsState> emit,
      ) async {
    try {
      final canCreate = await canCreatePaper(event.subjectId, event.gradeLevel);
      final message = canCreate
          ? 'You can create papers for this subject and grade'
          : 'You do not have permission to create papers for this subject and grade';

      emit(QpsPermissionValidated(canCreate: canCreate, message: message));
    } catch (e) {
      emit(QpsError(error: 'Failed to validate permissions: ${e.toString()}'));
    }
  }
}