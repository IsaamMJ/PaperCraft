// features/question_papers/domain/helpers/section_ordering_helper.dart
import '../../../catalog/domain/entities/paper_section_entity.dart';

class SectionOrderingHelper {
  static List<OrderedSection> getOrderedSections(
      List<PaperSectionEntity> paperSections,
      Map<String, List<dynamic>> questionsMap,
      ) {
    final orderedSections = <OrderedSection>[];

    print('=== getOrderedSections DEBUG ===');
    for (int i = 0; i < paperSections.length; i++) {
      final section = paperSections[i];
      final questions = questionsMap[section.name] ?? [];
      final marks = _calculateSectionMarks(section, questions);

      print('Processing Section: ${section.name}');
      print('  - Type: ${section.type}');
      print('  - MarksPerQuestion: ${section.marksPerQuestion}');
      print('  - Expected questions: ${section.questions}');
      print('  - Actual questions list length: ${questions.length}');
      print('  - Calculated marks: $marks');

      orderedSections.add(OrderedSection(
        sectionNumber: i + 1,
        section: section,
        questions: questions,
        questionCount: questions.length,
        totalMarks: marks,
      ));
    }

    // Handle extra sections not in paperSections
    final definedSectionNames = paperSections.map((s) => s.name).toSet();
    final extraSections = questionsMap.keys.where((name) => !definedSectionNames.contains(name)).toList();

    for (int i = 0; i < extraSections.length; i++) {
      final sectionName = extraSections[i];
      final questions = questionsMap[sectionName] ?? [];

      final syntheticSection = PaperSectionEntity(
        name: sectionName,
        type: 'mixed',
        questions: questions.length,
        marksPerQuestion: 1,
      );

      orderedSections.add(OrderedSection(
        sectionNumber: paperSections.length + i + 1,
        section: syntheticSection,
        questions: questions,
        questionCount: questions.length,
        totalMarks: questions.length.toDouble(),
        isExtra: true,
      ));
    }

    return orderedSections;
  }

  static double _calculateSectionMarks(PaperSectionEntity section, List<dynamic> questions) {
    if (questions.isEmpty) return 0;

    // For match_following sections, calculate marks as: marksPerQuestion × numberOfPairs
    // This is because there's only 1 question object but it represents multiple pairs
    if (section.type == 'match_following') {
      // For match_following: use section.questions (number of pairs) not questions.length
      // Count only non-optional questions for match_following
      final nonOptionalCount = questions.where((q) {
        if (q is Map) {
          return !(q['is_optional'] ?? false);
        } else {
          try {
            return !((q as dynamic).isOptional ?? false);
          } catch (e) {
            return true;
          }
        }
      }).length;

      // If there are non-optional questions, use section.questions (pairs count) for calculation
      if (nonOptionalCount > 0) {
        final result = section.marksPerQuestion * section.questions;
        print('  [_calculateSectionMarks] match_following: ${section.marksPerQuestion} × ${section.questions} (pairs) = $result');
        return result;
      }
      return 0;
    }

    double totalMarks = 0;
    for (int idx = 0; idx < questions.length; idx++) {
      final question = questions[idx];

      // Check if question is optional - skip if it is
      bool isOptional = false;
      if (question is Map) {
        isOptional = question['is_optional'] ?? false;
      } else {
        try {
          isOptional = (question as dynamic).isOptional ?? false;
        } catch (e) {
          isOptional = false;
        }
      }

      // Skip optional questions
      if (isOptional) {
        print('  [_calculateSectionMarks] Question ${idx + 1}: SKIPPED (optional)');
        continue;
      }

      double questionMarks = 0;
      if (question is Map && question.containsKey('marks')) {
        final marks = question['marks'];
        questionMarks = (marks is int ? marks.toDouble() : marks as double? ?? section.marksPerQuestion);
      } else {
        try {
          final marks = (question as dynamic).marks as num?;
          questionMarks = marks?.toDouble() ?? section.marksPerQuestion;
        } catch (e) {
          questionMarks = section.marksPerQuestion;
        }
      }
      totalMarks += questionMarks;
      print('  [_calculateSectionMarks] Question ${idx + 1}: $questionMarks (type: ${question is Map ? 'Map' : 'Object'})');
    }

    print('  [_calculateSectionMarks] Total for non-optional questions: $totalMarks');
    return totalMarks;
  }


  static String getSectionDisplayName(OrderedSection orderedSection) {
    return 'Section ${orderedSection.sectionNumber}: ${orderedSection.section.name}';
  }

  static String getCompactSectionDisplay(OrderedSection orderedSection) {
    return 'Sec ${orderedSection.sectionNumber}';
  }

  static String getSectionSummary(OrderedSection orderedSection) {
    final section = orderedSection.section;
    final actualQuestions = orderedSection.questionCount;
    final expectedQuestions = section.questions;
    final marks = orderedSection.totalMarks;

    // Format marks to show whole numbers without decimal point
    final marksDisplay = marks % 1 == 0 ? marks.toInt() : marks;

    String summary = '$actualQuestions questions • $marksDisplay marks';

    // Don't show "Expected" for matching questions since they have 1 question with multiple pairs
    // For matching: actualQuestions=1, expectedQuestions=pairs, so the comparison is misleading
    if (actualQuestions != expectedQuestions && section.type != 'match_following') {
      summary += ' (Expected: $expectedQuestions)';
    }

    return summary;
  }

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

    if (actualQuestions > requiredQuestions) {
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
      totalMarks += orderedSection.totalMarks.toInt();

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

  static List<OrderedSection> sortSectionsByCustomOrder(
      List<OrderedSection> sections,
      List<String> customOrder,
      ) {
    if (customOrder.isEmpty) return sections;

    final orderedSections = <OrderedSection>[];
    final sectionMap = {for (var s in sections) s.section.name: s};

    for (int i = 0; i < customOrder.length; i++) {
      final sectionName = customOrder[i];
      final section = sectionMap[sectionName];
      if (section != null) {
        orderedSections.add(section.copyWith(sectionNumber: i + 1));
        sectionMap.remove(sectionName);
      }
    }

    final remainingSections = sectionMap.values.toList();
    for (int i = 0; i < remainingSections.length; i++) {
      orderedSections.add(remainingSections[i].copyWith(
        sectionNumber: orderedSections.length + i + 1,
      ));
    }

    return orderedSections;
  }
}

class OrderedSection {
  final int sectionNumber;
  final PaperSectionEntity section;
  final List<dynamic> questions;
  final int questionCount;
  final double totalMarks;
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
    PaperSectionEntity? section,
    List<dynamic>? questions,
    int? questionCount,
    double? totalMarks,
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

enum SectionStatus {
  empty,
  incomplete,
  complete,
  excess,
}

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

  double get completionPercentage {
    if (totalSections == 0) return 0.0;
    return (completeSections / totalSections * 100).clamp(0.0, 100.0);
  }

  String get summaryText {
    if (isComplete) {
      return 'Complete: $totalQuestions questions, $totalMarks marks';
    } else {
      return 'Incomplete: $incompleteSections section${incompleteSections == 1 ? '' : 's'} need${incompleteSections == 1 ? 's' : ''} questions';
    }
  }
}