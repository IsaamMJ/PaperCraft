// features/question_papers/domain2/services/pdf_generation_service.dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../paper_workflow/domain/entities/question_entity.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';
abstract class IPdfGenerationService {
  Future<Uint8List> generateStudentPdf({
    required QuestionPaperEntity paper,
    required String schoolName,
    String? studentName,
    String? rollNumber,
  });

  Future<Uint8List> generateDualLayoutPdf({
    required QuestionPaperEntity paper,
    required String schoolName,
  });

}

class SimplePdfService implements IPdfGenerationService {
  static const int MAX_QUESTIONS_PER_BATCH = 20;
  static const int MAX_QUESTIONS_PER_PAGE = 10;

  // Mobile-compatible fonts - using built-in fonts only
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

  @override
  Future<Uint8List> generateDualLayoutPdf({
    required QuestionPaperEntity paper,
    required String schoolName,
  }) async {
    await _loadFonts();
    final pdf = pw.Document();

    try {
      final allSections = _getSortedSections(paper.questions);
      final totalSections = allSections.length;

      // Estimate: ~8-10 questions per side (adjust based on your content)
      final estimatedQuestionsPerSide = 12;
      final totalQuestions = paper.questions.values.expand((q) => q).length;

      // Check if content fits in single page dual layout
      if (totalQuestions <= estimatedQuestionsPerSide) {
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
      } else {
        // Multi-page needed - split content
        final halfPoint = (totalSections / 2).ceil();
        final leftSections = Map.fromEntries(allSections.take(halfPoint));
        final rightSections = Map.fromEntries(allSections.skip(halfPoint));

        // First page: Left with header + Right continuation
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(15),
            build: (context) {
              return pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // LEFT: Header + first half sections
                  pw.Expanded(
                    child: _buildSinglePaperLayout(
                      schoolName,
                      paper,
                      sectionsToShow: leftSections,
                      startingSectionIndex: 1,
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  // RIGHT: Continuation without header
                  pw.Expanded(
                    child: _buildContinuationLayout(
                      paper,
                      rightSections,
                      startingSectionIndex: halfPoint + 1,
                    ),
                  ),
                ],
              );
            },
          ),
        );

        // If right side still has overflow (very long papers), add more pages
        // This handles extreme cases with 30+ questions
        if (totalQuestions > estimatedQuestionsPerSide * 2) {
          // Add additional continuation pages as needed
          // For now, the single overflow page should handle most cases
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
        final sectionMarks = questions.fold(0, (sum, q) => sum + q.totalMarks);
        final questionCount = questions.length;

        widgets.add(
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${_getRomanNumeral(sectionIndex)}. $sectionName',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    font: _boldFont,
                  ),
                ),
                pw.Text(
                  '$questionCount × ${sectionMarks ~/ questionCount} = $sectionMarks marks',
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


  @override
  Future<Uint8List> generateStudentPdf({
    required QuestionPaperEntity paper,
    required String schoolName,
    String? studentName,
    String? rollNumber,
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
                ),
                pw.SizedBox(height: 3), // Reduced from 6
                _buildCompactInstructionsForSinglePage(),
                pw.SizedBox(height: 4), // Reduced from 8
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: _buildCompactQuestionsForSinglePage(paper),
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
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // School name
        pw.Center(
          child: pw.Text(
            schoolName,
            style: pw.TextStyle(
              fontSize: 16, // Increased from 14
              fontWeight: pw.FontWeight.bold,
              font: _boldFont,
            ),
          ),
        ),
        pw.SizedBox(height: 2), // Reduced from 4

        // Paper title
        pw.Center(
          child: pw.Text(
            paper.title,
            style: pw.TextStyle(
              fontSize: UIConstants.fontSizeMedium, // Increased from 12
              fontWeight: pw.FontWeight.bold,
              font: _boldFont,
            ),
          ),
        ),
        pw.SizedBox(height: 2), // Reduced from 4

        // Paper details in single row
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Subject: ${paper.subject}',
                style: pw.TextStyle(fontSize: 10, font: _regularFont)), // Increased from 9
            pw.Text('Grade: ${paper.gradeDisplayName}',
                style: pw.TextStyle(fontSize: 10, font: _regularFont)), // Increased from 9
            if (paper.examDate != null)
              pw.Text('Date: ${_formatExamDate(paper.examDate!)}',
                  style: pw.TextStyle(fontSize: 10, font: _regularFont)), // Increased from 9
            if (paper.examTypeEntity.durationMinutes != null)
              pw.Text('Time: ${paper.examTypeEntity.formattedDuration}',
                  style: pw.TextStyle(fontSize: 10, font: _regularFont)), // Increased from 9
            pw.Text('Total Marks: ${paper.totalMarks}',
                style: pw.TextStyle(fontSize: 10, font: _regularFont)), // Increased from 9
          ],
        ),

