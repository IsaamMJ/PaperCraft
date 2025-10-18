// features/pdf_generation/domain/services/pdf_generation_service_new.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/domain/errors/failures.dart';
import '../../../../core/infrastructure/config/app_config.dart';
import '../../../../core/infrastructure/rate_limiter/rate_limiter.dart';
import '../../../paper_workflow/domain/entities/question_entity.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';

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
}

class SimplePdfService implements IPdfGenerationService {
  // Mobile-compatible fonts - using built-in fonts only
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

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

    // Spacing based on compress mode and user multiplier
    final double questionSpacing = (compressed ? 6 : 12) * spacingMultiplier;
    final double sectionSpacing = (compressed ? 12 : 20) * spacingMultiplier;
    final double headerSpacing = (compressed ? 8 : 16) * spacingMultiplier;

    try {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(compressed ? 12 : 20),
          build: (context) {
            final widgets = <pw.Widget>[];

            // Header
            widgets.add(_buildHeader(
              schoolName: schoolName,
              paper: paper,
              studentName: studentName,
              rollNumber: rollNumber,
              compressed: compressed,
              fontSizeMultiplier: fontSizeMultiplier,
            ));
            widgets.add(pw.SizedBox(height: headerSpacing));

            // Instructions
            if (!compressed) {
              widgets.add(pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'Instructions: Read all questions carefully. Write your answers clearly in the space provided.',
                  style: pw.TextStyle(fontSize: 9 * fontSizeMultiplier, color: PdfColors.grey700),
                ),
              ));
              widgets.add(pw.SizedBox(height: 12));
            }

            // Questions by section
            for (final section in paper.paperSections) {
              final sectionQuestions = paper.questions[section.name] ?? [];
              if (sectionQuestions.isNotEmpty) {
                widgets.add(_buildSectionHeader(section.name, compressed, fontSizeMultiplier));
                widgets.add(pw.SizedBox(height: sectionSpacing));

                int questionNumber = 1;
                for (final question in sectionQuestions) {
                  widgets.add(_buildQuestion(
                    question: question,
                    questionNumber: questionNumber++,
                    compressed: compressed,
                    fontSizeMultiplier: fontSizeMultiplier,
                  ));
                  widgets.add(pw.SizedBox(height: questionSpacing));
                }

                widgets.add(pw.SizedBox(height: sectionSpacing));
              }
            }

            return widgets;
          },
        ),
      );

      return pdf.save();
    } catch (e) {
      throw ValidationFailure('Failed to generate PDF: ${e.toString()}');
    }
  }

  Future<void> _loadFonts() async {
    // Using default fonts - no custom fonts needed
    _regularFont = pw.Font.helvetica();
    _boldFont = pw.Font.helveticaBold();
  }

  pw.Widget _buildHeader({
    required String schoolName,
    required QuestionPaperEntity paper,
    String? studentName,
    String? rollNumber,
    required bool compressed,
    required double fontSizeMultiplier,
  }) {
    final titleSize = (compressed ? 16.0 : 22.0) * fontSizeMultiplier;
    final subtitleSize = (compressed ? 11.0 : 15.0) * fontSizeMultiplier;
    final infoSize = (compressed ? 9.0 : 11.0) * fontSizeMultiplier;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // School name - centered, uppercase
        pw.Text(
          schoolName.toUpperCase(),
          style: pw.TextStyle(fontSize: titleSize, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: compressed ? 4 : 6),

        // Exam title - use pdfTitle, centered
        pw.Text(
          paper.pdfTitle,
          style: pw.TextStyle(fontSize: subtitleSize, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: compressed ? 6 : 8),

        // Decorative divider
        pw.Container(
          width: 100,
          height: 2,
          color: PdfColors.grey800,
        ),
        pw.SizedBox(height: compressed ? 6 : 10),

        // Info row
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (paper.gradeNumber != null)
                  pw.Text('Class: ${paper.gradeNumber}', style: pw.TextStyle(fontSize: infoSize))
                else if (paper.gradeDisplayName != null)
                  pw.Text('Class: ${paper.gradeDisplayName.replaceAll('Grade ', '')}', style: pw.TextStyle(fontSize: infoSize)),
                if (paper.subject != null)
                  pw.Text('Subject: ${paper.subject}', style: pw.TextStyle(fontSize: infoSize)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Total Marks: ${paper.totalMarks}', style: pw.TextStyle(fontSize: infoSize)),
                pw.Text('Questions: ${paper.totalQuestions}', style: pw.TextStyle(fontSize: infoSize)),
              ],
            ),
          ],
        ),
        if (studentName != null || rollNumber != null) ...[
          pw.SizedBox(height: compressed ? 6 : 8),
          pw.Row(
            children: [
              if (studentName != null)
                pw.Text('Name: $studentName', style: pw.TextStyle(fontSize: infoSize)),
              pw.Spacer(),
              if (rollNumber != null)
                pw.Text('Roll No: $rollNumber', style: pw.TextStyle(fontSize: infoSize)),
            ],
          ),
        ],
        pw.Divider(thickness: compressed ? 1 : 1.5),
      ],
    );
  }

  pw.Widget _buildSectionHeader(String sectionName, bool compressed, double fontSizeMultiplier) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(compressed ? 8 : 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey800,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        sectionName.toUpperCase(),
        style: pw.TextStyle(
          fontSize: (compressed ? 12 : 14) * fontSizeMultiplier,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  pw.Widget _buildQuestion({
    required Question question,
    required int questionNumber,
    required bool compressed,
    required double fontSizeMultiplier,
  }) {
    final questionNumSize = (compressed ? 11.0 : 13.0) * fontSizeMultiplier;
    final questionSize = (compressed ? 10.0 : 12.0) * fontSizeMultiplier;
    final optionSize = (compressed ? 9.0 : 10.0) * fontSizeMultiplier;

    final widgets = <pw.Widget>[];

    // Question text
    widgets.add(
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '$questionNumber. ',
            style: pw.TextStyle(fontSize: questionNumSize, fontWeight: pw.FontWeight.bold),
          ),
          pw.Expanded(
            child: pw.Text(
              question.text,
              style: pw.TextStyle(fontSize: questionSize),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(
              '[${question.marks} mark${question.marks > 1 ? 's' : ''}]',
              style: pw.TextStyle(fontSize: (compressed ? 7 : 8) * fontSizeMultiplier),
            ),
          ),
        ],
      ),
    );

    // Options for MCQ
    if (question.type == 'multiple_choice' && question.options != null) {
      widgets.add(pw.SizedBox(height: compressed ? 3 : 5));
      for (int i = 0; i < question.options!.length; i++) {
        widgets.add(
          pw.Padding(
            padding: pw.EdgeInsets.only(left: 16, top: compressed ? 2 : 3),
            child: pw.Text(
              '${String.fromCharCode(97 + i)}) ${question.options![i]}',
              style: pw.TextStyle(fontSize: optionSize),
            ),
          ),
        );
      }
    }

    // Sub-questions
    if (question.subQuestions.isNotEmpty) {
      widgets.add(pw.SizedBox(height: compressed ? 3 : 5));
      for (int i = 0; i < question.subQuestions.length; i++) {
        final subQ = question.subQuestions[i];
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 16, top: 2),
            child: pw.Text(
              '  ${String.fromCharCode(97 + i)}) ${subQ.text}',
              style: pw.TextStyle(fontSize: optionSize),
            ),
          ),
        );
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: widgets,
    );
  }
}
