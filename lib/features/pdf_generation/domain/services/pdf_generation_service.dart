// features/question_papers/domain2/services/pdf_generation_service.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../../core/infrastructure/config/app_config.dart';
import '../../../../core/infrastructure/rate_limiter/rate_limiter.dart';
import '../../../paper_workflow/domain/entities/question_entity.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';

class DualPageData {
  final pw.Widget leftContent;
  final pw.Widget rightContent;
  final int pageNumber;

  DualPageData({
    required this.leftContent,
    required this.rightContent,
    required this.pageNumber,
  });
}

enum DualLayoutMode {
  balanced,    // Balance content between left/right (current)
  compressed,  // Pack content tightly from top, fill both sides completely
  identical,   // Both sides identical (only for small papers)
}

abstract class IPdfGenerationService {
  Future<Uint8List> generateStudentPdf({
    required QuestionPaperEntity paper,
    required String schoolName,
    String? studentName,
    String? rollNumber,
    bool compressed = false,
    double fontSizeMultiplier = 1.0,
    double spacingMultiplier = 1.0,
  });

  Future<Uint8List> generateDualLayoutPdf({
    required QuestionPaperEntity paper,
    required String schoolName,
    DualLayoutMode mode = DualLayoutMode.balanced,
  });

}

class SimplePdfService implements IPdfGenerationService {
  static const int MAX_QUESTIONS_PER_BATCH = 20;
  static const int MAX_QUESTIONS_PER_PAGE = 10;

  // Layout constants for dual mode
  static const double DUAL_PAGE_HEIGHT = 550; // A4 landscape height in points minus margins
  static const double HEADER_HEIGHT = 80;
  static const double AVAILABLE_CONTENT_HEIGHT = DUAL_PAGE_HEIGHT - HEADER_HEIGHT;

  // Mobile-compatible fonts - using built-in fonts only
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

  @override
  Future<Uint8List> generateDualLayoutPdf({
    required QuestionPaperEntity paper,
    required String schoolName,
    DualLayoutMode mode = DualLayoutMode.balanced,
  }) async {
    // Rate limiting check
    if (!RateLimiters.pdfGeneration.canProceed('pdf_gen_${paper.id}')) {
      final waitTime = RateLimiters.pdfGeneration.getWaitTime('pdf_gen_${paper.id}');
      throw ValidationFailure(
        'Too many PDF requests. Please wait ${waitTime.inSeconds} seconds before trying again.'
      );
    }

    // Wrap generation with timeout
    return await _generateDualLayoutPdfInternal(
      paper: paper,
      schoolName: schoolName,
      mode: mode,
    ).timeout(
      AppConfig.pdfGenerationTimeout,
      onTimeout: () {
        throw ValidationFailure(
          'PDF generation timed out. The paper may be too large. '
          'Try reducing the number of questions or contact support.'
        );
      },
    );
  }

