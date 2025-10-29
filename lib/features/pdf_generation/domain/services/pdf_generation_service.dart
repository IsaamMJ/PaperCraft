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
import '../../../catalog/domain/entities/paper_section_entity.dart';

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
  static const int MAX_QUESTIONS_PER_BATCH = 20;
  static const int MAX_QUESTIONS_PER_PAGE = 10;

  static const double PAGE_HEIGHT = 842;
  static const double PAGE_MARGIN = 15;
  static const double USABLE_PAGE_HEIGHT = PAGE_HEIGHT - (PAGE_MARGIN * 2);
  static const double HEADER_HEIGHT = 80;

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
    if (!RateLimiters.pdfGeneration.canProceed('pdf_gen_${paper.id}')) {
      final waitTime = RateLimiters.pdfGeneration.getWaitTime('pdf_gen_${paper.id}');
      throw ValidationFailure(
          'Too many PDF requests. Please wait ${waitTime.inSeconds} seconds before trying again.'
      );
    }

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
      final sortedSections = _getSortedSections(paper.questions, paper.paperSections);

      List<pw.Widget> allQuestionWidgets = [];
      int sectionIndex = 1;

      for (final sectionEntry in sortedSections) {
        final sectionName = sectionEntry.key;
        final questions = sectionEntry.value;

        if (questions.isEmpty) continue;

        try {
          // Calculate marks excluding optional questions
          final nonOptionalQuestions = questions.where((q) => !(q.isOptional ?? false)).toList();
          final sectionMarks = nonOptionalQuestions.fold(0.0, (sum, q) => sum + q.totalMarks);
          final questionCount = nonOptionalQuestions.length;

          final isFillBlanksSection = questions.first.type == 'fill_in_blanks' || questions.first.type == 'fill_blanks';

          String sectionHeaderText = '${_getRomanNumeral(sectionIndex)}. $sectionName';

          allQuestionWidgets.add(
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
                    questionCount > 0
                        ? '$questionCount × ${(sectionMarks / questionCount).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')} = ${sectionMarks.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')} marks'
                        : '${sectionMarks.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')} marks',
                    style: pw.TextStyle(
                      fontSize: UIConstants.fontSizeSmall * fontSizeMultiplier,
                      fontWeight: pw.FontWeight.bold,
                      font: _boldFont,
                    ),
                  ),
                ],
              ),
            ),
          );

          allQuestionWidgets.add(pw.SizedBox(height: 4 * spacingMultiplier));

          if (isFillBlanksSection) {
            allQuestionWidgets.addAll(_buildSharedWordBankWidgetForSinglePage(questions, fontSizeMultiplier, spacingMultiplier));
          }

          final commonInstruction = _getCommonInstruction(questions.first.type);
          if (commonInstruction.isNotEmpty) {
            allQuestionWidgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(2),
                margin: pw.EdgeInsets.only(bottom: 6 * spacingMultiplier),
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

          if (questions.isNotEmpty && questions.first.type == 'word_forms') {
            final itemsText = questions.asMap().entries.map((entry) {
              final index = entry.key;
              final question = entry.value;
              final itemLabel = String.fromCharCode(97 + index);
              return '$itemLabel) ${question.text}';
            }).join('  ');

            allQuestionWidgets.add(
              pw.Text(
                itemsText,
                style: pw.TextStyle(
                  fontSize: 11 * fontSizeMultiplier,
                  fontWeight: pw.FontWeight.normal,
                  font: _regularFont,
                ),
                maxLines: 3,
                textAlign: pw.TextAlign.left,
              ),
            );
          } else {
            for (int i = 0; i < questions.length; i++) {
              final question = questions[i];
              final questionNumber = i + 1;

              try {
                allQuestionWidgets.add(_buildSinglePageQuestion(
                  question: question,
                  questionNumber: questionNumber,
                  showCommonText: commonInstruction.isEmpty,
                  fontSizeMultiplier: fontSizeMultiplier,
                  hideOptions: isFillBlanksSection,
                ));

                if (i < questions.length - 1) {
                  allQuestionWidgets.add(pw.SizedBox(height: 6 * spacingMultiplier));
                }
              } catch (e) {
                allQuestionWidgets.add(
                  pw.Text(
                    '$questionNumber. [Question could not be displayed]',
                    style: pw.TextStyle(fontSize: 9 * fontSizeMultiplier, color: PdfColors.grey),
                  ),
                );
              }
            }
          }

          allQuestionWidgets.add(pw.SizedBox(height: 12 * spacingMultiplier));
          sectionIndex++;
        } catch (e) {
          allQuestionWidgets.add(
            pw.Text(
              'Section error',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey),
            ),
          );
        }
      }

      final pages = _paginateContent(
        allQuestionWidgets,
        schoolName,
        paper,
        studentName,
        rollNumber,
        fontSizeMultiplier,
        spacingMultiplier,
      );

      // Check if single page and duplicate if needed
      final isSinglePage = pages.length == 1;

      for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
        final isFirstPage = pageIndex == 0;
        final pageContent = pages[pageIndex];

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(15),
            build: (context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (isFirstPage)
                    pw.Column(
                      children: [
                        _buildCompactHeaderForSinglePage(
                          schoolName: schoolName,
                          paper: paper,
                          studentName: studentName,
                          rollNumber: rollNumber,
                          fontSizeMultiplier: fontSizeMultiplier,
                        ),
                        pw.SizedBox(height: 12 * spacingMultiplier),
                      ],
                    )
                  else
                    pw.SizedBox(height: 4),

                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: pageContent,
                  ),
                ],
              );
            },
          ),
        );
      }

      // For single-page PDFs, add the same page again for 2 copies
      if (isSinglePage) {
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
                  pw.SizedBox(height: 12 * spacingMultiplier),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: pages[0],
                  ),
                ],
              );
            },
          ),
        );
      }
    } catch (e) {
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
      _regularFont = pw.Font.times();
      _boldFont = pw.Font.timesBold();
    } catch (e) {
      _regularFont = pw.Font.courier();
      _boldFont = pw.Font.courierBold();
    }
  }

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
            pw.Text('Total Marks: ${paper.totalMarks.toInt()}',
                style: pw.TextStyle(fontSize: 10 * fontSizeMultiplier, font: _regularFont)),
          ],
        ),

        pw.SizedBox(height: 2),
        pw.Container(height: 1, color: PdfColors.grey),
      ],
    );
  }

  pw.Widget _buildSinglePageQuestion({
    required Question question,
    required int questionNumber,
    bool showCommonText = true,
    double fontSizeMultiplier = 1.0,
    bool hideOptions = false,
  }) {
    if (question.type == 'word_forms' && question.options != null && question.options!.isNotEmpty) {
      final optionsText = question.options!.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final optionLabel = String.fromCharCode(97 + index);
        return '$optionLabel) $option';
      }).join('  ');

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '$questionNumber. ${question.text}',
            style: pw.TextStyle(
              fontSize: 11 * fontSizeMultiplier,
              fontWeight: pw.FontWeight.normal,
              font: _regularFont,
            ),
          ),
          pw.SizedBox(height: 0.5),
          pw.Text(
            optionsText,
            style: pw.TextStyle(
              fontSize: 11 * fontSizeMultiplier,
              fontWeight: pw.FontWeight.normal,
              font: _regularFont,
            ),
            maxLines: 3,
            textAlign: pw.TextAlign.left,
          ),
          if (question.subQuestions.isNotEmpty)
            ..._buildSinglePageSubQuestions(question.subQuestions, fontSizeMultiplier),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          showCommonText
              ? '$questionNumber. ${question.text}'
              : '$questionNumber. ${_extractSpecificText(question.text, question.type)}',
          style: pw.TextStyle(
            fontSize: 11 * fontSizeMultiplier,
            fontWeight: pw.FontWeight.normal,
            font: _regularFont,
          ),
        ),
        pw.SizedBox(height: 1),
        if (question.type == 'match_following' && question.options != null)
          _buildMatchingPairs(question.options!, fontSizeMultiplier)
        else if (question.options != null && question.options!.isNotEmpty && !hideOptions)
          _buildSinglePageOptions(question, fontSizeMultiplier),
        if (question.subQuestions.isNotEmpty)
          ..._buildSinglePageSubQuestions(question.subQuestions, fontSizeMultiplier),
      ],
    );
  }

  pw.Widget _buildCompactSingleQuestion({
    required Question question,
    required int questionNumber,
    bool showCommonText = true,
    bool hideOptions = false,
  }) {
    if (question.type == 'word_forms' && question.options != null && question.options!.isNotEmpty) {
      final optionsText = question.options!.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final optionLabel = String.fromCharCode(97 + index);
        return '$optionLabel) $option';
      }).join('   ');

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '$questionNumber. ${question.text}',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              font: _regularFont,
            ),
          ),
          pw.SizedBox(height: 0.5),
          pw.Text(
            optionsText,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.normal,
              font: _regularFont,
            ),
            maxLines: 2,
            textAlign: pw.TextAlign.left,
          ),
          if (question.subQuestions.isNotEmpty)
            ..._buildCompactSubQuestions(question.subQuestions),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          showCommonText
              ? '$questionNumber. ${question.text}'
              : '$questionNumber. ${_extractSpecificText(question.text, question.type)}',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.normal,
            font: _regularFont,
          ),
        ),
        pw.SizedBox(height: 1),
        if (question.type == 'match_following' && question.options != null)
          _buildCompactMatchingPairs(question.options!)
        else if (question.options != null && question.options!.isNotEmpty && !hideOptions)
          _buildCompactHorizontalOptions(question),
        if (question.subQuestions.isNotEmpty)
          ..._buildCompactSubQuestions(question.subQuestions),
      ],
    );
  }

  pw.Widget _buildMatchingPairs(List<String> options, double fontSizeMultiplier) {
    try {
      int separatorIndex = options.indexOf('---SEPARATOR---');
      if (separatorIndex == -1) return pw.SizedBox.shrink();

      List<String> leftColumn = options.sublist(0, separatorIndex);
      List<String> rightColumn = options.sublist(separatorIndex + 1);

      return pw.Column(
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Column A',
                  style: pw.TextStyle(fontSize: 11 * fontSizeMultiplier,
                      fontWeight: pw.FontWeight.bold,
                      font: _boldFont),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Text(
                  'Column B',
                  style: pw.TextStyle(fontSize: 11 * fontSizeMultiplier,
                      fontWeight: pw.FontWeight.bold,
                      font: _boldFont),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          ...List.generate(
            leftColumn.length.compareTo(rightColumn.length) <= 0 ? leftColumn.length : rightColumn.length,
                (i) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 1),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      i < leftColumn.length ? leftColumn[i] : '',
                      style: pw.TextStyle(fontSize: 11 * fontSizeMultiplier, font: _regularFont),
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: pw.Text(
                      i < rightColumn.length ? rightColumn[i] : '',
                      style: pw.TextStyle(fontSize: 11 * fontSizeMultiplier, font: _regularFont),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } catch (e) {
      return pw.Text('[Matching question error]',
          style: pw.TextStyle(fontSize: 11 * fontSizeMultiplier, color: PdfColors.grey));
    }
  }

  pw.Widget _buildCompactMatchingPairs(List<String> options) {
    try {
      int separatorIndex = options.indexOf('---SEPARATOR---');
      if (separatorIndex == -1) return pw.SizedBox.shrink();

      List<String> leftColumn = options.sublist(0, separatorIndex);
      List<String> rightColumn = options.sublist(separatorIndex + 1);

      return pw.Column(
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Column A',
                  style: pw.TextStyle(fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      font: _boldFont),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Text(
                  'Column B',
                  style: pw.TextStyle(fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      font: _boldFont),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 1),
          ...List.generate(
            leftColumn.length.compareTo(rightColumn.length) <= 0 ? leftColumn.length : rightColumn.length,
                (i) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 0.5),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      i < leftColumn.length ? leftColumn[i] : '',
                      style: pw.TextStyle(fontSize: 9, font: _regularFont),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Text(
                      i < rightColumn.length ? rightColumn[i] : '',
                      style: pw.TextStyle(fontSize: 9, font: _regularFont),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } catch (e) {
      return pw.Text('[Error]', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey));
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
      runSpacing: 1,
      children: question.options!.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final optionLabel = String.fromCharCode(65 + index);

        return pw.Container(
          child: pw.Text(
            '$optionLabel) $option',
            style: pw.TextStyle(
              fontSize: 8,
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
    widgets.add(pw.SizedBox(height: 1));

    for (int i = 0; i < subQuestions.length; i++) {
      final subQuestion = subQuestions[i];
      final subLabel = String.fromCharCode(97 + i);

      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(left: 6, bottom: 0.5),
          child: pw.Text(
            '$subLabel) ${subQuestion.text}',
            style: pw.TextStyle(fontSize: 8, font: _regularFont),
          ),
        ),
      );
    }

    return widgets;
  }

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
      default: return number.toString();
    }
  }

  List<MapEntry<String, List<Question>>> _getSortedSections(
      Map<String, List<Question>> questions,
      List<PaperSectionEntity> paperSections) {
    // Order sections based on paperSections order (teacher's creation order)
    final sortedEntries = <MapEntry<String, List<Question>>>[];

    for (final section in paperSections) {
      final sectionName = section.name;
      if (questions.containsKey(sectionName)) {
        sortedEntries.add(
          MapEntry(sectionName, questions[sectionName]!),
        );
      }
    }

    // Add any remaining sections that might not be in paperSections
    // (this shouldn't happen in normal cases)
    for (final entry in questions.entries) {
      if (!sortedEntries.any((e) => e.key == entry.key)) {
        sortedEntries.add(entry);
      }
    }

    return sortedEntries;
  }

  String _getCommonInstruction(String questionType) {
    return '';
  }

  String _extractSpecificText(String questionText, String questionType) {
    final commonInstruction = _getCommonInstruction(questionType);
    if (commonInstruction.isEmpty) return questionText;

    String cleaned = questionText;
    if (cleaned.toLowerCase().startsWith(commonInstruction.toLowerCase())) {
      cleaned = cleaned.substring(commonInstruction.length).trim();
    }

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

  List<pw.Widget> _buildSharedWordBankWidget(List<Question> questions) {
    final sharedWordBank = <String>{};
    for (final q in questions) {
      if (q.options != null && q.options!.isNotEmpty) {
        sharedWordBank.addAll(q.options!);
      }
    }

    if (sharedWordBank.isEmpty) return [];

    final wordBankText = '[${sharedWordBank.join(', ')}]';

    return [
      pw.SizedBox(height: 1),
      pw.Text(
        wordBankText,
        style: pw.TextStyle(
          fontSize: 8,
          font: _regularFont,
        ),
        maxLines: 3,
        textAlign: pw.TextAlign.left,
      ),
      pw.SizedBox(height: 1),
    ];
  }

  List<pw.Widget> _buildSharedWordBankWidgetForSinglePage(
      List<Question> questions, double fontSizeMultiplier, double spacingMultiplier) {
    final sharedWordBank = <String>{};
    for (final q in questions) {
      if (q.options != null && q.options!.isNotEmpty) {
        sharedWordBank.addAll(q.options!);
      }
    }

    if (sharedWordBank.isEmpty) return [];

    final wordBankText = '[${sharedWordBank.join(', ')}]';

    return [
      pw.SizedBox(height: 1 * spacingMultiplier),
      pw.Text(
        wordBankText,
        style: pw.TextStyle(
          fontSize: 9 * fontSizeMultiplier,
          font: _regularFont,
        ),
        maxLines: 3,
        textAlign: pw.TextAlign.left,
      ),
      pw.SizedBox(height: 1 * spacingMultiplier),
    ];
  }

  String _formatExamDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  double _calculateQuestionHeight(Question question) {
    double height = 0;

    final textLength = question.text.length;
    if (textLength <= 50) {
      height += 15;
    } else if (textLength <= 100) {
      height += 25;
    } else {
      height += 3;
    }

    if (question.subQuestions.isNotEmpty) {
      height += 3;
      for (final subQ in question.subQuestions) {
        final subTextLength = subQ.text.length;
        if (subTextLength <= 40) {
          height += 12;
        } else {
          height += 18;
        }
      }
    }

    height += 4;

    return height;
  }

  double _calculateSectionHeight(String sectionName, List<Question> questions) {
    if (questions.isEmpty) return 0;

    double height = 0;

    height += 20;

    final commonInstruction = _getCommonInstruction(questions.first.type);
    if (commonInstruction.isNotEmpty) {
      height += 18;
    }

    for (final question in questions) {
      height += _calculateQuestionHeight(question);
    }

    height += 6;

    return height;
  }

  List<List<pw.Widget>> _paginateContent(
      List<pw.Widget> allWidgets,
      String schoolName,
      QuestionPaperEntity paper,
      String? studentName,
      String? rollNumber,
      double fontSizeMultiplier,
      double spacingMultiplier,
      ) {
    final pages = <List<pw.Widget>>[];
    final currentPage = <pw.Widget>[];
    double currentPageHeight = 0;

    final availableHeightFirstPage = (USABLE_PAGE_HEIGHT - HEADER_HEIGHT) * 0.95;
    final availableHeightOtherPages = (USABLE_PAGE_HEIGHT - 30) * 0.95;

    double maxHeightForCurrentPage = availableHeightFirstPage;
    bool isFirstPage = true;

    for (final widget in allWidgets) {
      final widgetHeight = _estimateWidgetHeight(widget, fontSizeMultiplier);

      if (currentPageHeight + widgetHeight > maxHeightForCurrentPage && currentPage.isNotEmpty) {
        pages.add(List.from(currentPage));
        currentPage.clear();
        currentPageHeight = 0;
        maxHeightForCurrentPage = availableHeightOtherPages;
        isFirstPage = false;
      }

      currentPage.add(widget);
      currentPageHeight += widgetHeight;
    }

    if (currentPage.isNotEmpty) {
      pages.add(currentPage);
    }

    return pages.isEmpty ? [allWidgets] : pages;
  }

  double _estimateWidgetHeight(pw.Widget widget, double fontSizeMultiplier) {
    if (widget is pw.SizedBox) {
      return widget.height ?? 0;
    }

    if (widget is pw.Text) {
      return 12 * fontSizeMultiplier;
    }

    if (widget is pw.Container) {
      return 15 * fontSizeMultiplier;
    }

    if (widget is pw.Column) {
      return 18 * fontSizeMultiplier;
    }

    if (widget is pw.Row) {
      return 14 * fontSizeMultiplier;
    }

    return 10 * fontSizeMultiplier;
  }
}