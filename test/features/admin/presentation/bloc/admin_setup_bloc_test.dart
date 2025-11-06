import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/features/admin/domain/entities/admin_setup_grade.dart';
import 'package:papercraft/features/admin/domain/entities/admin_setup_section.dart';
import 'package:papercraft/features/admin/domain/entities/admin_setup_state.dart'
    as domain;
import 'package:papercraft/features/admin/domain/usecases/get_available_grades_usecase.dart';
import 'package:papercraft/features/admin/domain/usecases/get_subject_suggestions_usecase.dart';
import 'package:papercraft/features/admin/domain/usecases/save_admin_setup_usecase.dart';
import 'package:papercraft/features/admin/presentation/bloc/admin_setup_bloc.dart';
import 'package:papercraft/features/admin/presentation/bloc/admin_setup_event.dart';
import 'package:papercraft/features/admin/presentation/bloc/admin_setup_state.dart';

// Mock classes
class MockGetAvailableGradesUseCase extends Mock
    implements GetAvailableGradesUseCase {}

class MockGetSubjectSuggestionsUseCase extends Mock
    implements GetSubjectSuggestionsUseCase {}

class MockSaveAdminSetupUseCase extends Mock
    implements SaveAdminSetupUseCase {}

void main() {
  group('AdminSetupBloc Tests', () {
    late AdminSetupBloc adminSetupBloc;
    late MockGetAvailableGradesUseCase mockGetAvailableGradesUseCase;
    late MockGetSubjectSuggestionsUseCase mockGetSubjectSuggestionsUseCase;
    late MockSaveAdminSetupUseCase mockSaveAdminSetupUseCase;

    const testTenantId = 'test-tenant-id';

    setUp(() {
      mockGetAvailableGradesUseCase = MockGetAvailableGradesUseCase();
      mockGetSubjectSuggestionsUseCase = MockGetSubjectSuggestionsUseCase();
      mockSaveAdminSetupUseCase = MockSaveAdminSetupUseCase();

      adminSetupBloc = AdminSetupBloc(
        getAvailableGradesUseCase: mockGetAvailableGradesUseCase,
        getSubjectSuggestionsUseCase: mockGetSubjectSuggestionsUseCase,
        saveAdminSetupUseCase: mockSaveAdminSetupUseCase,
      );
    });

    tearDown(() {
      adminSetupBloc.close();
    });

    test('initial state is AdminSetupInitial', () {
      expect(adminSetupBloc.state, isA<AdminSetupInitial>());
    });

    group('Grade Management Tests', () {
      blocTest<AdminSetupBloc, AdminSetupUIState>(
        'should add grade successfully when valid grade number is provided',
        build: () => adminSetupBloc,
        act: (bloc) => bloc.add(const AddGradeEvent(gradeNumber: 9)),
        expect: () => [
          isA<AdminSetupUpdated>().having(
              (state) => (state as AdminSetupUpdated)
                  .setupState
                  .selectedGrades
                  .length,
              'grades count',
              1),
        ],
      );

      blocTest<AdminSetupBloc, AdminSetupUIState>(
        'should remove grade successfully when it exists',
        build: () => adminSetupBloc,
        seed: () => AdminSetupUpdated(
          setupState: domain.AdminSetupState(
            tenantId: testTenantId,
            selectedGrades: [
              AdminSetupGrade(
                gradeId: 'grade-9',
                gradeNumber: 9,
                sections: [],
              ),
            ],
          ),
        ),
        act: (bloc) => bloc.add(const RemoveGradeEvent(gradeNumber: 9)),
        expect: () => [
          isA<AdminSetupUpdated>().having(
              (state) => (state as AdminSetupUpdated)
                  .setupState
                  .selectedGrades
                  .length,
              'grades count',
              0),
        ],
      );

      blocTest<AdminSetupBloc, AdminSetupUIState>(
        'should prevent duplicate grades',
        build: () {
          when(mockGetAvailableGradesUseCase(tenantId: testTenantId))
              .thenAnswer((_) async => const Right([9, 10, 11, 12]));
          return adminSetupBloc;
        },
        act: (bloc) {
          // Initialize BLoC with tenant ID
          bloc.add(const InitializeAdminSetupEvent(tenantId: testTenantId));
          // Add first grade
          bloc.add(const AddGradeEvent(gradeNumber: 9));
          // Try to add same grade again (should be prevented)
          bloc.add(const AddGradeEvent(gradeNumber: 9));
        },
        expect: () => [
          // InitializeAdminSetupEvent emits AdminSetupUpdated
          isA<AdminSetupUpdated>(),
          // InitializeAdminSetupEvent also triggers LoadAvailableGradesEvent which emits LoadingGrades and GradesLoaded
          isA<LoadingGrades>(),
          isA<GradesLoaded>(),
          // First AddGradeEvent adds grade successfully
          isA<AdminSetupUpdated>().having(
              (state) => (state as AdminSetupUpdated).setupState.selectedGrades.length,
              'grades count after first add',
              1),
          // Second AddGradeEvent with duplicate should NOT emit anything (duplicate check prevents it)
        ],
      );
    });

    group('Section Management Tests', () {
      blocTest<AdminSetupBloc, AdminSetupUIState>(
        'should add section successfully to a grade',
        build: () => adminSetupBloc,
        seed: () => AdminSetupUpdated(
          setupState: domain.AdminSetupState(
            tenantId: testTenantId,
            selectedGrades: [
              AdminSetupGrade(
                gradeId: 'grade-9',
                gradeNumber: 9,
                sections: [],
              ),
            ],
          ),
        ),
        act: (bloc) => bloc.add(
            const AddSectionEvent(gradeNumber: 9, sectionName: 'A')),
        expect: () => [
          isA<AdminSetupUpdated>(),
        ],
      );

      blocTest<AdminSetupBloc, AdminSetupUIState>(
        'should remove section successfully from a grade',
        build: () => adminSetupBloc,
        seed: () => AdminSetupUpdated(
          setupState: domain.AdminSetupState(
            tenantId: testTenantId,
            selectedGrades: [
              AdminSetupGrade(
                gradeId: 'grade-9',
                gradeNumber: 9,
                sections: [
                  AdminSetupSection(sectionName: 'A', subjects: []),
                ],
              ),
            ],
          ),
        ),
        act: (bloc) => bloc.add(
            const RemoveSectionEvent(gradeNumber: 9, sectionName: 'A')),
        expect: () => [
          isA<AdminSetupUpdated>(),
        ],
      );
    });

    group('Subject Management Tests', () {
      blocTest<AdminSetupBloc, AdminSetupUIState>(
        'should load subject suggestions successfully',
        build: () {
          when(mockGetSubjectSuggestionsUseCase(gradeNumber: 9))
              .thenAnswer((_) async =>
                  const Right(['Math', 'English', 'Science']));
          return adminSetupBloc;
        },
        act: (bloc) =>
            bloc.add(const LoadSubjectSuggestionsEvent(gradeNumber: 9)),
        expect: () => [
          isA<LoadingSubjectSuggestions>(),
          isA<SubjectSuggestionsLoaded>().having(
              (state) => (state as SubjectSuggestionsLoaded).suggestions.length,
              'suggestions count',
              3),
        ],
      );

      blocTest<AdminSetupBloc, AdminSetupUIState>(
        'should add subject successfully to a grade',
        build: () => adminSetupBloc,
        seed: () => AdminSetupUpdated(
          setupState: domain.AdminSetupState(
            tenantId: testTenantId,
            selectedGrades: [
              AdminSetupGrade(
                gradeId: 'grade-9',
                gradeNumber: 9,
                sections: [
                  AdminSetupSection(sectionName: 'A', subjects: []),
                ],
              ),
            ],
          ),
        ),
        act: (bloc) => bloc.add(
            const AddSubjectEvent(gradeNumber: 9, subjectName: 'Math')),
        expect: () => [
          isA<AdminSetupUpdated>(),
        ],
      );
    });

    group('Step Navigation Tests', () {
      blocTest<AdminSetupBloc, AdminSetupUIState>(
        'should move to next step when validation passes',
        build: () {
          when(mockGetAvailableGradesUseCase(tenantId: testTenantId))
              .thenAnswer((_) async => const Right([9, 10, 11, 12]));
          return adminSetupBloc;
        },
        act: (bloc) {
          // Initialize BLoC
          bloc.add(const InitializeAdminSetupEvent(tenantId: testTenantId));
          // Add grade
          bloc.add(const AddGradeEvent(gradeNumber: 9));
          // Add section to grade (required for step 1 to pass)
          bloc.add(const AddSectionEvent(gradeNumber: 9, sectionName: 'A'));
          // Now move to next step
          bloc.add(const NextStepEvent());
        },
        expect: () => [
          isA<AdminSetupUpdated>(), // Initialize
          isA<LoadingGrades>(), // Load grades triggered by Initialize
          isA<GradesLoaded>(), // Grades loaded
          isA<AdminSetupUpdated>(), // Add grade
          isA<AdminSetupUpdated>(), // Add section
          isA<AdminSetupUpdated>(), // Move to next step
        ],
      );

      blocTest<AdminSetupBloc, AdminSetupUIState>(
        'should not move to next step when validation fails on step 1',
        build: () => adminSetupBloc,
        seed: () => AdminSetupUpdated(
          setupState: domain.AdminSetupState(
            tenantId: testTenantId,
            selectedGrades: [],
          ),
        ),
        act: (bloc) => bloc.add(const NextStepEvent()),
        expect: () => [
          isA<StepValidationFailed>(),
        ],
      );

      blocTest<AdminSetupBloc, AdminSetupUIState>(
        'should move to previous step',
        build: () => adminSetupBloc,
        seed: () => AdminSetupUpdated(
          setupState: domain.AdminSetupState(
            tenantId: testTenantId,
            selectedGrades: [
              AdminSetupGrade(
                gradeId: 'grade-9',
                gradeNumber: 9,
                sections: [
                  AdminSetupSection(sectionName: 'A', subjects: ['Math']),
                ],
              ),
            ],
          ),
        ),
        act: (bloc) => bloc.add(const PreviousStepEvent()),
        expect: () => [
          isA<AdminSetupUpdated>(),
        ],
      );
    });

    group('Save Admin Setup Tests', () {
      blocTest<AdminSetupBloc, AdminSetupUIState>(
        'should save admin setup successfully',
        build: () {
          when(mockGetAvailableGradesUseCase(tenantId: testTenantId))
              .thenAnswer((_) async => const Right([9, 10, 11, 12]));

          final setupState = const domain.AdminSetupState(
            tenantId: testTenantId,
          );
          when(mockSaveAdminSetupUseCase(
            setupState: setupState,
            tenantName: null,
            tenantAddress: null,
          )).thenAnswer((_) async => const Right(null));
          return adminSetupBloc;
        },
        act: (bloc) {
          // Initialize BLoC with tenant ID
          bloc.add(const InitializeAdminSetupEvent(tenantId: testTenantId));
          // Setup the grades, sections, and subjects
          bloc.add(const AddGradeEvent(gradeNumber: 9));
          bloc.add(const AddSectionEvent(gradeNumber: 9, sectionName: 'A'));
          bloc.add(const AddSubjectEvent(gradeNumber: 9, subjectName: 'Math'));
          // Now save
          bloc.add(const SaveAdminSetupEvent());
        },
        expect: () => [
          isA<AdminSetupUpdated>(), // Initialize
          isA<LoadingGrades>(), // Load grades triggered by Initialize
          isA<GradesLoaded>(), // Grades loaded
          isA<AdminSetupUpdated>(), // Add grade
          isA<AdminSetupUpdated>(), // Add section
          isA<AdminSetupUpdated>(), // Add subject
          isA<SavingAdminSetup>(), // Save starts
          isA<AdminSetupSaved>(), // Save completes successfully
        ],
      );
    });

    group('School Details Update Tests', () {
      blocTest<AdminSetupBloc, AdminSetupUIState>(
        'should update school details successfully',
        build: () => adminSetupBloc,
        act: (bloc) => bloc.add(
          const UpdateSchoolDetailsEvent(
            schoolName: 'My School',
            schoolAddress: '123 Main St',
          ),
        ),
        expect: () => [
          isA<AdminSetupUpdated>(),
        ],
      );
    });
  });
}
