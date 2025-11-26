import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';

void main() async {
  final excelFile = File('lib/Student 1-V 2026.xlsx');
  final bytes = await excelFile.readAsBytes();

  // Read the zip archive
  final archive = ZipDecoder().decodeBytes(bytes);

  // Find and read the worksheet
  ArchiveFile? sheetFile;
  ArchiveFile? stringFile;

  for (final file in archive) {
    if (file.name == 'xl/worksheets/sheet1.xml') {
      sheetFile = file;
    } else if (file.name == 'xl/sharedStrings.xml') {
      stringFile = file;
    }
  }

  if (sheetFile == null || stringFile == null) {
    print('Error: Could not find worksheet or strings file');
    return;
  }

  // Parse shared strings
  final stringContent = utf8.decode(stringFile.content);
  final strings = <String>[];

  final stringPattern = RegExp(r'<t>([^<]*)</t>');
  for (final match in stringPattern.allMatches(stringContent)) {
    strings.add(match.group(1) ?? '');
  }

  print('Found ${strings.length} shared strings');

  // Parse worksheet
  final sheetContent = utf8.decode(sheetFile.content);

  // Extract all cell values
  final cellPattern = RegExp(r'<c r="([A-Z]+)(\d+)"[^>]*(?:t="([^"]*)")?[^>]*><v>([^<]*)</v>');
  final cellMap = <String, String>{};

  for (final match in cellPattern.allMatches(sheetContent)) {
    final col = match.group(1);
    final row = match.group(2);
    final type = match.group(3);
    final value = match.group(4);

    final key = '$col$row';
    String cellValue = value ?? '';

    // If type is 's' (string), it's an index into shared strings
    if (type == 's') {
      final index = int.tryParse(cellValue);
      if (index != null && index < strings.length) {
        cellValue = strings[index];
      }
    }

    cellMap[key] = cellValue;
  }

  print('Found ${cellMap.length} cells');

  // Extract student data
  // Columns: A=roll, B=grade, C=section, D=gender, E=dob, F+=name parts
  final students = <Map<String, String>>[];

  int rowNum = 2;
  while (true) {
    final rollNum = cellMap['A$rowNum']?.trim() ?? '';
    if (rollNum.isEmpty) break;

    final grade = cellMap['B$rowNum']?.trim() ?? '';
    final section = cellMap['C$rowNum']?.trim() ?? '';
    final gender = cellMap['D$rowNum']?.trim() ?? '';

    // Collect name parts from columns F onwards
    final nameParts = <String>[];
    for (int col = 6; col <= 20; col++) {
      final colLetter = String.fromCharCode(64 + col); // F=6, G=7, etc
      final nameCol = cellMap['$colLetter$rowNum']?.trim() ?? '';
      if (nameCol.isNotEmpty) {
        nameParts.add(nameCol);
      }
    }

    final fullName = nameParts.join(' ');

    if (fullName.isNotEmpty && rollNum.isNotEmpty) {
      students.add({
        'roll_number': rollNum,
        'full_name': fullName,
        'grade_code': grade,
        'section_code': section,
        'gender': gender,
      });
    }

    rowNum++;
  }

  print('\nExtracted ${students.length} students');
  print('\nSample data (first 10):');
  print('-' * 100);

  for (int i = 0; i < (students.length < 10 ? students.length : 10); i++) {
    final s = students[i];
    print('${(i+1).toString().padRight(3)} | ${s['roll_number']?.padRight(6)} | ${s['full_name']?.padRight(35)} | Grade: ${s['grade_code']?.padRight(4)} | Section: ${s['section_code']?.padRight(4)}');
  }

  // Analyze grade and section codes
  final gradeCodes = <String, int>{};
  final sectionCodes = <String, int>{};

  for (final student in students) {
    final grade = student['grade_code'] ?? '';
    final section = student['section_code'] ?? '';

    if (grade.isNotEmpty) {
      gradeCodes[grade] = (gradeCodes[grade] ?? 0) + 1;
    }
    if (section.isNotEmpty) {
      sectionCodes[section] = (sectionCodes[section] ?? 0) + 1;
    }
  }

  print('\n' + '=' * 100);
  print('GRADE CODE DISTRIBUTION:');
  print('=' * 100);

  final sortedGrades = gradeCodes.keys.toList();
  sortedGrades.sort((a, b) {
    final aNum = int.tryParse(a) ?? 0;
    final bNum = int.tryParse(b) ?? 0;
    return aNum.compareTo(bNum);
  });
  for (final grade in sortedGrades) {
    print('  Grade Code $grade: ${gradeCodes[grade]} students');
  }

  print('\n' + '=' * 100);
  print('SECTION CODE DISTRIBUTION:');
  print('=' * 100);

  final sortedSections = sectionCodes.keys.toList();
  sortedSections.sort((a, b) {
    final aNum = int.tryParse(a) ?? 0;
    final bNum = int.tryParse(b) ?? 0;
    return aNum.compareTo(bNum);
  });
  for (final section in sortedSections) {
    print('  Section Code $section: ${sectionCodes[section]} students');
  }

  // Save to CSV
  final csvFile = File('lib/students_bulk_upload.csv');
  final csvContent = StringBuffer();

  csvContent.writeln('roll_number,full_name,grade,section,email,phone');

  for (final student in students) {
    final roll = student['roll_number'] ?? '';
    final name = student['full_name'] ?? '';
    // For now, leave grade and section as codes - will need manual mapping
    final grade = student['grade_code'] ?? '';
    final section = student['section_code'] ?? '';

    // Escape quotes in name
    final escapedName = name.replaceAll('"', '""');

    csvContent.writeln('$roll,"$escapedName",$grade,$section,,');
  }

  await csvFile.writeAsString(csvContent.toString());

  print('\n' + '=' * 100);
  print('✓ Saved ${students.length} students to: lib/students_bulk_upload.csv');
  print('=' * 100);

  print('\nNEXT STEPS:');
  print('1. Map grade codes to grade numbers in your database');
  print('2. Map section codes to section names in your database');
  print('3. Update the CSV file with correct grade and section values');
  print('4. Use the bulk upload feature to import the data');
}
