import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';

void main() async {
  final excelFile = File('lib/Student 1-V 2026.xlsx');
  final bytes = await excelFile.readAsBytes();

  final archive = ZipDecoder().decodeBytes(bytes);

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

  // Split by </si><si> to get individual string entries
  final stringPattern = RegExp(r'<t[^>]*>([^<]*)</t>');
  for (final match in stringPattern.allMatches(stringContent)) {
    strings.add(match.group(1) ?? '');
  }

  print('Found ${strings.length} shared strings');
  print('First 15 strings:');
  for (int i = 0; i < (strings.length < 15 ? strings.length : 15); i++) {
    print('  [$i] = "${strings[i]}"');
  }

  // Parse worksheet to extract cell references and values
  final sheetContent = utf8.decode(sheetFile.content);

  // Extract all cells with their row/col and values
  final cellPattern = RegExp(r'<c r="([A-Z]+)(\d+)"[^>]*(?:t="([^"]*)")?[^>]*>(?:<v>([^<]*)</v>)?');
  final cellData = <String, Map<String, dynamic>>{};

  for (final match in cellPattern.allMatches(sheetContent)) {
    final col = match.group(1);
    final row = match.group(2);
    final type = match.group(3);
    final value = match.group(4) ?? '';

    final key = '$col$row';

    dynamic cellValue = value;
    if (type == 's') {
      // String reference
      final index = int.tryParse(value);
      if (index != null && index < strings.length) {
        cellValue = strings[index];
      }
    } else if (type == null && value.isNotEmpty) {
      // Numeric value
      cellValue = value;
    }

    cellData[key] = {
      'col': col,
      'row': int.parse(row ?? '0'),
      'type': type,
      'value': cellValue,
    };
  }

  print('\nFound ${cellData.length} cells\n');

  // Extract student data
  // Based on header row analysis:
  // A: Roll No, B: Name, C: Initial, D: Class/Grade, E: Section, F: Gender, G: DOB

  final students = <Map<String, String>>[];

  int rowNum = 2; // Start after header
  while (true) {
    final rollKey = 'A$rowNum';
    if (!cellData.containsKey(rollKey)) break;

    var rollValue = cellData[rollKey]?['value'];
    if (rollValue == null || rollValue.toString().isEmpty) break;

    final rollNumber = rollValue.toString().trim();

    // Helper to resolve string index if needed
    String? resolveValue(dynamic value) {
      if (value == null) return null;
      final strValue = value.toString().trim();
      if (strValue.isEmpty) return null;
      // Try to parse as string index
      final index = int.tryParse(strValue);
      if (index != null && index < strings.length) {
        return strings[index].toString().trim();
      }
      return strValue;
    }

    // Extract data from each column
    final nameValue = resolveValue(cellData['B$rowNum']?['value']) ?? '';
    final initialValue = resolveValue(cellData['C$rowNum']?['value']) ?? '';
    final gradeValue = resolveValue(cellData['D$rowNum']?['value']) ?? '';
    final sectionValue = resolveValue(cellData['E$rowNum']?['value']) ?? '';
    final genderValue = resolveValue(cellData['F$rowNum']?['value']) ?? '';
    final dobValue = resolveValue(cellData['G$rowNum']?['value']) ?? '';

    // Convert Excel date serial to ISO format (Excel epoch is 1900-01-01)
    String? dobIso;
    if (dobValue.isNotEmpty) {
      try {
        final excelDays = int.parse(dobValue);
        // Excel stores dates as days since 1900-01-01 (with leap year bug)
        // 1900-01-01 = 1, so we subtract 1
        final baseDate = DateTime(1900, 1, 1);
        final adjustedDate = baseDate.add(Duration(days: excelDays - 1));
        dobIso = adjustedDate.toIso8601String().split('T')[0]; // YYYY-MM-DD
      } catch (e) {
        // If not a number, treat as-is (might already be formatted)
        dobIso = dobValue.isNotEmpty ? dobValue : '';
      }
    }

    // Combine name and initial if initial exists
    final fullName = initialValue.isNotEmpty && initialValue != nameValue
        ? '$nameValue $initialValue'
        : nameValue;

    if (fullName.isNotEmpty && rollNumber.isNotEmpty) {
      students.add({
        'roll_number': rollNumber,
        'full_name': fullName,
        'grade_code': gradeValue,
        'section_code': sectionValue,
        'gender': genderValue,
        'dob': dobIso ?? '',
      });

      if (students.length <= 10) {
        print('Row $rowNum: Roll=$rollNumber, Name=$fullName, Grade=$gradeValue, Section=$sectionValue, Gender=$genderValue, DOB=$dobIso');
      }
    }

    rowNum++;
  }

  print('\nExtracted ${students.length} students\n');

  // Analyze codes
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

  print('=' * 80);
  print('UNIQUE GRADES (codes from Excel):');
  print('=' * 80);
  final sortedGrades = gradeCodes.keys.toList();
  sortedGrades.sort();
  for (final grade in sortedGrades) {
    print('  Grade "$grade": ${gradeCodes[grade]} students');
  }

  print('\n' + '=' * 80);
  print('UNIQUE SECTIONS (codes from Excel):');
  print('=' * 80);
  final sortedSections = sectionCodes.keys.toList();
  sortedSections.sort();
  for (final section in sortedSections) {
    print('  Section "$section": ${sectionCodes[section]} students');
  }

  // Save to CSV with proper format
  final csvFile = File('lib/students_bulk_upload.csv');
  final csvContent = StringBuffer();

  // Header: roll_number, full_name, grade, section, gender, date_of_birth, email, phone
  csvContent.writeln('roll_number,full_name,grade,section,gender,date_of_birth,email,phone');

  for (final student in students) {
    final roll = student['roll_number'] ?? '';
    final name = student['full_name'] ?? '';
    final grade = student['grade_code'] ?? '';
    final section = student['section_code'] ?? '';
    final gender = student['gender'] ?? '';
    final dob = student['dob'] ?? '';

    // Escape quotes in name
    final escapedName = name.replaceAll('"', '""');

    csvContent.writeln('$roll,"$escapedName",$grade,$section,$gender,$dob,,');
  }

  await csvFile.writeAsString(csvContent.toString());

  print('\n' + '=' * 80);
  print('✓ Saved ${students.length} students to: lib/students_bulk_upload.csv');
  print('=' * 80);

  print('\n📋 NEXT STEPS:');
  print('1. In the app, go to bulk upload');
  print('2. Select a Grade (I, II, III, IV, or V)');
  print('3. Select a Section (A or B)');
  print('4. Upload this CSV file');
  print('5. All students will be added to the selected grade and section');
}
