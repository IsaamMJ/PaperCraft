import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';

import '../../domain/entities/exam_timetable_entity.dart';
import '../../domain/entities/exam_timetable_entry_entity.dart';

/// Service to generate PDF for exam timetables with branding
class TimetablePdfGenerator {
  /// Generate PDF for a timetable with school branding
  static Future<Uint8List> generateTimetablePdf({
    required ExamTimetableEntity timetable,
    required List<ExamTimetableEntryEntity> entries,
    required String schoolName,
    required List<int> gradeNumbers,
  }) async {
    final pdf = pw.Document();

    // Define colors for branding
    const primaryColor = PdfColor.fromInt(0xFF6366F1); // Indigo
    const accentColor = PdfColor.fromInt(0xFFF59E0B); // Amber

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          // Header with school name
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: primaryColor, width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  schoolName,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Exam Timetable',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Exam details
          pw.Container(
            width: double.infinity,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Exam Name', timetable.examName),
                pw.SizedBox(height: 6),
                _buildDetailRow('Exam Type', timetable.examType),
                pw.SizedBox(height: 6),
                _buildDetailRow('Academic Year', timetable.academicYear),
                pw.SizedBox(height: 6),
                _buildDetailRow('Status', timetable.status.toUpperCase()),
                pw.SizedBox(height: 6),
                _buildDetailRow('Grades', gradeNumbers.map((g) => 'Grade $g').join(', ')),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Timetable entries
          pw.Text(
            'Exam Schedule',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),

          // Group entries by (examDate, subjectName, scheduleDisplay)
          // This avoids repetition and shows all grades for each subject
          pw.SizedBox(
            width: double.infinity,
            child: _buildGroupedTimetableTable(entries, primaryColor),
          ),

          pw.SizedBox(height: 40),

          // Footer with branding
          pw.Divider(color: accentColor, thickness: 2),
          pw.SizedBox(height: 10),
          pw.Container(
            width: double.infinity,
            alignment: pw.Alignment.center,
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'Powered by',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Papercraft × Scholar HQ',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Smart Exam Management System',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Build grouped timetable showing all grades per subject
  static pw.Widget _buildGroupedTimetableTable(
    List<ExamTimetableEntryEntity> entries,
    PdfColor primaryColor,
  ) {
    // Group entries by (examDate, subjectName, scheduleDisplay)
    final Map<String, List<ExamTimetableEntryEntity>> groupedEntries = {};
    for (final entry in entries) {
      final key = '${entry.examDate}|${entry.subjectName}|${entry.scheduleDisplay}';
      groupedEntries.putIfAbsent(key, () => []).add(entry);
    }

    // Sort by exam date
    final sortedKeys = groupedEntries.keys.toList()
      ..sort((a, b) {
        final dateA = a.split('|')[0];
        final dateB = b.split('|')[0];
        return dateA.compareTo(dateB);
      });

    // Build table data - only show Date, Subject, Time (Grades already shown at top)
    final List<List<String>> tableData = [];
    for (final key in sortedKeys) {
      final groupedList = groupedEntries[key] ?? [];
      if (groupedList.isEmpty) continue;

      final firstEntry = groupedList.first;

      tableData.add([
        _formatDate(firstEntry.examDate),
        firstEntry.subjectName ?? 'Unknown',
        firstEntry.scheduleDisplay,
      ]);
    }

    // Build and return the table (Grades column removed - shown at top of PDF)
    return pw.TableHelper.fromTextArray(
      headers: ['Date', 'Subject', 'Time'],
      data: tableData,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(
        color: primaryColor,
      ),
      cellHeight: 30,
      cellAlignment: pw.Alignment.centerLeft,
      rowDecoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: PdfColors.grey300,
            width: 0.5,
          ),
        ),
      ),
    );
  }

  /// Build a detail row for exam info
  static pw.Widget _buildDetailRow(String label, String value) {
    return pw.Container(
      width: double.infinity,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          pw.Text(
            ': ',
            style: pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(width: 8),
          pw.Container(
            width: 350,
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 11),
              maxLines: 3,
              overflow: pw.TextOverflow.clip,
            ),
          ),
        ],
      ),
    );
  }

  /// Format date as "10-Nov-2025"
  static String _formatDate(DateTime date) {
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = monthNames[date.month - 1];
    return '${date.day.toString().padLeft(2, '0')}-$month-${date.year}';
  }
}
