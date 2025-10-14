// features/pdf_generation/domain/config/pdf_layout_config.dart

/// Professional PDF layout configuration based on typography standards
///
/// Uses 6-point baseline grid system (common in print design)
/// All spacing values are multiples of the baseline for consistent rhythm
///
/// Reference: https://material.io/design/typography/understanding-typography.html
class PdfLayoutConfig {
  /// Baseline grid unit (6pt is standard for print)
  final double baselineUnit;

  /// Spacing after page header before content starts
  final double headerSpacing;

  /// Spacing after section header (e.g., "I. Answer The Following")
  final double sectionHeaderSpacing;

  /// Spacing between individual questions within a section
  final double questionSpacing;

  /// Spacing between sections (larger than question spacing)
  final double sectionSpacing;

  /// Body text font size (questions, options)
  final double bodyFontSize;

  /// Header/title font size
  final double headerFontSize;

  /// Section label font size (I, II, III)
  final double sectionFontSize;

  /// Line height multiplier for body text
  final double lineHeight;

  /// Page margins (all sides)
  final double pageMargin;

  const PdfLayoutConfig({
    required this.baselineUnit,
    required this.headerSpacing,
    required this.sectionHeaderSpacing,
    required this.questionSpacing,
    required this.sectionSpacing,
    required this.bodyFontSize,
    required this.headerFontSize,
    required this.sectionFontSize,
    required this.lineHeight,
    required this.pageMargin,
  });

  /// Compact layout: Maximum questions per page, minimal spacing
  /// Use case: Long exams (50+ questions), multiple-choice heavy
  const PdfLayoutConfig.compact()
      : baselineUnit = 6.0,
        headerSpacing = 6.0,       // 1 baseline unit
        sectionHeaderSpacing = 3.0, // 0.5 baseline unit
        questionSpacing = 3.0,      // 0.5 baseline unit
        sectionSpacing = 6.0,       // 1 baseline unit
        bodyFontSize = 10.0,
        headerFontSize = 14.0,
        sectionFontSize = 11.0,
        lineHeight = 1.4,
        pageMargin = 12.0;           // 2 baseline units

  /// Standard layout: Balanced spacing, professional appearance
  /// Use case: Normal exams (15-30 questions), recommended default
  const PdfLayoutConfig.standard()
      : baselineUnit = 6.0,
        headerSpacing = 12.0,       // 2 baseline units
        sectionHeaderSpacing = 4.0, // ~0.7 baseline units
        questionSpacing = 6.0,      // 1 baseline unit
        sectionSpacing = 12.0,      // 2 baseline units
        bodyFontSize = 11.0,
        headerFontSize = 16.0,
        sectionFontSize = 11.0,
        lineHeight = 1.5,
        pageMargin = 15.0;           // 2.5 baseline units

  /// Spacious layout: Extra breathing room, high readability
  /// Use case: Short exams (8-15 questions), descriptive questions
  const PdfLayoutConfig.spacious()
      : baselineUnit = 6.0,
        headerSpacing = 18.0,       // 3 baseline units
        sectionHeaderSpacing = 6.0, // 1 baseline unit
        questionSpacing = 12.0,     // 2 baseline units
        sectionSpacing = 18.0,      // 3 baseline units
        bodyFontSize = 12.0,
        headerFontSize = 16.0,
        sectionFontSize = 12.0,
        lineHeight = 1.6,
        pageMargin = 18.0;           // 3 baseline units

  /// Get config by name for backward compatibility
  static PdfLayoutConfig fromName(String name) {
    switch (name.toLowerCase()) {
      case 'compact':
        return const PdfLayoutConfig.compact();
      case 'standard':
        return const PdfLayoutConfig.standard();
      case 'spacious':
        return const PdfLayoutConfig.spacious();
      default:
        return const PdfLayoutConfig.standard();
    }
  }

  @override
  String toString() => '''
PdfLayoutConfig(
  headerSpacing: $headerSpacing pt,
  questionSpacing: $questionSpacing pt,
  sectionSpacing: $sectionSpacing pt,
  bodyFontSize: $bodyFontSize pt,
  lineHeight: $lineHeight
)''';
}
