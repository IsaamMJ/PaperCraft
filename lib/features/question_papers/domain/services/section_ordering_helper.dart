// features/question_papers/domain/helpers/section_ordering_helper.dart
import '../entities/exam_type_entity.dart';

/// Helper class for handling section ordering and numbering in question papers
class SectionOrderingHelper {

  /// Get ordered sections with numbering information
  static List<OrderedSection> getOrderedSections(
      ExamTypeEntity examTypeEntity,
      Map<String, List<dynamic>> questionsMap,
      ) {
    final orderedSections = <OrderedSection>[];

    // Use the order from examTypeEntity.sections
    for (int i = 0; i < examTypeEntity.sections.length; i++) {
      final section = examTypeEntity.sections[i];
      final questions = questionsMap[section.name] ?? [];

      orderedSections.add(OrderedSection(
        sectionNumber: i + 1,
        section: section,
        questions: questions,
        questionCount: questions.length,
        totalMarks: _calculateSectionMarks(section, questions),
      ));
    }

    // Handle any sections in questionsMap that aren't in examTypeEntity
    // (this shouldn't happen in normal cases, but provides robustness)
    final definedSectionNames = examTypeEntity.sections.map((s) => s.name).toSet();
    final extraSections = questionsMap.keys.where((name) => !definedSectionNames.contains(name)).toList();

    for (int i = 0; i < extraSections.length; i++) {
      final sectionName = extraSections[i];
      final questions = questionsMap[sectionName] ?? [];

      // Create a synthetic section for undefined sections
      final syntheticSection = ExamSectionEntity(
        name: sectionName,
        type: 'mixed',
        questions: questions.length,
        marksPerQuestion: 1, // Default
      );

      orderedSections.add(OrderedSection(
        sectionNumber: examTypeEntity.sections.length + i + 1,
        section: syntheticSection,
        questions: questions,
        questionCount: questions.length,
        totalMarks: questions.length, // Default 1 mark per question
        isExtra: true,
      ));
    }

    return orderedSections;
  }

  /// Calculate marks for a section based on actual questions
  static int _calculateSectionMarks(ExamSectionEntity section, List<dynamic> questions) {
    if (questions.isEmpty) return 0;

    // If questions have individual marks, sum them up
    int totalMarks = 0;
    for (final question in questions) {
      if (question is Map && question.containsKey('marks')) {
        totalMarks += (question['marks'] as int? ?? section.marksPerQuestion);
      } else if (question.runtimeType.toString().contains('Question')) {
        // Handle Question entity type
        try {
          final marks = (question as dynamic).marks as int?;
          totalMarks += marks ?? section.marksPerQuestion;
        } catch (e) {
          totalMarks += section.marksPerQuestion;
        }
      } else {
        totalMarks += section.marksPerQuestion;
      }
    }

    return totalMarks;
  }

  /// Get section display name with number
  static String getSectionDisplayName(OrderedSection orderedSection) {
    return 'Section ${orderedSection.sectionNumber}: ${orderedSection.section.name}';
  }

  /// Get compact section display (for limited space)
  static String getCompactSectionDisplay(OrderedSection orderedSection) {
    return 'Sec ${orderedSection.sectionNumber}';
  }

  /// Get section summary text
  static String getSectionSummary(OrderedSection orderedSection) {
    final section = orderedSection.section;
    final actualQuestions = orderedSection.questionCount;
    final expectedQuestions = section.questions;
    final marks = orderedSection.totalMarks;

    String summary = '$actualQuestions questions • $marks marks';

    // Add requirement info if different from actual
    if (actualQuestions != expectedQuestions) {
      summary += ' (Expected: $expectedQuestions)';
    }

    // Add optional question info
    if (section.hasOptionalQuestions) {
      summary += ' • ${section.questionRequirement}';
    }

    return summary;
  }

  /// Validate section completeness
  static SectionValidation validateSection(OrderedSection orderedSection) {
    final section = orderedSection.section;
    final actualQuestions = orderedSection.questionCount;
    final requiredQuestions = section.questions;

    if (actualQuestions == 0) {
      return SectionValidation(
        isValid: false,
        status: SectionStatus.empty,
        message: 'No questions added',
      );
    }

    if (actualQuestions < requiredQuestions) {
      final needed = requiredQuestions - actualQuestions;
      return SectionValidation(
        isValid: false,
        status: SectionStatus.incomplete,
        message: 'Need $needed more question${needed == 1 ? '' : 's'}',
      );
    }

    if (actualQuestions > requiredQuestions && !section.hasOptionalQuestions) {
      final excess = actualQuestions - requiredQuestions;
      return SectionValidation(
        isValid: true,
        status: SectionStatus.excess,
        message: '$excess extra question${excess == 1 ? '' : 's'}',
      );
    }

    return SectionValidation(
      isValid: true,
      status: SectionStatus.complete,
      message: 'Complete',
    );
  }

