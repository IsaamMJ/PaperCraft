import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/features/catalog/domain/entities/grade_section.dart';
import 'package:papercraft/features/catalog/domain/repositories/grade_section_repository.dart';
import 'package:papercraft/features/catalog/domain/usecases/load_grade_sections_usecase.dart';

import '../../../../test_helpers.dart';

@GenerateMocks([GradeSectionRepository])
void main() {
  group('LoadGradeSectionsUseCase', () {
    late MockGradeSectionRepository mockRepository;
    late LoadGradeSectionsUseCase usecase;

    setUp(() {
      mockRepository = MockGradeSectionRepository();
      usecase = LoadGradeSectionsUseCase(repository: mockRepository);
    });

    test('should return list of grade sections when repository succeeds', () async {
      // Arrange
      final mockSections = [
        GradeSectionBuilder().buildJson(),
        GradeSectionBuilder()
            .withSectionName('B')
            .buildJson(),
      ];

      when(mockRepository.getGradeSections(
        tenantId: anyNamed('tenantId'),
        gradeId: anyNamed('gradeId'),
        activeOnly: anyNamed('activeOnly'),
      )).thenAnswer((_) async => Right(
        mockSections.map((json) => GradeSection.fromJson(json)).toList(),
      ));

      // Act
      final result = await usecase(
        tenantId: TestData.testTenantId,
        gradeId: TestData.testGradeId,
      );

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should have returned sections'),
        (sections) {
          expect(sections.length, equals(2));
          expect(sections[0].sectionName, equals('A'));
          expect(sections[1].sectionName, equals('B'));
        },
      );

      verify(mockRepository.getGradeSections(
        tenantId: TestData.testTenantId,
        gradeId: TestData.testGradeId,
        activeOnly: true,
      )).called(1);
    });

    test('should return empty list when no sections exist', () async {
      // Arrange
      when(mockRepository.getGradeSections(
        tenantId: anyNamed('tenantId'),
        gradeId: anyNamed('gradeId'),
        activeOnly: anyNamed('activeOnly'),
      )).thenAnswer((_) async => const Right([]));

      // Act
      final result = await usecase(
        tenantId: TestData.testTenantId,
        gradeId: TestData.testGradeId,
      );

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should have returned empty list'),
        (sections) => expect(sections.isEmpty, true),
      );
    });

    test('should return failure when repository fails', () async {
      // Arrange
      final failure = ServerFailure('Database error');

      when(mockRepository.getGradeSections(
        tenantId: anyNamed('tenantId'),
        gradeId: anyNamed('gradeId'),
        activeOnly: anyNamed('activeOnly'),
      )).thenAnswer((_) async => Left(failure));

      // Act
      final result = await usecase(
        tenantId: TestData.testTenantId,
        gradeId: TestData.testGradeId,
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (sections) => fail('Should have returned failure'),
      );
    });

    test('should filter by gradeId when provided', () async {
      // Arrange
      when(mockRepository.getGradeSections(
        tenantId: anyNamed('tenantId'),
        gradeId: anyNamed('gradeId'),
        activeOnly: anyNamed('activeOnly'),
      )).thenAnswer((_) async => const Right([]));

      // Act
      await usecase(
        tenantId: TestData.testTenantId,
        gradeId: 'Grade 6',
      );

      // Assert
      verify(mockRepository.getGradeSections(
        tenantId: TestData.testTenantId,
        gradeId: 'Grade 6',
        activeOnly: true,
      )).called(1);
    });

    test('should not filter by gradeId when not provided', () async {
      // Arrange
      when(mockRepository.getGradeSections(
        tenantId: anyNamed('tenantId'),
        gradeId: anyNamed('gradeId'),
        activeOnly: anyNamed('activeOnly'),
      )).thenAnswer((_) async => const Right([]));

      // Act
      await usecase(
        tenantId: TestData.testTenantId,
      );

      // Assert
      verify(mockRepository.getGradeSections(
        tenantId: TestData.testTenantId,
        gradeId: null,
        activeOnly: true,
      )).called(1);
    });

    test('should always filter for active sections only', () async {
      // Arrange
      when(mockRepository.getGradeSections(
        tenantId: anyNamed('tenantId'),
        gradeId: anyNamed('gradeId'),
        activeOnly: anyNamed('activeOnly'),
      )).thenAnswer((_) async => const Right([]));

      // Act
      await usecase(
        tenantId: TestData.testTenantId,
        gradeId: TestData.testGradeId,
      );

      // Assert
      verify(mockRepository.getGradeSections(
        tenantId: TestData.testTenantId,
        gradeId: TestData.testGradeId,
        activeOnly: true,
      )).called(1);
    });
  });
}
