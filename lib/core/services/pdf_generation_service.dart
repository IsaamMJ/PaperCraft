// lib/core/services/pdf_generation_service.dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../features/question_papers/domain/entities/question_paper_entity.dart';
import '../../features/question_papers/domain/entities/question_entity.dart';

class SimplePdfService {
  static Future<Uint8List> generateStudentPdf({
    required QuestionPaperEntity paper,
    String? schoolName,
  }) async {
    print('Starting Student PDF generation for: ${paper.title}');

    final pdf = pw.Document();

    // Build all questions first
    final allQuestions = _buildAllQuestions(paper, includeAnswers: false);

    // Split questions into pages (roughly 10 questions per page)
    const questionsPerPage = 10;
    final totalQuestions = allQuestions.length;
    final totalPages = (totalQuestions / questionsPerPage).ceil().clamp(1, 10);

    print('Total questions: $totalQuestions, splitting into $totalPages pages');

    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final startIndex = pageIndex * questionsPerPage;
      final endIndex = (startIndex + questionsPerPage).clamp(0, totalQuestions);
      final pageQuestions = allQuestions.sublist(startIndex, endIndex);

      print('Page ${pageIndex + 1}: questions $startIndex to ${endIndex - 1}');

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header on every page
                _buildSimpleHeader(paper, schoolName, pageIndex + 1, totalPages, isTeacherCopy: false),

                pw.SizedBox(height: 20),

                // Instructions only on first page
                if (pageIndex == 0) ...[
                  _buildSimpleInstructions(paper),
                  pw.SizedBox(height: 20),
                ],

                // Questions for this page
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: pageQuestions,
                  ),
                ),

                // Footer
                _buildFooter(paper, pageIndex + 1, totalPages, 'STUDENT'),
              ],
            );
          },
        ),
      );
    }

    print('Student PDF generation completed with $totalPages pages');
    return pdf.save();
  }

  static Future<Uint8List> generateTeacherPdf({
    required QuestionPaperEntity paper,
    String? schoolName,
  }) async {
    print('Starting Teacher PDF generation for: ${paper.title}');

    final pdf = pw.Document();

    // Build all questions for student section (without answers)
    final allQuestions = _buildAllQuestions(paper, includeAnswers: false);

    // Split questions into pages for student section
    const questionsPerPage = 10;
    final totalQuestions = allQuestions.length;
    final studentPages = (totalQuestions / questionsPerPage).ceil().clamp(1, 10);
    final totalPages = studentPages + 1; // +1 for answer key page

    print('Total questions: $totalQuestions, student pages: $studentPages, total pages: $totalPages');

    // Add student copy pages first
    for (int pageIndex = 0; pageIndex < studentPages; pageIndex++) {
      final startIndex = pageIndex * questionsPerPage;
      final endIndex = (startIndex + questionsPerPage).clamp(0, totalQuestions);
      final pageQuestions = allQuestions.sublist(startIndex, endIndex);

      print('Student page ${pageIndex + 1}: questions $startIndex to ${endIndex - 1}');

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildSimpleHeader(paper, schoolName, pageIndex + 1, totalPages, isTeacherCopy: true),
                pw.SizedBox(height: 20),

                if (pageIndex == 0) ...[
                  _buildSimpleInstructions(paper),
                  pw.SizedBox(height: 20),
                ],

                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: pageQuestions,
                  ),
                ),

                _buildFooter(paper, pageIndex + 1, totalPages, 'TEACHER'),
              ],
            );
          },
        ),
      );
    }

    // Add answer key page
    print('Adding answer key page');
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildAnswerKeyHeader(paper, schoolName, totalPages, totalPages),
              pw.SizedBox(height: 30),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: _buildAnswerKey(paper),
                ),
              ),
              _buildFooter(paper, totalPages, totalPages, 'TEACHER - ANSWER KEY'),
            ],
          );
        },
      ),
    );

    print('Teacher PDF generation completed with $totalPages pages (including answer key)');
    return pdf.save();
  }

  static pw.Widget _buildSimpleHeader(QuestionPaperEntity paper, String? schoolName, int pageNumber, int totalPages, {required bool isTeacherCopy}) {
    return pw.Center(
      child: pw.Column(
        children: [
          if (schoolName != null)
            pw.Text(schoolName, style: const pw.TextStyle(fontSize: 18)),
          pw.SizedBox(height: 10),
          pw.Text(paper.title, style: const pw.TextStyle(fontSize: 16)),
          pw.SizedBox(height: 5),
          pw.Text('Subject: ${paper.subject} | Total Marks: ${paper.totalMarks}'),
          pw.Text('Page $pageNumber of $totalPages', style: const pw.TextStyle(fontSize: 10)),

          // Teacher copy indicator
          if (isTeacherCopy) ...[
            pw.SizedBox(height: 5),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                color: PdfColors.orange300,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(color: PdfColors.orange600),
              ),
              child: pw.Text(
                'TEACHER COPY - NOT FOR DISTRIBUTION',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
          ],

          pw.Container(height: 2, width: double.infinity, color: PdfColors.black),
        ],
      ),
    );
  }

  static pw.Widget _buildAnswerKeyHeader(QuestionPaperEntity paper, String? schoolName, int pageNumber, int totalPages) {
    return pw.Center(
      child: pw.Column(
        children: [
          if (schoolName != null)
            pw.Text(schoolName, style: const pw.TextStyle(fontSize: 18)),
          pw.SizedBox(height: 10),
          pw.Text('ANSWER KEY', style: const pw.TextStyle(fontSize: 20)),
          pw.SizedBox(height: 5),
          pw.Text(paper.title, style: const pw.TextStyle(fontSize: 16)),
          pw.SizedBox(height: 5),
          pw.Text('Subject: ${paper.subject} | Exam Type: ${paper.examType}'),
          pw.Text('Page $pageNumber of $totalPages', style: const pw.TextStyle(fontSize: 10)),

          pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 10),
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: PdfColors.red300,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              border: pw.Border.all(color: PdfColors.red600),
            ),
            child: pw.Text(
              'CONFIDENTIAL - FOR TEACHERS ONLY',
              style: const pw.TextStyle(fontSize: 12),
            ),
          ),

          pw.Container(height: 2, width: double.infinity, color: PdfColors.black),
        ],
      ),
    );
  }

  static pw.Widget _buildSimpleInstructions(QuestionPaperEntity paper) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('INSTRUCTIONS:', style: const pw.TextStyle()),
          pw.SizedBox(height: 5),
          pw.Text('1. Read all questions carefully'),
          pw.Text('2. Answer all questions'),
          pw.Text('3. Use black or blue pen only'),
          pw.Text('4. Duration: ${paper.examTypeEntity.formattedDuration}'),
        ],
      ),
    );
  }

  static List<pw.Widget> _buildAllQuestions(QuestionPaperEntity paper, {required bool includeAnswers}) {
    final widgets = <pw.Widget>[];
    int questionNumber = 1;

    print('Building questions for ${paper.examTypeEntity.sections.length} sections (include answers: $includeAnswers)');

    for (final section in paper.examTypeEntity.sections) {
      final questions = paper.questions[section.name] ?? [];
      print('Section: ${section.name} has ${questions.length} questions');

      if (questions.isEmpty) {
        print('Skipping empty section: ${section.name}');
        continue;
      }

      // Section header
      widgets.add(
        pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(top: 10, bottom: 10),
          padding: const pw.EdgeInsets.all(8),
          color: PdfColors.grey300,
          child: pw.Text(section.name, style: const pw.TextStyle()),
        ),
      );

      // Questions in this section
      for (int i = 0; i < questions.length; i++) {
        final question = questions[i];
        print('Building question $questionNumber (${i+1}/${questions.length})');

        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 15),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Question text
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 30,
                      child: pw.Text('$questionNumber.', style: const pw.TextStyle()),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(question.text),
                          pw.SizedBox(height: 3),
                          pw.Text('[${question.marks} marks]', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 8),

                // Options for MCQ or answer lines for subjective
                if (question.options != null && question.options!.isNotEmpty) ...[
                  pw.Container(
                    margin: const pw.EdgeInsets.only(left: 30),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: question.options!.asMap().entries.map((entry) {
                        final optionIndex = entry.key;
                        final option = entry.value;
                        final isCorrect = includeAnswers && question.correctAnswer == option;

                        return pw.Container(
                          margin: const pw.EdgeInsets.only(bottom: 3),
                          decoration: isCorrect ? pw.BoxDecoration(
                            color: PdfColors.green100,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                          ) : null,
                          padding: isCorrect ? const pw.EdgeInsets.all(2) : null,
                          child: pw.Row(
                            children: [
                              pw.Expanded(
                                child: pw.Text('${String.fromCharCode(65 + optionIndex)}) $option'),
                              ),
                              if (isCorrect)
                                pw.Text(' (CORRECT)', style: const pw.TextStyle(fontSize: 10)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ] else ...[
                  // Answer lines for subjective questions
                  pw.Container(
                    margin: const pw.EdgeInsets.only(left: 30),
                    child: pw.Column(
                      children: List.generate(
                        3,
                            (index) => pw.Container(
                          margin: const pw.EdgeInsets.only(bottom: 6),
                          child: pw.Row(
                            children: [
                              pw.Expanded(
                                child: pw.Container(
                                  height: 1,
                                  decoration: const pw.BoxDecoration(
                                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );

        print('Successfully added question $questionNumber');
        questionNumber++;
      }

      print('Completed section: ${section.name}');
    }

    print('Total questions processed: ${questionNumber - 1}');
    print('Total widgets created: ${widgets.length}');
    return widgets;
  }

  static List<pw.Widget> _buildAnswerKey(QuestionPaperEntity paper) {
    final widgets = <pw.Widget>[];
    int questionNumber = 1;

    print('Building answer key');

    for (final section in paper.examTypeEntity.sections) {
      final questions = paper.questions[section.name] ?? [];

      if (questions.isEmpty) continue;

      // Section header
      widgets.add(
        pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(top: 15, bottom: 10),
          padding: const pw.EdgeInsets.all(8),
          color: PdfColors.blue100,
          child: pw.Text(
            section.name,
            style: const pw.TextStyle(fontSize: 14),
          ),
        ),
      );

      // Create a grid layout for answers
      final answerRows = <List<pw.Widget>>[];
      List<pw.Widget> currentRow = [];

      for (int i = 0; i < questions.length; i++) {
        final question = questions[i];
        String answerText;

        if (question.options != null && question.correctAnswer != null) {
          // MCQ - show the correct answer
          answerText = question.correctAnswer!;
        } else {
          // Subjective - indicate it's a subjective answer
          answerText = '[Subjective Answer]';
        }

        currentRow.add(
          pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.all(2),
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Text(
                'Q$questionNumber: $answerText',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
          ),
        );

        questionNumber++;

        // Create rows of 3 answers each
        if (currentRow.length == 3 || i == questions.length - 1) {
          // Fill remaining slots in the row if needed
          while (currentRow.length < 3) {
            currentRow.add(pw.Expanded(child: pw.Container()));
          }
          answerRows.add(List.from(currentRow));
          currentRow.clear();
        }
      }

      // Add all answer rows for this section
      for (final row in answerRows) {
        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(children: row),
          ),
        );
      }
    }

    // Add marking guidelines
    widgets.add(
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 20),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.amber50,
          border: pw.Border.all(color: PdfColors.amber300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'MARKING GUIDELINES:',
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 5),
            pw.Text('1. MCQ questions: Award full marks for correct answer only', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('2. Subjective questions: Award marks based on content quality', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('3. Partial marks may be awarded for partial understanding', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('4. No negative marking unless specified otherwise', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );

    print('Answer key building completed');
    return widgets;
  }

  static pw.Widget _buildFooter(QuestionPaperEntity paper, int pageNumber, int totalPages, String copyType) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide()),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Paper ID: ${paper.id.substring(0, 8)}', style: const pw.TextStyle(fontSize: 8)),
          pw.Text(copyType, style: const pw.TextStyle(fontSize: 8)),
          pw.Text('Generated: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }
}