  Future<Uint8List> _generateDualLayoutPdfInternal({
    required QuestionPaperEntity paper,
    required String schoolName,
    DualLayoutMode mode = DualLayoutMode.balanced,
  }) async {
    await _loadFonts();
    final pdf = pw.Document();

    try {
      final allSections = _getSortedSections(paper.questions);

      // Calculate total content height
      double totalHeight = 0;
      for (final section in allSections) {
        totalHeight += _calculateSectionHeight(section.key, section.value);
      }

      // If content fits on one side, duplicate it (identical layout)
      if (totalHeight <= AVAILABLE_CONTENT_HEIGHT * 0.85 || mode == DualLayoutMode.identical) {
        // Single page - both sides identical with full content
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(15),
            build: (context) {
              return pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: _buildSinglePaperLayout(schoolName, paper)),
                  pw.SizedBox(width: 10),
                  pw.Expanded(child: _buildSinglePaperLayout(schoolName, paper)),
                ],
              );
            },
          ),
        );
      } else if (mode == DualLayoutMode.compressed) {
        // Compressed mode - fill both sides from top to bottom
        final compressedPages = _compressContentForDualLayout(allSections, schoolName, paper);

        for (final pageData in compressedPages) {
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4.landscape,
              margin: const pw.EdgeInsets.all(15),
              build: (context) {
                return pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(child: pageData.leftContent),
                    pw.SizedBox(width: 10),
                    pw.Expanded(child: pageData.rightContent),
                  ],
                );
              },
            ),
          );
        }
      } else {
        // Balanced mode - use space-based splitting
        final balancedPages = _balanceContentForDualLayout(allSections, schoolName, paper);

        for (final pageData in balancedPages) {
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4.landscape,
              margin: const pw.EdgeInsets.all(15),
              build: (context) {
                return pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(child: pageData.leftContent),
                    pw.SizedBox(width: 10),
                    pw.Expanded(child: pageData.rightContent),
                  ],
                );
              },
            ),
          );
        }
      }
    } catch (e) {
      pdf.addPage(
        pw.Page(
          build: (context) => pw.Center(
            child: pw.Text('Error generating PDF. Please contact support.'),
          ),
        ),
      );
    }

    return pdf.save();
  }

  pw.Widget _buildSinglePaperLayout(
      String schoolName,
      QuestionPaperEntity paper, {
        Map<String, List<Question>>? sectionsToShow,
        int startingSectionIndex = 1,
      }) {
    final sections = sectionsToShow ?? paper.questions;

    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildCompactHeader(schoolName: schoolName, paper: paper),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: _buildCompactQuestionsForSections(sections, startingSectionIndex),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildContinuationLayout(
      QuestionPaperEntity paper,
      Map<String, List<Question>> sections, {
        int startingSectionIndex = 1,
      }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: _buildCompactQuestionsForSections(sections, startingSectionIndex),
      ),
    );
  }

  List<pw.Widget> _buildCompactQuestionsForSections(
      Map<String, List<Question>> sections,
      int startingSectionIndex,
      ) {
    final widgets = <pw.Widget>[];
    final sortedSections = sections.entries.toList();
    int sectionIndex = startingSectionIndex;

    for (final sectionEntry in sortedSections) {
      final sectionName = sectionEntry.key;
      final questions = sectionEntry.value;

      if (questions.isEmpty) continue;

      try {
        final sectionMarks = questions.fold(0.0, (sum, q) => sum + q.totalMarks);
        final questionCount = questions.length;

        // Build section name with answer bank for fill_blanks
        String sectionHeaderText = '${_getRomanNumeral(sectionIndex)}. $sectionName';
        if (questions.first.type == 'fill_blanks' && questions.first.options != null && questions.first.options!.isNotEmpty) {
          final answerBank = questions.first.options!.join(', ');
          sectionHeaderText = '$sectionHeaderText [$answerBank]';
        }

        widgets.add(
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  sectionHeaderText,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    font: _boldFont,
                  ),
                ),
                pw.Text(
                  '$questionCount × ${(sectionMarks / questionCount).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')} = ${sectionMarks.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')} marks',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    font: _boldFont,
                  ),
                ),
              ],
            ),
          ),
        );

        widgets.add(pw.SizedBox(height: 1));

        final commonInstruction = _getCommonInstruction(questions.first.type);
        if (commonInstruction.isNotEmpty) {
          widgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(2),
              margin: const pw.EdgeInsets.only(bottom: 2),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(2),
              ),
              child: pw.Text(
                commonInstruction,
                style: pw.TextStyle(fontSize: 8, font: _regularFont),
              ),
            ),
          );
        }

        // Check if this is a fill_in_blanks section with word banks (shared mode)
        final isFillBlanksSection = questions.isNotEmpty && questions.first.type == 'fill_in_blanks';
        if (isFillBlanksSection) {
          final wordBankMode = _detectFillBlanksWordBankMode(questions);

          // Display shared word bank if all questions share the same word bank
          if (wordBankMode == 'shared') {
            final sharedWordBank = questions.first.options;
            if (sharedWordBank != null && sharedWordBank.isNotEmpty) {
              widgets.add(_buildWordBankDisplay(sharedWordBank));
              widgets.add(pw.SizedBox(height: 2));
            }
          }
        }

        // Display all questions normally with their options
        for (int i = 0; i < questions.length; i++) {
          final question = questions[i];
          final questionNumber = i + 1;

          try {
            widgets.add(_buildCompactSingleQuestion(
              question: question,
              questionNumber: questionNumber,
              showCommonText: commonInstruction.isEmpty,
            ));

            if (i < questions.length - 1) {
              widgets.add(pw.SizedBox(height: 2));
            }
          } catch (e) {
            widgets.add(
              pw.Text(
                '$questionNumber. [Question error]',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
            );
          }
        }

        widgets.add(pw.SizedBox(height: 3));
        sectionIndex++;
      } catch (e) {
        continue;
      }
    }

    return widgets;
  }

  /// Detect the word bank mode for fill_in_blanks questions
  /// Returns: 'none', 'individual', or 'shared'
  /// FIXED: Always prefer 'shared' mode for fill_in_blanks to show word bank once at top
  String _detectFillBlanksWordBankMode(List<Question> questions) {
    // Filter only fill_in_blanks questions with word banks
    final questionsWithBanks = questions.where((q) =>
        q.type == 'fill_in_blanks' &&
        q.options != null &&
        q.options!.isNotEmpty).toList();

    if (questionsWithBanks.isEmpty) {
      return 'none'; // No word banks at all
    }

    // For fill_in_blanks, ALWAYS use shared mode to display word bank at top once
    // Use the first question's word bank as the shared bank
    return 'shared';
  }

  /// Build word bank display widget as comma-separated text
  pw.Widget _buildWordBankDisplay(List<String> wordBank) {
    if (wordBank.isEmpty) return pw.SizedBox.shrink();

    // Format word bank with wrapping for space optimization
    // Group words into lines of ~80-100 characters each
    final wordBankText = '[${wordBank.join(', ')}]';

    // Create wrapped text with better layout
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Text(
        wordBankText,
        style: pw.TextStyle(
          fontSize: 9,
          font: _regularFont,
          color: PdfColors.grey700,
        ),
        maxLines: 3, // Allow wrapping across up to 3 lines to save vertical space
        textAlign: pw.TextAlign.left,
      ),
    );
  }


  @override
  Future<Uint8List> generateStudentPdf({
    required QuestionPaperEntity paper,
    required String schoolName,
    String? studentName,
    String? rollNumber,
    bool compressed = false,
    double fontSizeMultiplier = 1.0,
    double spacingMultiplier = 1.0,
  }) async {
    // Rate limiting check
    if (!RateLimiters.pdfGeneration.canProceed('pdf_gen_${paper.id}')) {
      final waitTime = RateLimiters.pdfGeneration.getWaitTime('pdf_gen_${paper.id}');
      throw ValidationFailure(
        'Too many PDF requests. Please wait ${waitTime.inSeconds} seconds before trying again.'
      );
    }

    // Wrap generation with timeout
    return await _generateStudentPdfInternal(
      paper: paper,
      schoolName: schoolName,
      studentName: studentName,
      rollNumber: rollNumber,
      compressed: compressed,
      fontSizeMultiplier: fontSizeMultiplier,
      spacingMultiplier: spacingMultiplier,
    ).timeout(
      AppConfig.pdfGenerationTimeout,
      onTimeout: () {
        throw ValidationFailure(
          'PDF generation timed out. The paper may be too large. '
          'Try reducing the number of questions or contact support.'
        );
      },
    );
  }

  Future<Uint8List> _generateStudentPdfInternal({
    required QuestionPaperEntity paper,
    required String schoolName,
    String? studentName,
    String? rollNumber,
    bool compressed = false,
    double fontSizeMultiplier = 1.0,
    double spacingMultiplier = 1.0,
  }) async {
    await _loadFonts();
    final pdf = pw.Document();

    try {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(15),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildCompactHeaderForSinglePage(
                  schoolName: schoolName,
                  paper: paper,
                  studentName: studentName,
                  rollNumber: rollNumber,
                  fontSizeMultiplier: fontSizeMultiplier,
                ),
                pw.SizedBox(height: 12 * spacingMultiplier), // Increased from 6
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: _buildCompactQuestionsForSinglePage(paper, fontSizeMultiplier, spacingMultiplier),
                  ),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      // Error recovery
      pdf.addPage(
        pw.Page(
          build: (context) =>
              pw.Center(
                child: pw.Text('Error generating PDF. Please contact support.'),
              ),
        ),
      );
    }

    return pdf.save();
  }


  Future<void> _loadFonts() async {
    try {
      // Professional serif fonts (recommended for academic papers)
      _regularFont = pw.Font.times();
      _boldFont = pw.Font.timesBold();

      // Alternative: Professional sans-serif fonts (uncomment to use instead)
      // _regularFont = pw.Font.helvetica();
      // _boldFont = pw.Font.helveticaBold();
    } catch (e) {
      // Fallback to courier if Times fails
      _regularFont = pw.Font.courier();
      _boldFont = pw.Font.courierBold();
    }
  }

  // Header components
  pw.Widget _buildCompactHeaderForSinglePage({
    required String schoolName,
    required QuestionPaperEntity paper,
    String? studentName,
    String? rollNumber,
    double fontSizeMultiplier = 1.0,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // School name
        pw.Center(
          child: pw.Text(
            schoolName,
            style: pw.TextStyle(
              fontSize: 16 * fontSizeMultiplier,
              fontWeight: pw.FontWeight.bold,
              font: _boldFont,
            ),
          ),
        ),
        pw.SizedBox(height: 2),

        // Paper title
        pw.Center(
          child: pw.Text(
            paper.pdfTitle,
            style: pw.TextStyle(
              fontSize: UIConstants.fontSizeMedium * fontSizeMultiplier,
              fontWeight: pw.FontWeight.bold,
              font: _boldFont,
            ),
          ),
        ),
        pw.SizedBox(height: 2),

        // Paper details in single row
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Subject: ${paper.subject}',
                style: pw.TextStyle(fontSize: 10 * fontSizeMultiplier, font: _regularFont)),
            if (paper.gradeNumber != null)
              pw.Text('Class: ${paper.gradeNumber}',
                  style: pw.TextStyle(fontSize: 10 * fontSizeMultiplier, font: _regularFont))
            else if (paper.gradeDisplayName != null)
              pw.Text('Class: ${paper.gradeDisplayName.replaceAll('Grade ', '')}',
                  style: pw.TextStyle(fontSize: 10 * fontSizeMultiplier, font: _regularFont)),
            if (paper.examDate != null)
              pw.Text('Date: ${_formatExamDate(paper.examDate!)}',
                  style: pw.TextStyle(fontSize: 10 * fontSizeMultiplier, font: _regularFont)),
            pw.Text('Total Marks: ${paper.totalMarks}',
                style: pw.TextStyle(fontSize: 10 * fontSizeMultiplier, font: _regularFont)),
          ],
        ),

        pw.SizedBox(height: 2),
        pw.Container(height: 1, color: PdfColors.grey),
      ],
    );
  }

  pw.Widget _buildCompactHeader({
    required String schoolName,
    required QuestionPaperEntity paper,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // School name
        pw.Center(
          child: pw.Text(
            schoolName,
            style: pw.TextStyle(
              fontSize: 13, // Increased from 12
              fontWeight: pw.FontWeight.bold,
              font: _boldFont,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.SizedBox(height: 2), // Reduced from 4

        // Paper title
        pw.Center(
          child: pw.Text(
            paper.title,
            style: pw.TextStyle(
              fontSize: 11, // Increased from 10
              fontWeight: pw.FontWeight.bold,
              font: _boldFont,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.SizedBox(height: 2), // Reduced from 4

        // Paper details
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('${paper.subject} | ${paper.gradeDisplayName}',
                style: pw.TextStyle(fontSize: 9, font: _regularFont)), // Increased from 8
            if (paper.examDate != null)
              pw.Text('Date: ${_formatExamDate(paper.examDate!)}',
                  style: pw.TextStyle(fontSize: 9, font: _regularFont)), // Increased from 8
            pw.Text('Marks: ${paper.totalMarks}',
                style: pw.TextStyle(fontSize: 9, font: _regularFont)), // Increased from 8
          ],
        ),
        pw.SizedBox(height: 2), // Reduced from 4
        pw.SizedBox(height: 2), // Reduced from 4
        pw.Container(height: 1, color: PdfColors.grey),
      ],
    );
  }

  pw.Widget _buildAnswerSheetHeader({
    required String schoolName,
    required QuestionPaperEntity paper,
    String? studentName,
    String? rollNumber,
  }) {
    return pw.Column(
      children: [
        pw.Center(
          child: pw.Text(
            schoolName,
            style: pw.TextStyle(
              fontSize: 18, // Increased from 16
              fontWeight: pw.FontWeight.bold,
              font: _boldFont,
            ),
          ),
        ),
        pw.SizedBox(height: 4), // Reduced from 8
        pw.Center(
          child: pw.Text(
            'ANSWER SHEET',
            style: pw.TextStyle(
              fontSize: 16, // Increased from 14
              fontWeight: pw.FontWeight.bold,
              font: _boldFont,
            ),
          ),
        ),
        pw.SizedBox(height: 3), // Reduced from 6
        pw.Text(
            'Paper: ${paper.title}', style: pw.TextStyle(font: _regularFont)),
        if (paper.examDate != null)
          pw.Text('Exam Date: ${_formatExamDate(paper.examDate!)}',
              style: pw.TextStyle(font: _regularFont)),
        pw.SizedBox(height: 4), // Reduced from 8
        pw.Container(height: 1, color: PdfColors.grey),
      ],
    );
  }

  pw.Widget _buildCompactInstructionsForSinglePage() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3), // Reduced from 6
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5),
        borderRadius: pw.BorderRadius.circular(2),
      ),

    );
  }

  pw.Widget _buildAnswerSheetInstructions() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4), // Reduced from 8
      decoration: pw.BoxDecoration(
        border: pw.Border.all(),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        'Instructions: Write your answers clearly in the spaces provided below.',
        style: pw.TextStyle(fontSize: 11, font: _regularFont), // Increased from 10
      ),
    );
  }

  // FIXED: Questions with proper section handling and error recovery
  List<pw.Widget> _buildCompactQuestionsForSinglePage(
      QuestionPaperEntity paper, double fontSizeMultiplier, double spacingMultiplier) {
    final widgets = <pw.Widget>[];
    final sortedSections = _getSortedSections(paper.questions);
    int sectionIndex = 1;

    for (final sectionEntry in sortedSections) {
      final sectionName = sectionEntry.key;
      final questions = sectionEntry.value;

      // SKIP EMPTY SECTIONS
      if (questions.isEmpty) continue;

      try {
        // Calculate section total marks
        final sectionMarks = questions.fold(0.0, (sum, q) => sum + q.totalMarks);
        final questionCount = questions.length;

        // Section header with roman numerals
        // Build section name with answer bank for fill_blanks
        String sectionHeaderText = '${_getRomanNumeral(sectionIndex)}. $sectionName';
        if (questions.first.type == 'fill_blanks' && questions.first.options != null && questions.first.options!.isNotEmpty) {
          final answerBank = questions.first.options!.join(', ');
          sectionHeaderText = '$sectionHeaderText [$answerBank]';
        }

        widgets.add(
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  sectionHeaderText,
                  style: pw.TextStyle(
                    fontSize: UIConstants.fontSizeSmall * fontSizeMultiplier,
                    fontWeight: pw.FontWeight.bold,
                    font: _boldFont,
                  ),
                ),
                pw.Text(
                  '$questionCount × ${(sectionMarks / questionCount).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')} = ${sectionMarks.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')} marks',
                  style: pw.TextStyle(
                    fontSize: 9 * fontSizeMultiplier,
                    fontWeight: pw.FontWeight.bold,
                    font: _boldFont,
                  ),
                ),
              ],
            ),
          ),
        );

        widgets.add(pw.SizedBox(height: 4 * spacingMultiplier)); // Increased from 1

        // COMMON INSTRUCTION FOR BULK QUESTIONS
        final commonInstruction = _getCommonInstruction(questions.first.type);
        if (commonInstruction.isNotEmpty) {
          widgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(2),
              margin: pw.EdgeInsets.only(bottom: 6 * spacingMultiplier), // Increased from 3
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Text(
                commonInstruction,
                style: pw.TextStyle(fontSize: 9 * fontSizeMultiplier, font: _regularFont),
              ),
            ),
          );
        }

        // SPECIAL HANDLING FOR WORD_FORMS: Display all items horizontally in one group
        if (questions.isNotEmpty && questions.first.type == 'word_forms') {
          final itemsText = questions.asMap().entries.map((entry) {
            final index = entry.key;
            final question = entry.value;
            final itemLabel = String.fromCharCode(97 + index); // a, b, c, d, e, ...
            return '$itemLabel) ${question.text}';
          }).join('  '); // Double space between items for wrapping

          widgets.add(
            pw.Text(
              itemsText,
              style: pw.TextStyle(
                fontSize: 11 * fontSizeMultiplier,
                fontWeight: pw.FontWeight.normal,
                font: _regularFont,
              ),
              maxLines: 3, // Allow wrapping across up to 3 lines
              textAlign: pw.TextAlign.left,
            ),
          );
        } else {
          // NORMAL PROCESSING FOR OTHER QUESTION TYPES
          // Compact questions with error handling
          for (int i = 0; i < questions.length; i++) {
            final question = questions[i];
            final questionNumber = i + 1;

            try {
              widgets.add(_buildSinglePageQuestion(
                question: question,
                questionNumber: questionNumber,
                showCommonText: commonInstruction.isEmpty,
                fontSizeMultiplier: fontSizeMultiplier,
              ));

              if (i < questions.length - 1) {
                widgets.add(pw.SizedBox(height: 6 * spacingMultiplier)); // Increased from 1 for better question separation
              }
            } catch (e) {
              // Skip malformed questions
              widgets.add(
                pw.Text(
                  '$questionNumber. [Question could not be displayed]',
                  style: pw.TextStyle(fontSize: 9 * fontSizeMultiplier, color: PdfColors.grey),
                ),
              );
            }
          }
        }

        widgets.add(pw.SizedBox(height: 12 * spacingMultiplier)); // Increased from 3 for section separation
        sectionIndex++;
      } catch (e) {
        // Skip entire section if there's an error
        widgets.add(
          pw.Text(
            'Section $sectionName: [Section could not be displayed]',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey), // Increased from 8
          ),
        );
      }
    }

    return widgets;
  }

  List<pw.Widget> _buildCompactQuestions(QuestionPaperEntity paper) {
    final widgets = <pw.Widget>[];
    final sortedSections = _getSortedSections(paper.questions);
    int sectionIndex = 1;

    for (final sectionEntry in sortedSections) {
      final sectionName = sectionEntry.key;
      final questions = sectionEntry.value;

      // SKIP EMPTY SECTIONS
      if (questions.isEmpty) continue;

      try {
        final sectionMarks = questions.fold(0.0, (sum, q) => sum + q.totalMarks);
        final questionCount = questions.length;

        // Compact section header with roman numerals
        // Build section name with answer bank for fill_blanks
        String sectionHeaderText = '${_getRomanNumeral(sectionIndex)}. $sectionName';
        if (questions.first.type == 'fill_blanks' && questions.first.options != null && questions.first.options!.isNotEmpty) {
          final answerBank = questions.first.options!.join(', ');
          sectionHeaderText = '$sectionHeaderText [$answerBank]';
        }

        widgets.add(
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1), // Reduced padding
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  sectionHeaderText,
                  style: pw.TextStyle(
                    fontSize: 10, // Increased from 9
                    fontWeight: pw.FontWeight.bold,
                    font: _boldFont,
                  ),
                ),
                pw.Text(
                  '$questionCount × ${(sectionMarks / questionCount).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')} = ${sectionMarks.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')} marks',
                  style: pw.TextStyle(
                    fontSize: 8, // Increased from 7
                    fontWeight: pw.FontWeight.bold,
                    font: _boldFont,
                  ),
                ),
              ],
            ),
          ),
        );

        widgets.add(pw.SizedBox(height: 1)); // Reduced from 2

        // COMMON INSTRUCTION FOR BULK QUESTIONS
        final commonInstruction = _getCommonInstruction(questions.first.type);
        if (commonInstruction.isNotEmpty) {
          widgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(2), // Reduced from 3
              margin: const pw.EdgeInsets.only(bottom: 2), // Reduced from 4
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(2),
              ),
              child: pw.Text(
                commonInstruction,
                style: pw.TextStyle(fontSize: 8, font: _regularFont), // Increased from 7
              ),
            ),
          );
        }

        // SPECIAL HANDLING FOR WORD_FORMS: Display all items horizontally in one group
        if (questions.isNotEmpty && questions.first.type == 'word_forms') {
          final itemsText = questions.asMap().entries.map((entry) {
            final index = entry.key;
            final question = entry.value;
            final itemLabel = String.fromCharCode(97 + index); // a, b, c, d, e, ...
            return '$itemLabel) ${question.text}';
          }).join('  '); // Double space between items for wrapping

          widgets.add(
            pw.Text(
              itemsText,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.normal,
                font: _regularFont,
              ),
              maxLines: 3, // Allow wrapping across up to 3 lines
              textAlign: pw.TextAlign.left,
            ),
          );
        } else {
          // NORMAL PROCESSING FOR OTHER QUESTION TYPES
          for (int i = 0; i < questions.length; i++) {
            final question = questions[i];
            final questionNumber = i + 1;

            try {
              widgets.add(_buildCompactSingleQuestion(
                question: question,
                questionNumber: questionNumber,
                showCommonText: commonInstruction.isEmpty,
              ));

              if (i < questions.length - 1) {
                widgets.add(pw.SizedBox(height: 2)); // Reduced from 4
              }
            } catch (e) {
              // Skip malformed questions
              widgets.add(
                pw.Text(
                  '$questionNumber. [Question error]',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey), // Increased from 7
                ),
              );
            }
          }
        }

        widgets.add(pw.SizedBox(height: 3)); // Reduced from 6
        sectionIndex++;
      } catch (e) {
        // Skip entire section if there's an error
        continue;
      }
    }

    return widgets;
  }

  // FIXED: Question rendering with matching support
  pw.Widget _buildSinglePageQuestion({
    required Question question,
    required int questionNumber,
    bool showCommonText = true,
    double fontSizeMultiplier = 1.0,
  }) {
    // CHANGED: For word_forms, display question text on one line, options horizontally on next line
    if (question.type == 'word_forms' && question.options != null && question.options!.isNotEmpty) {
      final optionsText = question.options!.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final optionLabel = String.fromCharCode(97 + index); // lowercase a, b, c, d, e, etc.
        return '$optionLabel) $option';
      }).join('  '); // Double space between options for better wrapping

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Question text on first line
          pw.Text(
            '$questionNumber. ${question.text}',
            style: pw.TextStyle(
              fontSize: 11 * fontSizeMultiplier,
              fontWeight: pw.FontWeight.normal,
              font: _regularFont,
            ),
          ),

          pw.SizedBox(height: 0.5), // Small gap between question and options

          // Options horizontally on second line
          pw.Text(
            optionsText,
            style: pw.TextStyle(
              fontSize: 11 * fontSizeMultiplier,
              fontWeight: pw.FontWeight.normal,
              font: _regularFont,
            ),
            maxLines: 3, // Allow wrapping across multiple lines if needed
            textAlign: pw.TextAlign.left,
          ),

          // Sub-questions
          if (question.subQuestions.isNotEmpty)
            ..._buildSinglePageSubQuestions(question.subQuestions, fontSizeMultiplier),
        ],
      );
    }

    // DEFAULT: Column layout for all other question types
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Question text (show full text or just specific part)
        pw.Text(
          showCommonText
              ? '$questionNumber. ${question.text}'
              : '$questionNumber. ${_extractSpecificText(
              question.text, question.type)}',
          style: pw.TextStyle(
            fontSize: 11 * fontSizeMultiplier,
            fontWeight: pw.FontWeight.normal,
            font: _regularFont,
          ),
        ),

        pw.SizedBox(height: 1),

        // FIXED: Proper matching question handling
        if (question.type == 'match_following' && question.options != null)
          _buildMatchingPairs(question.options!, fontSizeMultiplier)
        else
          if (question.options != null && question.options!.isNotEmpty)
            _buildSinglePageOptions(question, fontSizeMultiplier),

        // Sub-questions
        if (question.subQuestions.isNotEmpty)
          ..._buildSinglePageSubQuestions(question.subQuestions, fontSizeMultiplier),
      ],
    );
  }

  pw.Widget _buildCompactSingleQuestion({
    required Question question,
    required int questionNumber,
    bool showCommonText = true,
  }) {
    // CHANGED: For word_forms, display question text on one line, options horizontally on next line
    if (question.type == 'word_forms' && question.options != null && question.options!.isNotEmpty) {
      final optionsText = question.options!.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final optionLabel = String.fromCharCode(97 + index); // lowercase a, b, c, d, e, etc.
        return '$optionLabel) $option';
      }).join('   '); // Double space between options for readability

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Question text on first line
          pw.Text(
            '$questionNumber. ${question.text}',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              font: _regularFont,
            ),
          ),

          pw.SizedBox(height: 0.5), // Small gap between question and options

          // Options horizontally on second line
          pw.Text(
            optionsText,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.normal,
              font: _regularFont,
            ),
            maxLines: 2, // Allow wrapping if options are too long
            textAlign: pw.TextAlign.left,
          ),

          // Sub-questions
          if (question.subQuestions.isNotEmpty)
            ..._buildCompactSubQuestions(question.subQuestions),
        ],
      );
    }

    // DEFAULT: Column layout for all other question types
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Question text
        pw.Text(
          showCommonText
              ? '$questionNumber. ${question.text}'
              : '$questionNumber. ${_extractSpecificText(
              question.text, question.type)}',
          style: pw.TextStyle(
            fontSize: 9, // Increased from 8
            fontWeight: pw.FontWeight.normal,
            font: _regularFont,
          ),
        ),

        pw.SizedBox(height: 1), // Reduced from 2

        // FIXED: Proper matching question handling
        if (question.type == 'match_following' && question.options != null)
          _buildCompactMatchingPairs(question.options!)
        else
          if (question.options != null && question.options!.isNotEmpty)
            _buildCompactHorizontalOptions(question),

        // Sub-questions
        if (question.subQuestions.isNotEmpty)
          ..._buildCompactSubQuestions(question.subQuestions),
      ],
    );
  }

  // NEW: Matching pairs display
  pw.Widget _buildMatchingPairs(List<String> options, double fontSizeMultiplier) {
    try {
      int separatorIndex = options.indexOf('---SEPARATOR---');
      if (separatorIndex == -1) return pw.SizedBox.shrink();

      List<String> leftColumn = options.sublist(0, separatorIndex);
      List<String> rightColumn = options.sublist(separatorIndex + 1);

      return pw.Container(
        padding: const pw.EdgeInsets.all(3),
        margin: const pw.EdgeInsets.only(top: 2),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 0.5),
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Column(
          children: [
            // Headers
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'Column A',
                    style: pw.TextStyle(fontSize: 9 * fontSizeMultiplier,
                        fontWeight: pw.FontWeight.bold,
                        font: _boldFont),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: pw.Text(
                    'Column B',
                    style: pw.TextStyle(fontSize: 9 * fontSizeMultiplier,
                        fontWeight: pw.FontWeight.bold,
                        font: _boldFont),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 2),
            // Pairs
            ...List.generate(
              leftColumn.length.compareTo(rightColumn.length) <= 0 ? leftColumn
                  .length : rightColumn.length,
                  (i) =>
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 1),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            i < leftColumn.length
                                ? '${i + 1}. ${leftColumn[i]}'
                                : '',
                            style: pw.TextStyle(
                                fontSize: 9 * fontSizeMultiplier, font: _regularFont),
                          ),
                        ),
                        pw.SizedBox(width: 20),
                        pw.Expanded(
                          child: pw.Text(
                            i < rightColumn.length ? '${String.fromCharCode(65 +
                                i)}. ${rightColumn[i]}' : '',
                            style: pw.TextStyle(
                                fontSize: 9 * fontSizeMultiplier, font: _regularFont),
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          ],
        ),
      );
    } catch (e) {
      return pw.Text('[Matching question error]',
          style: pw.TextStyle(fontSize: 9 * fontSizeMultiplier, color: PdfColors.grey));
    }
  }

  pw.Widget _buildCompactMatchingPairs(List<String> options) {
    try {
      int separatorIndex = options.indexOf('---SEPARATOR---');
      if (separatorIndex == -1) return pw.SizedBox.shrink();

      List<String> leftColumn = options.sublist(0, separatorIndex);
      List<String> rightColumn = options.sublist(separatorIndex + 1);

      return pw.Container(
        padding: const pw.EdgeInsets.all(2), // Reduced from 4
        margin: const pw.EdgeInsets.only(top: 1), // Reduced from 2
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 0.3),
          borderRadius: pw.BorderRadius.circular(2),
        ),
        child: pw.Column(
          children: [
            // Headers
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'Column A',
                    style: pw.TextStyle(fontSize: 7, // Increased from 6
                        fontWeight: pw.FontWeight.bold,
                        font: _boldFont),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Text(
                    'Column B',
                    style: pw.TextStyle(fontSize: 7, // Increased from 6
                        fontWeight: pw.FontWeight.bold,
                        font: _boldFont),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 1), // Reduced from 2
            // Pairs
            ...List.generate(
              leftColumn.length.compareTo(rightColumn.length) <= 0 ? leftColumn
                  .length : rightColumn.length,
                  (i) =>
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 0.5), // Reduced from 1
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            i < leftColumn.length
                                ? '${i + 1}. ${leftColumn[i]}'
                                : '',
                            style: pw.TextStyle(
                                fontSize: 7, font: _regularFont), // Increased from 6
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          child: pw.Text(
                            i < rightColumn.length ? '${String.fromCharCode(65 +
                                i)}. ${rightColumn[i]}' : '',
                            style: pw.TextStyle(
                                fontSize: 7, font: _regularFont), // Increased from 6
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          ],
        ),
      );
    } catch (e) {
      return pw.Text(
          '[Error]', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey)); // Increased from 6
    }
  }

  pw.Widget _buildSinglePageOptions(Question question, double fontSizeMultiplier) {
    return pw.Wrap(
      spacing: 10,
      runSpacing: 1,
      children: question.options!.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final optionLabel = String.fromCharCode(65 + index);

        return pw.Text(
          '$optionLabel) $option',
          style: pw.TextStyle(
            fontSize: 9 * fontSizeMultiplier,
            font: _regularFont,
          ),
        );
      }).toList(),
    );
  }

  pw.Widget _buildCompactHorizontalOptions(Question question) {
    return pw.Wrap(
      spacing: 8,
      runSpacing: 1, // Reduced from 2
      children: question.options!.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final optionLabel = String.fromCharCode(65 + index);

        return pw.Container(
          child: pw.Text(
            '$optionLabel) $option',
            style: pw.TextStyle(
              fontSize: 8, // Increased from 7
              font: _regularFont,
            ),
          ),
        );
      }).toList(),
    );
  }

  List<pw.Widget> _buildSinglePageSubQuestions(List<SubQuestion> subQuestions, double fontSizeMultiplier) {
    final widgets = <pw.Widget>[];

    widgets.add(pw.SizedBox(height: 1));

    for (int i = 0; i < subQuestions.length; i++) {
      final subQuestion = subQuestions[i];
      final subLabel = String.fromCharCode(97 + i);

      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(left: 8, bottom: 0.5),
          child: pw.Text(
            '$subLabel) ${subQuestion.text}',
            style: pw.TextStyle(fontSize: 9 * fontSizeMultiplier, font: _regularFont),
          ),
        ),
      );
    }

    return widgets;
  }

  List<pw.Widget> _buildCompactSubQuestions(List<SubQuestion> subQuestions) {
    final widgets = <pw.Widget>[];

    widgets.add(pw.SizedBox(height: 1)); // Reduced from 2

    for (int i = 0; i < subQuestions.length; i++) {
      final subQuestion = subQuestions[i];
      final subLabel = String.fromCharCode(97 + i);

      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(left: 6, bottom: 0.5), // Reduced bottom margin
          child: pw.Text(
            '$subLabel) ${subQuestion.text}',
            style: pw.TextStyle(fontSize: 8, font: _regularFont), // Increased from 7
          ),
        ),
      );
    }

    return widgets;
  }

  // Answer sheet content with error recovery

  List<pw.Widget> _buildMatchingAnswerBoxes() {
    return List.generate(5, (i) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(right: 15),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text('${i + 1}:', style: pw.TextStyle(fontSize: 11)), // Increased from 10
            pw.SizedBox(width: 4),
            pw.Container(
              width: 20,
              height: 12,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(),
              ),
            ),
          ],
        ),
      );
    });
  }

  // Helper methods
  String _getRomanNumeral(int number) {
    switch (number) {
      case 1:
        return 'I';
      case 2:
        return 'II';
      case 3:
        return 'III';
      case 4:
        return 'IV';
      case 5:
        return 'V';
      case 6:
        return 'VI';
      case 7:
        return 'VII';
      case 8:
        return 'VIII';
      case 9:
        return 'IX';
      case 10:
        return 'X';
      case 11:
        return 'XI';
      case 12:
        return 'XII';
      case 13:
        return 'XIII';
      case 14:
        return 'XIV';
      case 15:
        return 'XV';
      default:
        return number.toString();
    }
  }

  List<MapEntry<String, List<Question>>> _getSortedSections(
      Map<String, List<Question>> questions) {
    final entries = questions.entries.toList();

    // Sort sections by average marks per question (easy → hard)
    entries.sort((a, b) {
      // Calculate average marks for section A
      final avgMarksA = a.value.isEmpty
          ? 0.0
          : a.value.fold(0.0, (sum, q) => sum + q.totalMarks) / a.value.length;

      // Calculate average marks for section B
      final avgMarksB = b.value.isEmpty
          ? 0.0
          : b.value.fold(0.0, (sum, q) => sum + q.totalMarks) / b.value.length;

      // Sort ascending (easy questions with low marks first)
      return avgMarksA.compareTo(avgMarksB);
    });

    return entries;
  }

  String _getCommonInstruction(String questionType) {
    switch (questionType) {
      case 'missing_letters':
      // FIXED: Remove repetitive instruction since questions now have varied, self-contained text
        return '';
      default:
        return '';
    }
  }

  String _extractSpecificText(String questionText, String questionType) {
    final commonInstruction = _getCommonInstruction(questionType);
    if (commonInstruction.isEmpty) return questionText;

    // Remove common instruction from question text if it exists
    String cleaned = questionText;
    if (cleaned.toLowerCase().startsWith(commonInstruction.toLowerCase())) {
      cleaned = cleaned.substring(commonInstruction.length).trim();
    }

    // FIXED: For missing letters, also clean any variations of the instruction
    if (questionType == 'missing_letters') {
      final instructionVariations = [
        'fill the missing letters:',
        'complete the word:',
        'add the missing letters:',
        'complete:',
        'fill in the blanks:',
        'fill in the missing letters:',
      ];

      for (final instruction in instructionVariations) {
        if (cleaned.toLowerCase().startsWith(instruction)) {
          cleaned = cleaned.substring(instruction.length).trim();
          break;
        }
      }
    }

    return cleaned.isEmpty ? questionText : cleaned;
  }

  String _formatExamDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Calculate estimated height for a question in points
  double _calculateQuestionHeight(Question question) {
    double height = 0;

    // Base question text height (varies by text length)
    final textLength = question.text.length;
    if (textLength <= 50) {
      height += 15; // Single line
    } else if (textLength <= 100) {
      height += 25; // Two lines
    } else {
      height += 35; // Multiple lines
    }

    // Spacing after question text
    height += 3;

    // Options height (depends on question type)
    if (question.options != null && question.options!.isNotEmpty) {
      if (question.type == 'match_following') {
        // Matching questions take significantly more space (table layout)
        final maxPairs = question.options!.length ~/ 2;
        height += 15 + (maxPairs * 10); // Header + rows
      } else {
        // MCQ options (horizontal wrap)
        final optionCount = question.options!.length;
        final avgOptionLength = question.options!.map((o) => o.length).reduce((a, b) => a + b) / optionCount;

        if (avgOptionLength > 30) {
          // Long options, likely vertical
          height += optionCount * 12;
        } else {
          // Short options, horizontal wrap
          height += ((optionCount / 2).ceil()) * 12;
        }
      }
      height += 3;
    }

    // Sub-questions height
    if (question.subQuestions.isNotEmpty) {
      height += 3; // Spacing before sub-questions
      for (final subQ in question.subQuestions) {
        final subTextLength = subQ.text.length;
        if (subTextLength <= 40) {
          height += 12;
        } else {
          height += 18;
        }
      }
    }

    // Spacing after question
    height += 4;

    return height;
  }

  /// Calculate total height for a section including header
  double _calculateSectionHeight(String sectionName, List<Question> questions) {
    if (questions.isEmpty) return 0;

    double height = 0;

    // Section header
    height += 20;

    // Common instruction (if applicable)
    final commonInstruction = _getCommonInstruction(questions.first.type);
    if (commonInstruction.isNotEmpty) {
      height += 18;
    }

    // Questions
    for (final question in questions) {
      height += _calculateQuestionHeight(question);
    }

    // Spacing after section
    height += 6;

    return height;
  }

  /// Balance content across dual layout pages using space-based algorithm
  List<DualPageData> _balanceContentForDualLayout(
    List<MapEntry<String, List<Question>>> allSections,
    String schoolName,
    QuestionPaperEntity paper,
  ) {
    final pages = <DualPageData>[];
    int currentSectionIndex = 1;

    // Flatten all sections into list of (section, question) pairs
    final allItems = <_SectionItem>[];
    for (final section in allSections) {
      for (final question in section.value) {
        allItems.add(_SectionItem(
          sectionName: section.key,
          question: question,
          sectionIndex: currentSectionIndex,
        ));
      }
      currentSectionIndex++;
    }

    // Balance items into pages
    int itemIndex = 0;
    int pageNumber = 1;

    while (itemIndex < allItems.length) {
      // Try to fit as many items as possible on this page
      final pageItems = <_SectionItem>[];
      double pageHeight = 0;
      final maxPageHeight = AVAILABLE_CONTENT_HEIGHT * 2; // Both sides combined

      while (itemIndex < allItems.length && pageHeight < maxPageHeight) {
        final item = allItems[itemIndex];
        final itemHeight = _calculateQuestionHeight(item.question) + 5; // +5 for buffer

        if (pageHeight + itemHeight <= maxPageHeight || pageItems.isEmpty) {
          pageItems.add(item);
          pageHeight += itemHeight;
          itemIndex++;
        } else {
          break; // Page full
        }
      }

      // Balance page items into left and right columns
      final (leftItems, rightItems) = _balanceItems(pageItems);

      // Build left and right content
      final leftSections = _groupItemsBySection(leftItems);
      final rightSections = _groupItemsBySection(rightItems);

      final leftContent = pageNumber == 1
          ? _buildSinglePaperLayout(schoolName, paper, sectionsToShow: leftSections)
          : _buildContinuationLayout(paper, leftSections);

      final rightContent = _buildContinuationLayout(paper, rightSections);

      pages.add(DualPageData(
        leftContent: leftContent,
        rightContent: rightContent,
        pageNumber: pageNumber,
      ));

      pageNumber++;
    }

    return pages;
  }

  /// Balance items between left and right columns based on space
  (List<_SectionItem>, List<_SectionItem>) _balanceItems(List<_SectionItem> items) {
    final leftItems = <_SectionItem>[];
    final rightItems = <_SectionItem>[];
    double leftHeight = 0;
    double rightHeight = 0;

    for (final item in items) {
      final itemHeight = _calculateQuestionHeight(item.question);

      // Add to the side with less content
      if (leftHeight <= rightHeight && leftHeight + itemHeight <= AVAILABLE_CONTENT_HEIGHT) {
        leftItems.add(item);
        leftHeight += itemHeight;
      } else if (rightHeight + itemHeight <= AVAILABLE_CONTENT_HEIGHT) {
        rightItems.add(item);
        rightHeight += itemHeight;
      } else {
        // If both sides full, add to left (will overflow to next page)
        leftItems.add(item);
        leftHeight += itemHeight;
      }
    }

    return (leftItems, rightItems);
  }

  /// Group items back into section maps
  Map<String, List<Question>> _groupItemsBySection(List<_SectionItem> items) {
    final sections = <String, List<Question>>{};

    for (final item in items) {
      sections.putIfAbsent(item.sectionName, () => []).add(item.question);
    }

    return sections;
  }

  /// Compress content - fill left side COMPLETELY first, only use right when left is full
  /// This saves paper by maximizing space usage while keeping content continuous
  List<DualPageData> _compressContentForDualLayout(
    List<MapEntry<String, List<Question>>> allSections,
    String schoolName,
    QuestionPaperEntity paper,
  ) {
    final pages = <DualPageData>[];

    // Calculate total content height
    double totalHeight = 0;
    for (final section in allSections) {
      totalHeight += _calculateSectionHeight(section.key, section.value);
    }

    // If all content fits on LEFT side only, don't use right side at all
    if (totalHeight <= AVAILABLE_CONTENT_HEIGHT) {
      final leftContent = _buildSinglePaperLayout(schoolName, paper);

      pages.add(DualPageData(
        leftContent: leftContent,
        rightContent: pw.Container(), // Right side empty
        pageNumber: 1,
      ));

      return pages;
    }

    // Content needs to overflow - fill left completely, then use right
    // Split sections by height for left and right
    final leftSections = <MapEntry<String, List<Question>>>[];
    final rightSections = <MapEntry<String, List<Question>>>[];
    double leftHeight = 0;
    double rightHeight = 0;

    for (final section in allSections) {
      final sectionHeight = _calculateSectionHeight(section.key, section.value);

      // Try to fit entire section on left first
      if (leftHeight + sectionHeight <= AVAILABLE_CONTENT_HEIGHT * 0.95) {
        leftSections.add(section);
        leftHeight += sectionHeight;
      } else {
        // Left is full, add to right
        rightSections.add(section);
        rightHeight += sectionHeight;
      }
    }

    // Build single page with full left, continuation on right
    final leftContent = _buildSinglePaperLayout(
      schoolName,
      paper,
      sectionsToShow: Map.fromEntries(leftSections),
      startingSectionIndex: 1,
    );

    final rightContent = rightSections.isNotEmpty
        ? _buildContinuationLayout(
            paper,
            Map.fromEntries(rightSections),
            startingSectionIndex: leftSections.length + 1,
          )
        : pw.Container();

    pages.add(DualPageData(
      leftContent: leftContent,
      rightContent: rightContent,
      pageNumber: 1,
    ));

    // If right side also overflows (very long papers), create additional pages
    if (rightHeight > AVAILABLE_CONTENT_HEIGHT) {
      // TODO: Handle extreme cases with 40+ questions
      // For now, content will be compressed on right side
    }

    return pages;
  }
}

class _SectionItem {
  final String sectionName;
  final Question question;
  final int sectionIndex;

  _SectionItem({
    required this.sectionName,
    required this.question,
    required this.sectionIndex,
  });
}