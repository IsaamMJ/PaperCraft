import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:papercraft/features/assignments/domain/entities/teacher_subject_assignment_entity.dart';
import 'package:papercraft/features/assignments/domain/usecases/delete_teacher_assignment_usecase.dart';
import 'package:papercraft/features/assignments/domain/usecases/get_assignment_stats_usecase.dart';
import 'package:papercraft/features/assignments/domain/usecases/load_teacher_assignments_usecase.dart';
import 'package:papercraft/features/assignments/domain/usecases/save_teacher_assignment_usecase.dart';
import 'package:papercraft/features/assignments/presentation/bloc/teacher_assignment_bloc.dart';
import 'package:papercraft/features/assignments/presentation/bloc/teacher_assignment_event.dart';
import 'package:papercraft/features/assignments/presentation/bloc/teacher_assignment_state.dart';
import 'package:papercraft/core/domain/errors/failures.dart';

class MockLoadTeacherAssignmentsUseCase extends Mock implements LoadTeacherAssignmentsUseCase {}
class MockSaveTeacherAssignmentUseCase extends Mock implements SaveTeacherAssignmentUseCase {}
class MockDeleteTeacherAssignmentUseCase extends Mock implements DeleteTeacherAssignmentUseCase {}
class MockGetAssignmentStatsUseCase extends Mock implements GetAssignmentStatsUseCase {}

void main() {
  late TeacherAssignmentBloc bloc;
  late MockLoadTeacherAssignmentsUseCase mockLoadUseCase;
  late MockSaveTeacherAssignmentUseCase mockSaveUseCase;
  late MockDeleteTeacherAssignmentUseCase mockDeleteUseCase;
  late MockGetAssignmentStatsUseCase mockStatsUseCase;

  const testAssignments = [
    TeacherSubjectAssignmentEntity(
      id: 'a1', tenantId: 't1', teacherId: 'tr1', gradeId: 'g9',
      subjectId: 's1', teacherName: 'John', teacherEmail: 'john@test.com',
      gradeNumber: 9, section: 'A', subjectName: 'Math',
      academicYear: '2025-2026', startDate: null, endDate: null,
      isActive: true, createdAt: DateTime(2025, 1, 1), updatedAt: null,
    ),
  ];

  setUp(() {
    mockLoadUseCase = MockLoadTeacherAssignmentsUseCase();
    mockSaveUseCase = MockSaveTeacherAssignmentUseCase();
    mockDeleteUseCase = MockDeleteTeacherAssignmentUseCase();
    mockStatsUseCase = MockGetAssignmentStatsUseCase();

    bloc = TeacherAssignmentBloc(
      loadTeacherAssignmentsUseCase: mockLoadUseCase,
      saveTeacherAssignmentUseCase: mockSaveUseCase,
      deleteTeacherAssignmentUseCase: mockDeleteUseCase,
      getAssignmentStatsUseCase: mockStatsUseCase,
    );
  });

  tearDown(() {
    bloc.close();
  });

  group('TeacherAssignmentBloc', () {
    test('initial state is TeacherAssignmentInitial', () {
      expect(bloc.state, isA<TeacherAssignmentInitial>());
    });

    blocTest<TeacherAssignmentBloc, TeacherAssignmentState>(
      'emits [Loading, Loaded] when loading assignments succeeds',
      build: () {
        when(mockLoadUseCase(
          tenantId: 't1',
          teacherId: null,
          academicYear: '2025-2026',
          activeOnly: true,
        )).thenAnswer((_) async => const Right(testAssignments));
        return bloc;
      },
      act: (bloc) => bloc.add(
        const LoadTeacherAssignmentsEvent(tenantId: 't1'),
      ),
      expect: () => [
        isA<TeacherAssignmentsLoading>(),
        isA<TeacherAssignmentsLoaded>().having(
          (state) => state.assignments.length,
          'assignments count',
          1,
        ),
      ],
    );

    blocTest<TeacherAssignmentBloc, TeacherAssignmentState>(
      'emits [Loading, Error] when loading assignments fails',
      build: () {
        when(mockLoadUseCase(
          tenantId: 't1',
          teacherId: null,
          academicYear: '2025-2026',
          activeOnly: true,
        )).thenAnswer((_) async => Left(ServerFailure('Error')));
        return bloc;
      },
      act: (bloc) => bloc.add(
        const LoadTeacherAssignmentsEvent(tenantId: 't1'),
      ),
      expect: () => [
        isA<TeacherAssignmentsLoading>(),
        isA<TeacherAssignmentError>(),
      ],
    );

    blocTest<TeacherAssignmentBloc, TeacherAssignmentState>(
      'emits [Saving, Loaded] when saving assignment succeeds',
      build: () {
        when(mockSaveUseCase(any)).thenAnswer((_) async => const Right(null));
        return bloc;
      },
      act: (bloc) {
        bloc.add(const LoadTeacherAssignmentsEvent(tenantId: 't1'));
        bloc.add(
          const SaveTeacherAssignmentEvent(
            assignment: TeacherSubjectAssignmentEntity(
              id: 'a2', tenantId: 't1', teacherId: 'tr2', gradeId: 'g10',
              subjectId: 's2', teacherName: 'Jane', teacherEmail: 'jane@test.com',
              gradeNumber: 10, section: 'B', subjectName: 'Science',
              academicYear: '2025-2026', startDate: null, endDate: null,
              isActive: true, createdAt: DateTime(2025, 1, 1), updatedAt: null,
            ),
          ),
        );
      },
      expect: () => [
        isA<TeacherAssignmentInitial>(),
        isA<TeacherAssignmentSaving>(),
        isA<TeacherAssignmentSaved>(),
      ],
    );

    blocTest<TeacherAssignmentBloc, TeacherAssignmentState>(
      'emits [Deleting, Deleted] when deleting assignment succeeds',
      build: () {
        when(mockDeleteUseCase('a1')).thenAnswer((_) async => const Right(null));
        return bloc;
      },
      act: (bloc) => bloc.add(
        const DeleteTeacherAssignmentEvent(assignmentId: 'a1'),
      ),
      expect: () => [
        isA<TeacherAssignmentDeleting>(),
        isA<TeacherAssignmentDeleted>(),
      ],
    );

    blocTest<TeacherAssignmentBloc, TeacherAssignmentState>(
      'emits [Loading, Loaded] when refreshing stats',
      build: () {
        when(mockStatsUseCase(tenantId: 't1', academicYear: '2025-2026'))
            .thenAnswer((_) async => const Right({'9:A': 5, '10:B': 3}));
        return bloc;
      },
      act: (bloc) => bloc.add(
        const RefreshAssignmentStatsEvent(tenantId: 't1'),
      ),
      expect: () => [
        isA<TeacherAssignmentLoading>(),
        isA<TeacherAssignmentStatsUpdated>(),
      ],
    );

    blocTest<TeacherAssignmentBloc, TeacherAssignmentState>(
      'resets to initial state when clearing assignments',
      build: () => bloc,
      act: (bloc) => bloc.add(const ClearTeacherAssignmentsEvent()),
      expect: () => [
        isA<TeacherAssignmentInitial>(),
      ],
    );
  });
}