  /// Get overall paper completion status
  static PaperCompletion getPaperCompletion(List<OrderedSection> orderedSections) {
    int completeSections = 0;
    int incompleteSections = 0;
    int emptySections = 0;
    int totalQuestions = 0;
    int totalMarks = 0;

    final issues = <String>[];

    for (final orderedSection in orderedSections) {
      final validation = validateSection(orderedSection);
      totalQuestions += orderedSection.questionCount;
      totalMarks += orderedSection.totalMarks;

      switch (validation.status) {
        case SectionStatus.complete:
        case SectionStatus.excess:
          completeSections++;
          break;
        case SectionStatus.incomplete:
          incompleteSections++;
          issues.add('${getSectionDisplayName(orderedSection)}: ${validation.message}');
          break;
        case SectionStatus.empty:
          emptySections++;
          issues.add('${getSectionDisplayName(orderedSection)}: No questions');
          break;
      }
    }

    final isComplete = incompleteSections == 0 && emptySections == 0 && totalQuestions > 0;

    return PaperCompletion(
      isComplete: isComplete,
      totalSections: orderedSections.length,
      completeSections: completeSections,
      incompleteSections: incompleteSections,
      emptySections: emptySections,
      totalQuestions: totalQuestions,
      totalMarks: totalMarks,
      issues: issues,
    );
  }

  /// Sort sections by custom order if needed
  static List<OrderedSection> sortSectionsByCustomOrder(
      List<OrderedSection> sections,
      List<String> customOrder,
      ) {
    if (customOrder.isEmpty) return sections;

    final orderedSections = <OrderedSection>[];
    final sectionMap = {for (var s in sections) s.section.name: s};

    // Add sections in custom order
    for (int i = 0; i < customOrder.length; i++) {
      final sectionName = customOrder[i];
      final section = sectionMap[sectionName];
      if (section != null) {
        orderedSections.add(section.copyWith(sectionNumber: i + 1));
        sectionMap.remove(sectionName);
      }
    }

    // Add any remaining sections
    final remainingSections = sectionMap.values.toList();
    for (int i = 0; i < remainingSections.length; i++) {
      orderedSections.add(remainingSections[i].copyWith(
        sectionNumber: orderedSections.length + i + 1,
      ));
    }

    return orderedSections;
  }
}

/// Represents a section with ordering information
class OrderedSection {
  final int sectionNumber;
  final ExamSectionEntity section;
  final List<dynamic> questions;
  final int questionCount;
  final int totalMarks;
  final bool isExtra;

  const OrderedSection({
    required this.sectionNumber,
    required this.section,
    required this.questions,
    required this.questionCount,
    required this.totalMarks,
    this.isExtra = false,
  });

  OrderedSection copyWith({
    int? sectionNumber,
    ExamSectionEntity? section,
    List<dynamic>? questions,
    int? questionCount,
    int? totalMarks,
    bool? isExtra,
  }) {
    return OrderedSection(
      sectionNumber: sectionNumber ?? this.sectionNumber,
      section: section ?? this.section,
      questions: questions ?? this.questions,
      questionCount: questionCount ?? this.questionCount,
      totalMarks: totalMarks ?? this.totalMarks,
      isExtra: isExtra ?? this.isExtra,
    );
  }
}

/// Section validation result
class SectionValidation {
  final bool isValid;
  final SectionStatus status;
  final String message;

  const SectionValidation({
    required this.isValid,
    required this.status,
    required this.message,
  });
}

/// Section status enum
enum SectionStatus {
  empty,
  incomplete,
  complete,
  excess,
}

/// Overall paper completion information
class PaperCompletion {
  final bool isComplete;
  final int totalSections;
  final int completeSections;
  final int incompleteSections;
  final int emptySections;
  final int totalQuestions;
  final int totalMarks;
  final List<String> issues;

  const PaperCompletion({
    required this.isComplete,
    required this.totalSections,
    required this.completeSections,
    required this.incompleteSections,
    required this.emptySections,
    required this.totalQuestions,
    required this.totalMarks,
    required this.issues,
  });

  /// Get completion percentage
  double get completionPercentage {
    if (totalSections == 0) return 0.0;
    return (completeSections / totalSections * 100).clamp(0.0, 100.0);
  }

  /// Get summary text
  String get summaryText {
    if (isComplete) {
      return 'Complete: $totalQuestions questions, $totalMarks marks';
    } else {
      return 'Incomplete: $incompleteSections section${incompleteSections == 1 ? '' : 's'} need${incompleteSections == 1 ? 's' : ''} questions';
    }
  }
}