// features/question_papers/domain2/services/pdf_generation_service.dart
import 'dart:typed_data';
import 'package:papercraft/features/question_papers/domain/constants/pdf_constants.dart';
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

  Future<Uint8List> generateTeacherPdf({
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

  // Font for Android compatibility
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

  @override
  Future<Uint8List> generateDualLayoutPdf({
    required QuestionPaperEntity paper,
    required String schoolName,
  }) async {
    await _loadFonts();
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(15),
        build: (context) {
          return pw.Row(
            children: [
              // Left paper
              pw.Expanded(
                child: pw.Container(
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
                          children: _buildCompactQuestions(paper), // This now has roman numerals
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              // Right paper (identical)
              pw.Expanded(
                child: pw.Container(
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
                          children: _buildCompactQuestions(paper), // This now has roman numerals
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

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
            pw.Text('Subject: ${paper.subject}', style: pw.TextStyle(fontSize: 9, font: _regularFont)),
            pw.Text('Grade: ${paper.gradeDisplayName}', style: pw.TextStyle(fontSize: 9, font: _regularFont)),
            if (paper.examTypeEntity.durationMinutes != null)
              pw.Text('Time: ${paper.examTypeEntity.formattedDuration}', style: pw.TextStyle(fontSize: 9, font: _regularFont)),
            pw.Text('Total Marks: ${paper.totalMarks}', style: pw.TextStyle(fontSize: 9, font: _regularFont)),
          ],
        ),

        // Student details in single line if provided
        if (studentName != null || rollNumber != null) ...[
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              pw.Text('Name: ___________________', style: pw.TextStyle(fontSize: 9, font: _regularFont)),
              pw.SizedBox(width: 20),
              pw.Text('Roll No: __________', style: pw.TextStyle(fontSize: 9, font: _regularFont)),
            ],
          ),
        ],

        pw.SizedBox(height: 4),
        pw.Divider(height: 1),
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

  List<pw.Widget> _buildCompactQuestionsForSinglePage(QuestionPaperEntity paper) {
    final widgets = <pw.Widget>[];
    final sortedSections = _getSortedSections(paper.questions);
    int sectionIndex = 1;

    for (final sectionEntry in sortedSections) {
      final sectionName = sectionEntry.key;
      final questions = sectionEntry.value;

      if (questions.isEmpty) continue;

      // Calculate section total marks
      final sectionMarks = questions.fold(0, (sum, q) => sum + q.totalMarks);
      final questionCount = questions.length;

      // Very compact section header
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

      widgets.add(pw.SizedBox(height: 3));

      // Compact questions
      for (int i = 0; i < questions.length; i++) {
        final question = questions[i];
        final questionNumber = i + 1;

        widgets.add(_buildSinglePageQuestion(
          question: question,
          questionNumber: questionNumber,
        ));

        if (i < questions.length - 1) {
          widgets.add(pw.SizedBox(height: 3));
        }
      }

      widgets.add(pw.SizedBox(height: 6));
      sectionIndex++;
    }

    return widgets;
  }

  pw.Widget _buildSinglePageQuestion({
    required Question question,
    required int questionNumber,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Question text
        pw.Text(
          '$questionNumber. ${question.text}',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.normal,
            font: _regularFont,
          ),
        ),

        pw.SizedBox(height: 2),

        // Question options (for MCQ) - Horizontal compact layout
        if (question.options != null && question.options!.isNotEmpty)
          _buildSinglePageOptions(question),

        // Sub-questions
        if (question.subQuestions.isNotEmpty)
          ..._buildSinglePageSubQuestions(question.subQuestions),
      ],
    );
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

  List<pw.Widget> _buildSinglePageSubQuestions(List<SubQuestion> subQuestions) {
    final widgets = <pw.Widget>[];

    for (int i = 0; i < subQuestions.length; i++) {
      final subQuestion = subQuestions[i];
      final subLabel = String.fromCharCode(97 + i);

      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(left: 10, bottom: 1),
          child: pw.Text(
            '$subLabel) ${subQuestion.text}',
            style: pw.TextStyle(fontSize: 8, font: _regularFont),
          ),
        ),
      );
    }

    return widgets;
  }

  // Add this method to the SimplePdfService class
  String _getRomanNumeral(int number) {
    switch (number) {
      case 1: return 'I';
      case 2: return 'II';
      case 3: return 'III';
      case 4: return 'IV';
      case 5: return 'V';
      case 6: return 'VI';
      case 7: return 'VII';
      case 8: return 'VIII';
      case 9: return 'IX';
      case 10: return 'X';
      case 11: return 'XI';
      case 12: return 'XII';
      case 13: return 'XIII';
      case 14: return 'XIV';
      case 15: return 'XV';
      default: return number.toString(); // Fallback to numbers for >15
    }
  }

  Future<void> _loadFonts() async {
    // Using system fonts that work well on Android
    _regularFont = pw.Font.helvetica();
    _boldFont = pw.Font.helveticaBold();
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

    pdf.addPage(
      pw.Page( // Changed from MultiPage to Page
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(15), // Reduced margin for more space
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header (only once)
              _buildCompactHeaderForSinglePage(
                schoolName: schoolName,
                paper: paper,
                studentName: studentName,
                rollNumber: rollNumber,
              ),
              pw.SizedBox(height: 6),
              _buildCompactInstructionsForSinglePage(),
              pw.SizedBox(height: 8),
              // Questions - fill remaining space
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

    return pdf.save();
  }

  @override
  Future<Uint8List> generateTeacherPdf({
    required QuestionPaperEntity paper,
    required String schoolName,
  }) async {
    await _loadFonts();
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (context) => _buildHeader(
          schoolName: schoolName,
          paper: paper,
          isTeacherCopy: true,
        ),
        build: (context) => [
          _buildTeacherInstructions(),
          pw.SizedBox(height: 10),
          ..._buildQuestions(paper, isTeacherCopy: true),
        ],
      ),
    );

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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (context) => _buildAnswerSheetHeader(
          schoolName: schoolName,
          paper: paper,
          studentName: studentName,
          rollNumber: rollNumber,
        ),
        build: (context) => [
          _buildAnswerSheetInstructions(),
          pw.SizedBox(height: 10),
          ..._buildAnswerSheetContent(paper),
        ],
      ),
    );

    return pdf.save();
  }

  // Helper method to sort sections in ascending order
  List<MapEntry<String, List<Question>>> _getSortedSections(Map<String, List<Question>> questions) {
    final entries = questions.entries.toList();

    // Sort sections by their key (Section A, Section B, etc.)
    entries.sort((a, b) {
      final sectionA = a.key.toLowerCase();
      final sectionB = b.key.toLowerCase();

      // Extract section identifier (A, B, C, etc.)
      final regexA = RegExp(r'section\s*([a-z])', caseSensitive: false);
      final regexB = RegExp(r'section\s*([a-z])', caseSensitive: false);

      final matchA = regexA.firstMatch(sectionA);
      final matchB = regexB.firstMatch(sectionB);

      if (matchA != null && matchB != null) {
        final letterA = matchA.group(1)!;
        final letterB = matchB.group(1)!;
        return letterA.compareTo(letterB);
      }

      // If no section letters found, sort alphabetically
      return sectionA.compareTo(sectionB);
    });

    return entries;
  }

  // Header components
  pw.Widget _buildHeader({
    required String schoolName,
    required QuestionPaperEntity paper,
    String? studentName,
    String? rollNumber,
    bool isTeacherCopy = false,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // School name
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

        // Paper title
        pw.Center(
          child: pw.Text(
            paper.title,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              font: _boldFont,
            ),
          ),
        ),
        pw.SizedBox(height: 6),

        // Paper details row
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Subject: ${paper.subject}', style: pw.TextStyle(font: _regularFont)),
                pw.Text('Grade: ${paper.gradeDisplayName}', style: pw.TextStyle(font: _regularFont)),
                if (paper.examTypeEntity.durationMinutes != null)
                  pw.Text('Time: ${paper.examTypeEntity.formattedDuration}', style: pw.TextStyle(font: _regularFont)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Total Marks: ${paper.totalMarks}', style: pw.TextStyle(font: _regularFont)),
                if (isTeacherCopy)
                  pw.Text(
                    'TEACHER COPY',
                    style: pw.TextStyle(
                      color: PdfColor.fromHex('#d32f2f'),
                      fontWeight: pw.FontWeight.bold,
                      font: _boldFont,
                    ),
                  ),
              ],
            ),
          ],
        ),

        // Student details (if provided)
        if (studentName != null || rollNumber != null) ...[
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (studentName != null)
                pw.Text('Name: _________________________', style: pw.TextStyle(font: _regularFont)),
              if (rollNumber != null)
                pw.Text('Roll No: ___________', style: pw.TextStyle(font: _regularFont)),
            ],
          ),
        ],

        pw.SizedBox(height: 10),
        pw.Divider(),
        pw.SizedBox(height: 8),
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
            pw.Text('Marks: ${paper.totalMarks}',
                style: pw.TextStyle(fontSize: 8, font: _regularFont)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text('Name: _________________  Roll No: ______',
            style: pw.TextStyle(fontSize: 8, font: _regularFont)),
        pw.SizedBox(height: 4),
        pw.Divider(),
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
        pw.Text('Paper: ${paper.title}', style: pw.TextStyle(font: _regularFont)),
        pw.SizedBox(height: 8),
        pw.Divider(),
      ],
    );
  }

  // Instructions
  pw.Widget _buildInstructions() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        'Instructions: Read all questions carefully. Answer all questions.',
        style: pw.TextStyle(fontSize: 10, font: _regularFont),
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

  pw.Widget _buildTeacherInstructions() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('#d32f2f')),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'TEACHER COPY - Correct answers are highlighted',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColor.fromHex('#d32f2f'),
              fontWeight: pw.FontWeight.bold,
              font: _boldFont,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Instructions: Read all questions carefully. Answer all questions.',
            style: pw.TextStyle(fontSize: 10, font: _regularFont),
          ),
        ],
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

  // Question building with memory management and batching
  // Question building with memory management and batching
  List<pw.Widget> _buildQuestions(QuestionPaperEntity paper, {bool isTeacherCopy = false}) {
    final widgets = <pw.Widget>[];
    final sortedSections = _getSortedSections(paper.questions);

    // Add section counter for roman numerals
    int sectionIndex = 1;

    for (final sectionEntry in sortedSections) {
      final sectionName = sectionEntry.key;
      final questions = sectionEntry.value;

      if (questions.isEmpty) continue;

      // Calculate section total marks
      final sectionMarks = questions.fold(0, (sum, q) => sum + q.totalMarks);
      final questionCount = questions.length;

      // Professional section header with roman numerals
      widgets.add(
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${_getRomanNumeral(sectionIndex)}. $sectionName', // Add roman numeral
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  font: _boldFont,
                ),
              ),
              pw.Text(
                '$questionCount × ${sectionMarks ~/ questionCount} = $sectionMarks marks',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  font: _boldFont,
                ),
              ),
            ],
          ),
        ),
      );

      widgets.add(pw.SizedBox(height: 6));

      // ... rest of the existing question processing logic remains the same ...
      for (int batchStart = 0; batchStart < questions.length; batchStart += MAX_QUESTIONS_PER_BATCH) {
        final batchEnd = (batchStart + MAX_QUESTIONS_PER_BATCH).clamp(0, questions.length);
        final batch = questions.sublist(batchStart, batchEnd);

        for (int i = 0; i < batch.length; i++) {
          final question = batch[i];
          final questionNumber = batchStart + i + 1;

          widgets.add(_buildSingleQuestion(
            question: question,
            questionNumber: questionNumber,
            isTeacherCopy: isTeacherCopy,
          ));

          if (batchStart + i < questions.length - 1) {
            widgets.add(pw.SizedBox(height: 6));
          }
        }

        if (batchEnd < questions.length && questions.length > MAX_QUESTIONS_PER_BATCH * 2) {
          Future.delayed(const Duration(milliseconds: 1));
        }
      }

      widgets.add(pw.SizedBox(height: 10));

      // Increment section counter
      sectionIndex++;
    }

    return widgets;
  }

  List<pw.Widget> _buildCompactQuestions(QuestionPaperEntity paper) {
    final widgets = <pw.Widget>[];
    final sortedSections = _getSortedSections(paper.questions);

    // Add section counter for roman numerals
    int sectionIndex = 1;

    for (final sectionEntry in sortedSections) {
      final sectionName = sectionEntry.key;
      final questions = sectionEntry.value;

      if (questions.isEmpty) continue;

      // Calculate section total marks
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
                '${_getRomanNumeral(sectionIndex)}. $sectionName', // Add roman numeral
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  font: _boldFont,
                ),
              ),
              pw.Text(
                '$questionCount × ${sectionMarks ~/ questionCount} = $sectionMarks marks',
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

      // ... rest of the existing compact question processing logic remains the same ...
      for (int batchStart = 0; batchStart < questions.length; batchStart += MAX_QUESTIONS_PER_BATCH) {
        final batchEnd = (batchStart + MAX_QUESTIONS_PER_BATCH).clamp(0, questions.length);
        final batch = questions.sublist(batchStart, batchEnd);

        for (int i = 0; i < batch.length; i++) {
          final question = batch[i];
          final questionNumber = batchStart + i + 1;

          widgets.add(_buildCompactSingleQuestion(
            question: question,
            questionNumber: questionNumber,
          ));

          if (batchStart + i < questions.length - 1) {
            widgets.add(pw.SizedBox(height: 4));
          }
        }
      }

      widgets.add(pw.SizedBox(height: 6));

      // Increment section counter
      sectionIndex++;
    }

    return widgets;
  }

  pw.Widget _buildSingleQuestion({
    required Question question,
    required int questionNumber,
    required bool isTeacherCopy,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Question text
        pw.Text(
          '$questionNumber. ${question.text}',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.normal,
            font: _regularFont,
          ),
        ),

        pw.SizedBox(height: 4),

        // Question options (for MCQ) - Horizontal layout
        if (question.options != null && question.options!.isNotEmpty)
          _buildHorizontalOptions(question, isTeacherCopy),

        // Sub-questions
        if (question.subQuestions.isNotEmpty)
          ..._buildSubQuestions(question.subQuestions),
      ],
    );
  }

  pw.Widget _buildCompactSingleQuestion({
    required Question question,
    required int questionNumber,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Question text
        pw.Text(
          '$questionNumber. ${question.text}',
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.normal,
            font: _regularFont,
          ),
        ),

        pw.SizedBox(height: 2),

        // Question options (for MCQ) - Horizontal layout
        if (question.options != null && question.options!.isNotEmpty)
          _buildCompactHorizontalOptions(question),

        // Sub-questions
        if (question.subQuestions.isNotEmpty)
          ..._buildCompactSubQuestions(question.subQuestions),
      ],
    );
  }

  pw.Widget _buildHorizontalOptions(Question question, bool isTeacherCopy) {
    return pw.Wrap(
      spacing: 15,
      runSpacing: 4,
      children: question.options!.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final optionLabel = String.fromCharCode(65 + index); // A, B, C, D
        final isCorrect = isTeacherCopy && question.correctAnswer == option;

        return pw.Container(
          child: pw.Text(
            '$optionLabel) $option',
            style: pw.TextStyle(
              fontSize: 10,
              color: isCorrect ? PdfColor.fromHex('#d32f2f') : null,
              fontWeight: isCorrect ? pw.FontWeight.bold : pw.FontWeight.normal,
              font: isCorrect ? _boldFont : _regularFont,
            ),
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
        final optionLabel = String.fromCharCode(65 + index); // A, B, C, D

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

  List<pw.Widget> _buildSubQuestions(List<SubQuestion> subQuestions) {
    final widgets = <pw.Widget>[];

    widgets.add(pw.SizedBox(height: 4));

    for (int i = 0; i < subQuestions.length; i++) {
      final subQuestion = subQuestions[i];
      final subLabel = String.fromCharCode(97 + i); // a, b, c...

      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(left: 15, bottom: 3),
          child: pw.Text(
            '$subLabel) ${subQuestion.text}',
            style: pw.TextStyle(fontSize: 10, font: _regularFont),
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
      final subLabel = String.fromCharCode(97 + i); // a, b, c...

      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(left: 8, bottom: 1),
          child: pw.Text(
            '$subLabel) ${subQuestion.text}',
            style: pw.TextStyle(fontSize: 7, font: _regularFont),
          ),
        ),
      );
    }

    return widgets;
  }

  // Answer sheet content with memory management and sorted sections
  List<pw.Widget> _buildAnswerSheetContent(QuestionPaperEntity paper) {
    final widgets = <pw.Widget>[];
    int questionCounter = 1;
    final sortedSections = _getSortedSections(paper.questions);

    // Add section counter for roman numerals
    int sectionIndex = 1;

    for (final sectionEntry in sortedSections) {
      final sectionName = sectionEntry.key;
      final questions = sectionEntry.value;

      if (questions.isEmpty) continue;

      widgets.add(
        pw.Text(
          '${_getRomanNumeral(sectionIndex)}. $sectionName', // Add roman numeral
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            font: _boldFont,
          ),
        ),
      );

      widgets.add(pw.SizedBox(height: 8));

      // ... rest of the existing answer sheet logic remains the same ...
      for (int batchStart = 0; batchStart < questions.length; batchStart += MAX_QUESTIONS_PER_BATCH) {
        final batchEnd = (batchStart + MAX_QUESTIONS_PER_BATCH).clamp(0, questions.length);
        final batch = questions.sublist(batchStart, batchEnd);

        for (final question in batch) {
          widgets.add(_buildAnswerSheetQuestion(questionCounter, question));
          questionCounter++;
        }
      }

      widgets.add(pw.SizedBox(height: 15));

      // Increment section counter
      sectionIndex++;
    }

    return widgets;
  }

  pw.Widget _buildAnswerSheetQuestion(int questionNumber, Question question) {
    if (question.options != null && question.options!.isNotEmpty) {
      // MCQ answer format
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          children: [
            pw.Container(
              width: 40,
              child: pw.Text('Q$questionNumber:', style: pw.TextStyle(font: _regularFont)),
            ),
            pw.Expanded(
              child: pw.Row(
                children: question.options!.asMap().entries.map((entry) {
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
                        pw.Text(optionLabel, style: pw.TextStyle(font: _regularFont)),
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
            pw.Text('Q$questionNumber:', style: pw.TextStyle(font: _regularFont)),
            pw.SizedBox(height: 4),
            ...List.generate(
              3, // Fixed 3 lines for written answers
                  (index) => pw.Container(
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
}