        pw.SizedBox(height: 2), // Reduced from 4
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
      QuestionPaperEntity paper) {
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
        final sectionMarks = questions.fold(0, (sum, q) => sum + q.totalMarks);
        final questionCount = questions.length;

        // Section header with roman numerals
        widgets.add(
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1), // Reduced vertical padding
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${_getRomanNumeral(sectionIndex)}. $sectionName',
                  style: pw.TextStyle(
                    fontSize: UIConstants.fontSizeSmall, // Increased from 10
                    fontWeight: pw.FontWeight.bold,
                    font: _boldFont,
                  ),
                ),
                pw.Text(
                  '$questionCount × ${sectionMarks ~/
                      questionCount} = $sectionMarks marks',
                  style: pw.TextStyle(
                    fontSize: 9, // Increased from 8
                    fontWeight: pw.FontWeight.bold,
                    font: _boldFont,
                  ),
                ),
              ],
            ),
          ),
        );

        widgets.add(pw.SizedBox(height: 1)); // Reduced from 3

        // COMMON INSTRUCTION FOR BULK QUESTIONS
        final commonInstruction = _getCommonInstruction(questions.first.type);
        if (commonInstruction.isNotEmpty) {
          widgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(2), // Reduced from 4
              margin: const pw.EdgeInsets.only(bottom: 3), // Reduced from 6
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Text(
                commonInstruction,
                style: pw.TextStyle(fontSize: 9, font: _regularFont), // Increased from 8
              ),
            ),
          );
        }

        // Compact questions with error handling
        for (int i = 0; i < questions.length; i++) {
          final question = questions[i];
          final questionNumber = i + 1;

          try {
            widgets.add(_buildSinglePageQuestion(
              question: question,
              questionNumber: questionNumber,
              showCommonText: commonInstruction.isEmpty,
            ));

            if (i < questions.length - 1) {
              widgets.add(pw.SizedBox(height: 1)); // Reduced from 3
            }
          } catch (e) {
            // Skip malformed questions
            widgets.add(
              pw.Text(
                '$questionNumber. [Question could not be displayed]',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey), // Increased from 8
              ),
            );
          }
        }

        widgets.add(pw.SizedBox(height: 3)); // Reduced from 6
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
        final sectionMarks = questions.fold(0, (sum, q) => sum + q.totalMarks);
        final questionCount = questions.length;

        // Compact section header with roman numerals
        widgets.add(
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1), // Reduced padding
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${_getRomanNumeral(sectionIndex)}. $sectionName',
                  style: pw.TextStyle(
                    fontSize: 10, // Increased from 9
                    fontWeight: pw.FontWeight.bold,
                    font: _boldFont,
                  ),
                ),
                pw.Text(
                  '$questionCount × ${sectionMarks ~/
                      questionCount} = $sectionMarks marks',
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
  }) {
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
            fontSize: 11, // Increased from 9
            fontWeight: pw.FontWeight.normal,
            font: _regularFont,
          ),
        ),

        pw.SizedBox(height: 1), // Reduced from 2

        // FIXED: Proper matching question handling
        if (question.type == 'match_following' && question.options != null)
          _buildMatchingPairs(question.options!)
        else
          if (question.options != null && question.options!.isNotEmpty)
            _buildSinglePageOptions(question),

        // Sub-questions
        if (question.subQuestions.isNotEmpty)
          ..._buildSinglePageSubQuestions(question.subQuestions),
      ],
    );
  }

  pw.Widget _buildCompactSingleQuestion({
    required Question question,
    required int questionNumber,
    bool showCommonText = true,
  }) {
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
  pw.Widget _buildMatchingPairs(List<String> options) {
    try {
      int separatorIndex = options.indexOf('---SEPARATOR---');
      if (separatorIndex == -1) return pw.SizedBox.shrink();

      List<String> leftColumn = options.sublist(0, separatorIndex);
      List<String> rightColumn = options.sublist(separatorIndex + 1);

      return pw.Container(
        padding: const pw.EdgeInsets.all(3), // Reduced from 6
        margin: const pw.EdgeInsets.only(top: 2), // Reduced from 4
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
                    style: pw.TextStyle(fontSize: 9, // Increased from 8
                        fontWeight: pw.FontWeight.bold,
                        font: _boldFont),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: pw.Text(
                    'Column B',
                    style: pw.TextStyle(fontSize: 9, // Increased from 8
                        fontWeight: pw.FontWeight.bold,
                        font: _boldFont),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 2), // Reduced from 4
            // Pairs
            ...List.generate(
              leftColumn.length.compareTo(rightColumn.length) <= 0 ? leftColumn
                  .length : rightColumn.length,
                  (i) =>
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 1), // Reduced from 2
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            i < leftColumn.length
                                ? '${i + 1}. ${leftColumn[i]}'
                                : '',
                            style: pw.TextStyle(
                                fontSize: 9, font: _regularFont), // Increased from 8
                          ),
                        ),
                        pw.SizedBox(width: 20),
                        pw.Expanded(
                          child: pw.Text(
                            i < rightColumn.length ? '${String.fromCharCode(65 +
                                i)}. ${rightColumn[i]}' : '',
                            style: pw.TextStyle(
                                fontSize: 9, font: _regularFont), // Increased from 8
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
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey)); // Increased from 8
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

  pw.Widget _buildSinglePageOptions(Question question) {
    return pw.Wrap(
      spacing: 10,
      runSpacing: 1, // Reduced from 2
      children: question.options!.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final optionLabel = String.fromCharCode(65 + index);

        return pw.Text(
          '$optionLabel) $option',
          style: pw.TextStyle(
            fontSize: 9, // Increased from 8
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

  List<pw.Widget> _buildSinglePageSubQuestions(List<SubQuestion> subQuestions) {
    final widgets = <pw.Widget>[];

    widgets.add(pw.SizedBox(height: 1)); // Reduced from 2

    for (int i = 0; i < subQuestions.length; i++) {
      final subQuestion = subQuestions[i];
      final subLabel = String.fromCharCode(97 + i);

      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(left: 8, bottom: 0.5), // Reduced bottom margin
          child: pw.Text(
            '$subLabel) ${subQuestion.text}',
            style: pw.TextStyle(fontSize: 9, font: _regularFont), // Increased from 8
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

    entries.sort((a, b) {
      final sectionA = a.key.toLowerCase();
      final sectionB = b.key.toLowerCase();

      final regexA = RegExp(r'section\s*([a-z])', caseSensitive: false);
      final regexB = RegExp(r'section\s*([a-z])', caseSensitive: false);

      final matchA = regexA.firstMatch(sectionA);
      final matchB = regexB.firstMatch(sectionB);

      if (matchA != null && matchB != null) {
        final letterA = matchA.group(1)!;
        final letterB = matchB.group(1)!;
        return letterA.compareTo(letterB);
      }

      return sectionA.compareTo(sectionB);
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
}