// features/question_papers/domain2/services/pdf_generation_service.dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../entities/question_entity.dart';
import '../entities/question_paper_entity.dart';

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

  Future<Uint8List> generateAnswerSheet({
    required QuestionPaperEntity paper,
    required String schoolName,
    String? studentName,
    String? rollNumber,
  });
}

class SimplePdfService implements IPdfGenerationService {
  static const _defaultSchoolName = 'Pearl Matriculation Higher Secondary School, Nagercoil';
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
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(15),
          build: (context) {
            return pw.Row(
              children: [
                // Left paper
                pw.Expanded(
                  child: _buildSinglePaperLayout(schoolName, paper),
                ),
                pw.SizedBox(width: 10),
                // Right paper (identical)
                pw.Expanded(
                  child: _buildSinglePaperLayout(schoolName, paper),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      // Error recovery - create simpler layout if complex one fails
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

  pw.Widget _buildSinglePaperLayout(String schoolName,
      QuestionPaperEntity paper) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildCompactHeader(schoolName: schoolName, paper: paper),
          pw.SizedBox(height: 8),
          _buildCompactInstructions(),
          pw.SizedBox(height: 8),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: _buildCompactQuestions(paper),
            ),
          ),
        ],
      ),
    );
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
                pw.SizedBox(height: 6),
                _buildCompactInstructionsForSinglePage(),
                pw.SizedBox(height: 8),
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

  @override
  Future<Uint8List> generateAnswerSheet({
    required QuestionPaperEntity paper,
    required String schoolName,
    String? studentName,
    String? rollNumber,
  }) async {
    await _loadFonts();
    final pdf = pw.Document();

    try {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          header: (context) =>
              _buildAnswerSheetHeader(
                schoolName: schoolName,
                paper: paper,
                studentName: studentName,
                rollNumber: rollNumber,
              ),
          build: (context) =>
          [
            _buildAnswerSheetInstructions(),
            pw.SizedBox(height: 10),
            ..._buildAnswerSheetContent(paper),
          ],
        ),
      );
    } catch (e) {
      // Error recovery
      pdf.addPage(
        pw.Page(
          build: (context) =>
              pw.Center(
                child: pw.Text(
                    'Error generating answer sheet. Please contact support.'),
              ),
        ),
      );
    }

    return pdf.save();
  }

  Future<void> _loadFonts() async {
    try {
      // Use basic built-in fonts that work on all mobile devices
      _regularFont = pw.Font.courier(); // Monospace - most compatible
      _boldFont = pw.Font.courierBold();
    } catch (e) {
      // Absolute fallback - no custom fonts
      _regularFont = null;
      _boldFont = null;
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
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              font: _boldFont,
            ),
          ),
        ),
        pw.SizedBox(height: 4),

        // Paper title
        pw.Center(
          child: pw.Text(
            paper.title,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              font: _boldFont,
            ),
          ),
        ),
        pw.SizedBox(height: 4),

        // Paper details in single row
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Subject: ${paper.subject}',
                style: pw.TextStyle(fontSize: 9, font: _regularFont)),
            pw.Text('Grade: ${paper.gradeDisplayName}',
                style: pw.TextStyle(fontSize: 9, font: _regularFont)),
            if (paper.examDate != null)
              pw.Text('Date: ${_formatExamDate(paper.examDate!)}',
                  style: pw.TextStyle(fontSize: 9, font: _regularFont)),
            if (paper.examTypeEntity.durationMinutes != null)
              pw.Text('Time: ${paper.examTypeEntity.formattedDuration}',
                  style: pw.TextStyle(fontSize: 9, font: _regularFont)),
            pw.Text('Total Marks: ${paper.totalMarks}',
                style: pw.TextStyle(fontSize: 9, font: _regularFont)),
          ],
        ),


        pw.SizedBox(height: 4),
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
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              font: _boldFont,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.SizedBox(height: 4),

        // Paper title
        pw.Center(
          child: pw.Text(
            paper.title,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              font: _boldFont,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.SizedBox(height: 4),

        // Paper details
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('${paper.subject} | ${paper.gradeDisplayName}',
                style: pw.TextStyle(fontSize: 8, font: _regularFont)),
            if (paper.examDate != null)
              pw.Text('Date: ${_formatExamDate(paper.examDate!)}',
                  style: pw.TextStyle(fontSize: 8, font: _regularFont)),
            pw.Text('Marks: ${paper.totalMarks}',
                style: pw.TextStyle(fontSize: 8, font: _regularFont)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.SizedBox(height: 4),
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
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              font: _boldFont,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(
            'ANSWER SHEET',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              font: _boldFont,
            ),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
            'Paper: ${paper.title}', style: pw.TextStyle(font: _regularFont)),
        if (paper.examDate != null)
          pw.Text('Exam Date: ${_formatExamDate(paper.examDate!)}',
              style: pw.TextStyle(font: _regularFont)),
        pw.SizedBox(height: 8),
        pw.Container(height: 1, color: PdfColors.grey),
      ],
    );
  }

  pw.Widget _buildCompactInstructionsForSinglePage() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5),
        borderRadius: pw.BorderRadius.circular(2),
      ),
      child: pw.Text(
        'Instructions: Read all questions carefully. Answer all questions.',
        style: pw.TextStyle(fontSize: 8, font: _regularFont),
      ),
    );
  }

  pw.Widget _buildCompactInstructions() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5),
        borderRadius: pw.BorderRadius.circular(2),
      ),
      child: pw.Text(
        'Instructions: Read all questions carefully. Answer all questions.',
        style: pw.TextStyle(fontSize: 7, font: _regularFont),
      ),
    );
  }

  pw.Widget _buildAnswerSheetInstructions() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        'Instructions: Write your answers clearly in the spaces provided below.',
        style: pw.TextStyle(fontSize: 10, font: _regularFont),
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
            padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
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
                  '$questionCount × ${sectionMarks ~/
                      questionCount} = $sectionMarks marks',
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

        widgets.add(pw.SizedBox(height: 3));

        // COMMON INSTRUCTION FOR BULK QUESTIONS
        final commonInstruction = _getCommonInstruction(questions.first.type);
        if (commonInstruction.isNotEmpty) {
          widgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              margin: const pw.EdgeInsets.only(bottom: 6),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Text(
                commonInstruction,
                style: pw.TextStyle(fontSize: 8, font: _regularFont),
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
              widgets.add(pw.SizedBox(height: 3));
            }
          } catch (e) {
            // Skip malformed questions
            widgets.add(
              pw.Text(
                '$questionNumber. [Question could not be displayed]',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
            );
          }
        }

        widgets.add(pw.SizedBox(height: 6));
        sectionIndex++;
      } catch (e) {
        // Skip entire section if there's an error
        widgets.add(
          pw.Text(
            'Section $sectionName: [Section could not be displayed]',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
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
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${_getRomanNumeral(sectionIndex)}. $sectionName',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    font: _boldFont,
                  ),
                ),
                pw.Text(
                  '$questionCount × ${sectionMarks ~/
                      questionCount} = $sectionMarks marks',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    font: _boldFont,
                  ),
                ),
              ],
            ),
          ),
        );

        widgets.add(pw.SizedBox(height: 4));

        // COMMON INSTRUCTION FOR BULK QUESTIONS
        final commonInstruction = _getCommonInstruction(questions.first.type);
        if (commonInstruction.isNotEmpty) {
          widgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(3),
              margin: const pw.EdgeInsets.only(bottom: 4),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(2),
              ),
              child: pw.Text(
                commonInstruction,
                style: pw.TextStyle(fontSize: 7, font: _regularFont),
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
              widgets.add(pw.SizedBox(height: 4));
            }
          } catch (e) {
            // Skip malformed questions
            widgets.add(
              pw.Text(
                '$questionNumber. [Question error]',
                style: pw.TextStyle(fontSize: 7, color: PdfColors.grey),
              ),
            );
          }
        }

        widgets.add(pw.SizedBox(height: 6));
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
            fontSize: 9,
            fontWeight: pw.FontWeight.normal,
            font: _regularFont,
          ),
        ),

        pw.SizedBox(height: 2),

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
            fontSize: 8,
            fontWeight: pw.FontWeight.normal,
            font: _regularFont,
          ),
        ),

        pw.SizedBox(height: 2),

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
        padding: const pw.EdgeInsets.all(6),
        margin: const pw.EdgeInsets.only(top: 4),
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
                    style: pw.TextStyle(fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        font: _boldFont),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: pw.Text(
                    'Column B',
                    style: pw.TextStyle(fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        font: _boldFont),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            // Pairs
            ...List.generate(
              leftColumn.length.compareTo(rightColumn.length) <= 0 ? leftColumn
                  .length : rightColumn.length,
                  (i) =>
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            i < leftColumn.length
                                ? '${i + 1}. ${leftColumn[i]}'
                                : '',
                            style: pw.TextStyle(
                                fontSize: 8, font: _regularFont),
                          ),
                        ),
                        pw.SizedBox(width: 20),
                        pw.Expanded(
                          child: pw.Text(
                            i < rightColumn.length ? '${String.fromCharCode(65 +
                                i)}. ${rightColumn[i]}' : '',
                            style: pw.TextStyle(
                                fontSize: 8, font: _regularFont),
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
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey));
    }
  }

  pw.Widget _buildCompactMatchingPairs(List<String> options) {
    try {
      int separatorIndex = options.indexOf('---SEPARATOR---');
      if (separatorIndex == -1) return pw.SizedBox.shrink();

      List<String> leftColumn = options.sublist(0, separatorIndex);
      List<String> rightColumn = options.sublist(separatorIndex + 1);

      return pw.Container(
        padding: const pw.EdgeInsets.all(4),
        margin: const pw.EdgeInsets.only(top: 2),
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
                    style: pw.TextStyle(fontSize: 6,
                        fontWeight: pw.FontWeight.bold,
                        font: _boldFont),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Text(
                    'Column B',
                    style: pw.TextStyle(fontSize: 6,
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
                                fontSize: 6, font: _regularFont),
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          child: pw.Text(
                            i < rightColumn.length ? '${String.fromCharCode(65 +
                                i)}. ${rightColumn[i]}' : '',
                            style: pw.TextStyle(
                                fontSize: 6, font: _regularFont),
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
          '[Error]', style: pw.TextStyle(fontSize: 6, color: PdfColors.grey));
    }
  }

  pw.Widget _buildSinglePageOptions(Question question) {
    return pw.Wrap(
      spacing: 10,
      runSpacing: 2,
      children: question.options!.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final optionLabel = String.fromCharCode(65 + index);

        return pw.Text(
          '$optionLabel) $option',
          style: pw.TextStyle(
            fontSize: 8,
            font: _regularFont,
          ),
        );
      }).toList(),
    );
  }

  pw.Widget _buildCompactHorizontalOptions(Question question) {
    return pw.Wrap(
      spacing: 8,
      runSpacing: 2,
      children: question.options!.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final optionLabel = String.fromCharCode(65 + index);

        return pw.Container(
          child: pw.Text(
            '$optionLabel) $option',
            style: pw.TextStyle(
              fontSize: 7,
              font: _regularFont,
            ),
          ),
        );
      }).toList(),
    );
  }

  List<pw.Widget> _buildSinglePageSubQuestions(List<SubQuestion> subQuestions) {
    final widgets = <pw.Widget>[];

    widgets.add(pw.SizedBox(height: 2));

    for (int i = 0; i < subQuestions.length; i++) {
      final subQuestion = subQuestions[i];
      final subLabel = String.fromCharCode(97 + i);

      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(left: 8, bottom: 1),
          child: pw.Text(
            '$subLabel) ${subQuestion.text}',
            style: pw.TextStyle(fontSize: 8, font: _regularFont),
          ),
        ),
      );
    }

    return widgets;
  }

  List<pw.Widget> _buildCompactSubQuestions(List<SubQuestion> subQuestions) {
    final widgets = <pw.Widget>[];

    widgets.add(pw.SizedBox(height: 2));

    for (int i = 0; i < subQuestions.length; i++) {
      final subQuestion = subQuestions[i];
      final subLabel = String.fromCharCode(97 + i);

      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(left: 6, bottom: 1),
          child: pw.Text(
            '$subLabel) ${subQuestion.text}',
            style: pw.TextStyle(fontSize: 7, font: _regularFont),
          ),
        ),
      );
    }

    return widgets;
  }

  // Answer sheet content with error recovery
  List<pw.Widget> _buildAnswerSheetContent(QuestionPaperEntity paper) {
    final widgets = <pw.Widget>[];
    int questionCounter = 1;
    final sortedSections = _getSortedSections(paper.questions);
    int sectionIndex = 1;

    for (final sectionEntry in sortedSections) {
      final sectionName = sectionEntry.key;
      final questions = sectionEntry.value;

      // SKIP EMPTY SECTIONS
      if (questions.isEmpty) continue;

      try {
        widgets.add(
          pw.Text(
            '${_getRomanNumeral(sectionIndex)}. $sectionName',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              font: _boldFont,
            ),
          ),
        );

        widgets.add(pw.SizedBox(height: 8));

        for (final question in questions) {
          try {
            widgets.add(_buildAnswerSheetQuestion(questionCounter, question));
            questionCounter++;
          } catch (e) {
            // Skip malformed questions in answer sheet
            widgets.add(
              pw.Text(
                'Q$questionCounter: [Question could not be displayed]',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
            );
            questionCounter++;
          }
        }

        widgets.add(pw.SizedBox(height: 15));
        sectionIndex++;
      } catch (e) {
        // Skip entire section if there's an error
        continue;
      }
    }

    return widgets;
  }

  pw.Widget _buildAnswerSheetQuestion(int questionNumber, Question question) {
    if (question.type == 'match_following' ||
        (question.options != null && question.options!.isNotEmpty &&
            question.type == 'multiple_choice')) {
      // MCQ answer format
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          children: [
            pw.Container(
              width: 40,
              child: pw.Text(
                  'Q$questionNumber:', style: pw.TextStyle(font: _regularFont)),
            ),
            pw.Expanded(
              child: pw.Row(
                children: question.type == 'match_following'
                    ? _buildMatchingAnswerBoxes()
                    : question.options!.asMap().entries.map((entry) {
                  final optionLabel = String.fromCharCode(65 + entry.key);
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(right: 20),
                    child: pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Container(
                          width: 12,
                          height: 12,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(),
                          ),
                        ),
                        pw.SizedBox(width: 4),
                        pw.Text(optionLabel,
                            style: pw.TextStyle(font: _regularFont)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    } else {
      // Written answer format
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 15),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
                'Q$questionNumber:', style: pw.TextStyle(font: _regularFont)),
            pw.SizedBox(height: 4),
            ...List.generate(
              3, // Fixed 3 lines for written answers
                  (index) =>
                  pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 6),
                    height: 1,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColors.grey400),
                      ),
                    ),
                  ),
            ),
          ],
        ),
      );
    }
  }

  List<pw.Widget> _buildMatchingAnswerBoxes() {
    return List.generate(5, (i) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(right: 15),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text('${i + 1}:', style: pw.TextStyle(fontSize: 10)),
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
      case 'true_false':
        return 'Write T for True or F for False:';
      case 'short_answers':
        return 'Answer the following questions:';
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
