// features/question_papers/presentation/widgets/question_paper_pdf_preview.dart
import 'package:flutter/material.dart';
import '../../domain/entities/question_paper_entity.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../domain/entities/question_entity.dart';

class QuestionPaperPDFPreview extends StatelessWidget {
  final QuestionPaperEntity questionPaper;
  final bool isAdminReview;

  const QuestionPaperPDFPreview({
    super.key,
    required this.questionPaper,
    this.isAdminReview = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Question Paper Preview'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          if (isAdminReview) ...[
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _downloadPDF(context),
              tooltip: 'Download PDF',
            ),
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: () => _printPreview(context),
              tooltip: 'Print Preview',
            ),
          ],
        ],
      ),
      backgroundColor: Colors.grey[200],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Container(
            width: 794, // A4 width in logical pixels (210mm)
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(40), // A4 margins
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 30),
                  _buildInstructions(),
                  const SizedBox(height: 30),
                  _buildQuestionSections(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Institution header (you can customize this)
        Text(
          'EXAMINATION BOARD',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Question paper title
        Text(
          questionPaper.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 20),

        // Paper details table
        Table(
          border: TableBorder.all(color: Colors.black, width: 1),
          children: [
            _buildTableRow('Subject', questionPaper.subject),
            _buildTableRow('Exam Type', questionPaper.examTypeEntity.name),
            _buildTableRow('Duration', questionPaper.examTypeEntity.formattedDuration),
            _buildTableRow('Total Marks', '${questionPaper.totalMarks} marks'),
            _buildTableRow('Date', '_______________'),
            _buildTableRow('Time', '_______________'),
          ],
        ),

        const SizedBox(height: 20),

        // Student details section
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Student Name: _________________________',
                        style: TextStyle(fontSize: 12)),
                    SizedBox(height: 8),
                    Text('Roll Number: ___________',
                        style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Container(
              width: 100,
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
              ),
              child: const Center(
                child: Text(
                  'PHOTO',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  TableRow _buildTableRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            value,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INSTRUCTIONS:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ..._getInstructions().map((instruction) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• $instruction', style: const TextStyle(fontSize: 12)),
          )),
        ],
      ),
    );
  }

  Widget _buildQuestionSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: questionPaper.examTypeEntity.sections.map((section) {
        final sectionQuestions = questionPaper.questions[section.name] ?? [];
        if (sectionQuestions.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            _buildSectionHeader(section, sectionQuestions.length),
            const SizedBox(height: 20),
            ...sectionQuestions.asMap().entries.map((entry) {
              return _buildQuestion(
                entry.key + 1,
                entry.value,
                section.marksPerQuestion,
              );
            }),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(ExamSectionEntity section, int questionCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border.all(color: Colors.black),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SECTION ${section.name.toUpperCase()}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Answer ALL questions. Each question carries ${section.marksPerQuestion} marks.',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            'Total: $questionCount questions × ${section.marksPerQuestion} marks = ${questionCount * section.marksPerQuestion} marks',
            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(int questionNumber, Question question, int marks) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question number and marks
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$questionNumber. ',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Expanded(
                child: Text(
                  question.text,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Text(
                '[$marks marks]',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),

          // Multiple choice options (if applicable)
          if (question.type == 'multiple_choice' && question.options != null) ...[
            const SizedBox(height: 8),
            ...question.options!.asMap().entries.map((entry) {
              final optionLetter = String.fromCharCode(65 + entry.key); // A, B, C, D
              return Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 4),
                child: Text(
                  '$optionLetter) ${entry.value}',
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }),
          ],

          // Answer space for written answers
          if (question.type != 'multiple_choice') ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: _getAnswerSpaceHeight(marks),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  double _getAnswerSpaceHeight(int marks) {
    // Allocate space based on marks - more marks = more space
    return (marks * 20.0).clamp(40.0, 200.0);
  }

  List<String> _getInstructions() {
    return [
      'Read all questions carefully before attempting.',
      'Answer ALL questions in the spaces provided.',
      'Use black or blue pen only.',
      'Mobile phones and electronic devices are not allowed.',
      'Time allowed: ${questionPaper.examTypeEntity.formattedDuration}.',
      'Total marks: ${questionPaper.totalMarks}',
    ];
  }

  void _downloadPDF(BuildContext context) {
    // TODO: Implement PDF download functionality with pdf package
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF download feature - implement with pdf package'),
      ),
    );
  }

  void _printPreview(BuildContext context) {
    // TODO: Implement print preview functionality with printing package
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Print preview feature - implement with printing package'),
      ),
    );
  }
}