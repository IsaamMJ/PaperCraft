import 'dart:io';
import 'dart:convert';
import 'package:papercraft/features/pdf_generation/domain/services/pdf_generation_service.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/question_paper_entity.dart';

void main() async {
  print('🔧 Testing PDF Generation with Grade 5 data...\n');

  try {
    // Read the problematic grade5.txt file
    final file = File('E:\\New folder (2)\\papercraft\\grade5.txt');
    final jsonStr = await file.readAsString();
    final jsonData = json.decode(jsonStr);

    // Parse into QuestionPaperEntity
    final paper = QuestionPaperEntity.fromJson(jsonData);

    print('📄 Paper: ${paper.title}');
    print('📊 Total Marks: ${paper.totalMarks}');
    print('📝 Total Questions: ${paper.totalQuestions}');
    print('🗂️  Sections: ${paper.questions.keys.join(", ")}\n');

    // Generate PDF with standard settings
    final pdfService = SimplePdfService();

    print('⏳ Generating PDF with fontMultiplier=1.3, spacingMultiplier=1.0...');
    final pdfBytes = await pdfService.generateStudentPdf(
      paper: paper,
      schoolName: 'Test School',
      fontSizeMultiplier: 1.3,
      spacingMultiplier: 1.0,
    );

    print('✅ PDF generated successfully!');
    print('📦 Size: ${(pdfBytes.length / 1024).toStringAsFixed(2)} KB');

    // Save to file
    final outputFile = File('E:\\New folder (2)\\papercraft\\test_output.pdf');
    await outputFile.writeAsBytes(pdfBytes);
    print('💾 Saved to: ${outputFile.path}');

    // Parse PDF to check page count
    final pdfStr = String.fromCharCodes(pdfBytes);
    final countPattern = RegExp(r'/Type\s*/Pages[^>]*?/Count\s*(\d+)');
    final match = countPattern.firstMatch(pdfStr);

    if (match != null) {
      final pageCount = int.parse(match.group(1)!);
      print('📖 Page Count: $pageCount pages');

      if (pageCount == 2 && pdfBytes.length < 10000) {
        print('⚠️  WARNING: Possible blank first page issue!');
      } else {
        print('✅ Page count looks healthy!');
      }
    }

  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack trace:\n$stackTrace');
  }
}
