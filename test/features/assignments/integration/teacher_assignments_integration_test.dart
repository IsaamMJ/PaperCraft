import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:papercraft/features/assignments/domain/entities/teacher_subject_assignment_entity.dart';
import 'package:papercraft/features/assignments/domain/usecases/delete_teacher_assignment_usecase.dart';
import 'package:papercraft/features/assignments/domain/usecases/get_assignment_stats_usecase.dart';
import 'package:papercraft/features/assignments/domain/usecases/load_teacher_assignments_usecase.dart';
import 'package:papercraft/features/assignments/domain/usecases/save_teacher_assignment_usecase.dart';
import 'package:papercraft/features/assignments/presentation/bloc/teacher_assignment_bloc.dart';
import 'package:papercraft/features/assignments/presentation/bloc/teacher_assignment_event.dart';
import 'package:papercraft/features/assignments/presentation/bloc/teacher_assignment_state.dart';

class MockLoadTeacherAssignmentsUseCase extends Mock implements LoadTeacherAssignmentsUseCase {}
class MockSaveTeacherAssignmentUseCase extends Mock implements SaveTeacherAssignmentUseCase {}
class MockDeleteTeacherAssignmentUseCase extends Mock implements DeleteTeacherAssignmentUseCase {}
class MockGetAssignmentStatsUseCase extends Mock implements GetAssignmentStatsUseCase {}

void main() {
  group('Teacher Assignments - Integration Tests', () {
    late TeacherAssignmentBloc bloc;
    late MockLoadTeacherAssignmentsUseCase mockLoadUseCase;
    late MockSaveTeacherAssignmentUseCase mockSaveUseCase;
    late MockDeleteTeacherAssignmentUseCase mockDeleteUseCase;
    late MockGetAssignmentStatsUseCase mockStatsUseCase;

    const initialAssignment = TeacherSubjectAssignmentEntity(
      id: 'a1', tenantId: 't1', teacherId: 'tr1', gradeId: 'g9',
      subjectId: 's1', teacherName: 'John', teacherEmail: 'john@test.com',
      gradeNumber: 9, section: 'A', subjectName: 'Math',
      academicYear: '2025-2026', startDate: null, endDate: null,
      isActive: true, createdAt: DateTime(2025, 1, 1), updatedAt: null,
    );

    const newAssignment = TeacherSubjectAssignmentEntity(
      id: 'a2', tenantId: 't1', teacherId: 'tr2', gradeId: 'g10',
      subjectId: 's2', teacherName: 'Jane', teacherEmail: 'jane@test.com',
      gradeNumber: 10, section: 'B', subjectName: 'Science',
      academicYear: '2025-2026', startDate: null, endDate: null,
      isActive: true, createdAt: DateTime(2025, 1, 1), updatedAt: null,
    );

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

    blocTest<TeacherAssignmentBloc, TeacherAssignmentState>(
      'Complete flow: Load, Save, Delete assignments',
      build: () {
        when(mockLoadUseCase(
          tenantId: 't1',
          teacherId: null,
          academicYear: '2025-2026',
          activeOnly: true,
        )).thenAnswer((_) async => const Right([initialAssignment]));

        when(mockSaveUseCase(newAssignment))
            .thenAnswer((_) async => const Right(null));

        when(mockDeleteUseCase('a1'))
            .thenAnswer((_) async => const Right(null));

        return bloc;
      },
      act: (bloc) {
        // Step 1: Load existing assignments
        bloc.add(const LoadTeacherAssignmentsEvent(tenantId: 't1'));
        // Step 2: Save new assignment
        bloc.add(const SaveTeacherAssignmentEvent(assignment: newAssignment));
        // Step 3: Delete assignment
        bloc.add(const DeleteTeacherAssignmentEvent(assignmentId: 'a1'));
      },
      expect: () => [
        isA<TeacherAssignmentsLoading>(),
        isA<TeacherAssignmentsLoaded>(),
        isA<TeacherAssignmentSaving>(),
        isA<TeacherAssignmentSaved>(),
        isA<TeacherAssignmentDeleting>(),
        isA<TeacherAssignmentDeleted>(),
      ],
    );

    blocTest<TeacherAssignmentBloc, TeacherAssignmentState>(
      'Load filtered assignments by teacher',
      build: () {
        when(mockLoadUseCase(
          tenantId: 't1',
          teacherId: 'tr1',
          academicYear: '2025-2026',
          activeOnly: true,
        )).thenAnswer((_) async => const Right([initialAssignment]));

        return bloc;
      },
      act: (bloc) => bloc.add(
        const LoadTeacherAssignmentsEvent(
          tenantId: 't1',
          teacherId: 'tr1',
        ),
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
      'Handle bulk save operations',
      build: () {
        when(mockSaveUseCase(initialAssignment))
            .thenAnswer((_) async => const Right(null));
        when(mockSaveUseCase(newAssignment))
            .thenAnswer((_) async => const Right(null));

        return bloc;
      },
      act: (bloc) {
        bloc.add(const SaveTeacherAssignmentEvent(assignment: initialAssignment));
        bloc.add(const SaveTeacherAssignmentEvent(assignment: newAssignment));
      },
      expect: () => [
        isA<TeacherAssignmentSaving>(),
        isA<TeacherAssignmentSaved>(),
        isA<TeacherAssignmentSaving>(),
        isA<TeacherAssignmentSaved>(),
      ],
    );
  });
}
