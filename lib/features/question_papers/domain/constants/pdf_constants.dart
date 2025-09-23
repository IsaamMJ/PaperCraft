// features/question_papers/domain2/constants/pdf_constants.dart
class PdfConstants {
  PdfConstants._();

  // Page dimensions and margins
  static const double pageWidth = 595; // A4 width in points
  static const double pageHeight = 842; // A4 height in points
  static const double marginLeft = 50;
  static const double marginRight = 50;
  static const double marginTop = 50;
  static const double marginBottom = 50;
  static const double contentWidth = pageWidth - marginLeft - marginRight;
  static const double contentHeight = pageHeight - marginTop - marginBottom;

  // Font sizes
  static const double headerFontSize = 18;
  static const double subHeaderFontSize = 14;
  static const double titleFontSize = 16;
  static const double questionFontSize = 12;
  static const double optionFontSize = 11;
  static const double instructionFontSize = 10;
  static const double footerFontSize = 8;

  // Spacing
  static const double sectionSpacing = 20;
  static const double questionSpacing = 15;
  static const double optionSpacing = 8;
  static const double lineSpacing = 5;
  static const double headerSpacing = 10;

  // Colors (for teacher copy highlighting)
  static const int correctAnswerColor = 0xFF4CAF50; // Green
  static const int headerColor = 0xFF2196F3; // Blue
  static const int sectionColor = 0xFF607D8B; // Blue Grey

  // Text formatting
  static const String instructionsText = '''
INSTRUCTIONS:
• Read all questions carefully before answering
• Answer all questions in the space provided
• Use blue or black ink only
• Mobile phones are not allowed in the examination hall
• Calculators are permitted unless specified otherwise
''';

  static const String teacherInstructions = '''
TEACHER COPY - ANSWER KEY INCLUDED
This copy contains correct answers marked in green.
Do not distribute to students.
''';

  // Question type labels
  static const Map<String, String> questionTypeLabels = {
    'multiple_choice': 'Multiple Choice Questions',
    'short_answer': 'Short Answer Questions',
    'essay': 'Essay Questions',
    'fill_blanks': 'Fill in the Blanks',
    'true_false': 'True/False Questions',
  };

  // Option labels
  static const List<String> optionLabels = ['A', 'B', 'C', 'D', 'E', 'F'];

  // Footer text
  static String getFooterText(bool isTeacherCopy) {
    final copyType = isTeacherCopy ? 'Teacher Copy' : 'Student Copy';
    return '$copyType • Generated on ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
  }

  // Answer sheet instructions
  static const String answerSheetInstructions = '''
ANSWER SHEET

Instructions:
• Write your answers clearly in the spaces provided
• For multiple choice questions, clearly mark your choice
• Check your answers before submitting
• Ensure your name and roll number are written clearly
''';

  // Validation constants
  static const int maxQuestionsPerPage = 10;
  static const int maxOptionsPerQuestion = 6;
  static const double minQuestionHeight = 30;
  static const double maxQuestionHeight = 200;
}