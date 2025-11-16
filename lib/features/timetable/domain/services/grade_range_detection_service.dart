import '../entities/mark_config_entity.dart';

/// Service to automatically detect and suggest grade range configurations
/// for marks based on school grade structure
class GradeRangeDetectionService {
  /// Standard grade ranges for different school systems
  static const Map<String, Map<String, dynamic>> _standardRanges = {
    'primary': {
      'name': 'Primary',
      'minGrade': 1,
      'maxGrade': 5,
      'defaultMarks': 25,
    },
    'secondary': {
      'name': 'Secondary',
      'minGrade': 6,
      'maxGrade': 8,
      'defaultMarks': 50,
    },
    'senior': {
      'name': 'Senior',
      'minGrade': 9,
      'maxGrade': 12,
      'defaultMarks': 80,
    },
  };

  /// Detect default mark ranges based on available grades
  ///
  /// Algorithm:
  /// 1. Analyzes all grades present in the school
  /// 2. Auto-detects natural groupings (Primary 1-5, Secondary 6-8, Senior 9-12)
  /// 3. Assigns sensible default marks to each group
  /// 4. Returns a list ready for display/editing in UI
  ///
  /// Example:
  /// ```dart
  /// final allGrades = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
  /// final configs = GradeRangeDetectionService.detectDefaultRanges(allGrades);
  /// // Returns:
  /// // [
  /// //   MarkConfigEntity(minGrade: 1, maxGrade: 5, totalMarks: 25, label: 'Primary'),
  /// //   MarkConfigEntity(minGrade: 6, maxGrade: 8, totalMarks: 50, label: 'Secondary'),
  /// //   MarkConfigEntity(minGrade: 9, maxGrade: 12, totalMarks: 80, label: 'Senior'),
  /// // ]
  /// ```
  static List<MarkConfigEntity> detectDefaultRanges(List<int> allGrades) {
    if (allGrades.isEmpty) {
      return [];
    }

    // Sort grades
    final sortedGrades = allGrades.toList()..sort();
    final minGrade = sortedGrades.first;
    final maxGrade = sortedGrades.last;

    final configs = <MarkConfigEntity>[];

    // Primary (1-5)
    if (minGrade <= 5 && maxGrade >= 1) {
      final configMinGrade = minGrade;
      final configMaxGrade = (maxGrade >= 5 ? 5 : maxGrade);
      if (configMinGrade <= configMaxGrade) {
        configs.add(
          MarkConfigEntity(
            minGrade: configMinGrade,
            maxGrade: configMaxGrade,
            totalMarks: 25,
            label: 'Primary',
          ),
        );
      }
    }

    // Secondary (6-8)
    if (minGrade <= 8 && maxGrade >= 6) {
      final configMinGrade = (minGrade > 6 ? minGrade : 6);
      final configMaxGrade = (maxGrade >= 8 ? 8 : maxGrade);
      if (configMinGrade <= configMaxGrade) {
        configs.add(
          MarkConfigEntity(
            minGrade: configMinGrade,
            maxGrade: configMaxGrade,
            totalMarks: 50,
            label: 'Secondary',
          ),
        );
      }
    }

    // Senior (9+)
    if (maxGrade >= 9) {
      final configMinGrade = (minGrade > 9 ? minGrade : 9);
      final configMaxGrade = maxGrade;
      if (configMinGrade <= configMaxGrade) {
        configs.add(
          MarkConfigEntity(
            minGrade: configMinGrade,
            maxGrade: configMaxGrade,
            totalMarks: 80,
            label: 'Senior',
          ),
        );
      }
    }

    return configs;
  }

  /// Find marks for a specific grade
  ///
  /// Returns the MarkConfigEntity that contains the given grade,
  /// or null if no configuration exists for that grade
  static MarkConfigEntity? getConfigForGrade(
    int grade,
    List<MarkConfigEntity> configs,
  ) {
    try {
      return configs.firstWhere((config) => config.containsGrade(grade));
    } catch (e) {
      return null;
    }
  }

  /// Get all configured grades from a list of mark configs
  static List<int> getConfiguredGrades(List<MarkConfigEntity> configs) {
    final grades = <int>[];
    for (final config in configs) {
      for (int grade = config.minGrade; grade <= config.maxGrade; grade++) {
        if (!grades.contains(grade)) {
          grades.add(grade);
        }
      }
    }
    return grades..sort();
  }

  /// Check if there are gaps in grade coverage
  ///
  /// Returns a list of grades that are not covered by any configuration
  static List<int> findGradeCoverageGaps(
    List<int> allGrades,
    List<MarkConfigEntity> configs,
  ) {
    final configuredGrades = getConfiguredGrades(configs);
    return allGrades
        .where((grade) => !configuredGrades.contains(grade))
        .toList();
  }

  /// Validate that all provided grades have marks configured
  ///
  /// Returns true if all grades in [allGrades] have a corresponding
  /// mark configuration in [configs]
  static bool isFullyCovered(
    List<int> allGrades,
    List<MarkConfigEntity> configs,
  ) {
    return findGradeCoverageGaps(allGrades, configs).isEmpty;
  }

  /// Merge overlapping or adjacent grade ranges
  ///
  /// Useful for cleaning up manual configurations that may have overlaps
  static List<MarkConfigEntity> mergeRanges(List<MarkConfigEntity> configs) {
    if (configs.isEmpty) return [];

    // Sort by minGrade
    final sorted = configs.toList()
      ..sort((a, b) => a.minGrade.compareTo(b.minGrade));

    final merged = <MarkConfigEntity>[];
    var current = sorted.first;

    for (int i = 1; i < sorted.length; i++) {
      final next = sorted[i];

      // Check if ranges overlap or are adjacent
      if (next.minGrade <= current.maxGrade + 1) {
        // Merge: keep lower minGrade and higher maxGrade, use first marks config
        current = current.copyWith(
          maxGrade: (next.maxGrade > current.maxGrade ? next.maxGrade : current.maxGrade),
        );
      } else {
        // No overlap, add current and start new
        merged.add(current);
        current = next;
      }
    }

    // Add the last range
    merged.add(current);
    return merged;
  }
}
