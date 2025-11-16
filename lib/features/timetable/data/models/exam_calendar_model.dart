import 'dart:convert';
import 'package:papercraft/features/timetable/domain/entities/exam_calendar_entity.dart';
import 'package:papercraft/features/timetable/domain/entities/mark_config_entity.dart';
import 'mark_config_model.dart';

/// Data model for ExamCalendarEntity
/// Used for API requests/responses and database mapping
/// Extends the entity with no additional functionality (thin model pattern)
class ExamCalendarModel extends ExamCalendarEntity {
  const ExamCalendarModel({
    required super.id,
    required super.tenantId,
    required super.examName,
    required super.examType,
    required super.monthNumber,
    required super.plannedStartDate,
    required super.plannedEndDate,
    super.paperSubmissionDeadline,
    super.displayOrder,
    super.metadata,
    super.marksConfig,
    super.isActive,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Create model from entity
  factory ExamCalendarModel.fromEntity(ExamCalendarEntity entity) {
    return ExamCalendarModel(
      id: entity.id,
      tenantId: entity.tenantId,
      examName: entity.examName,
      examType: entity.examType,
      monthNumber: entity.monthNumber,
      plannedStartDate: entity.plannedStartDate,
      plannedEndDate: entity.plannedEndDate,
      paperSubmissionDeadline: entity.paperSubmissionDeadline,
      displayOrder: entity.displayOrder,
      metadata: entity.metadata,
      marksConfig: entity.marksConfig,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Create model from JSON (Supabase response)
  factory ExamCalendarModel.fromJson(Map<String, dynamic> json) {
    final examName = json['exam_name'] as String;
    final rawExamType = json['exam_type'] as String;
    // Normalize exam type to handle corrupt database data
    final normalizedExamType = _normalizeExamType(rawExamType, examName);

    // Parse marks configuration if present
    // Supports three formats:
    // 1. Legacy list format: List<Map> with grade ranges
    // 2. New map format: Map with selected_grades and marks
    // 3. JSON string format: String representation of the above
    List<MarkConfigEntity>? marksConfigList;
    final marksConfigJson = json['marks_config'];
    if (marksConfigJson != null) {
      try {
        // Handle JSON string format (from database)
        if (marksConfigJson is String && marksConfigJson.isNotEmpty) {
          print('🔍 [ExamCalendarModel] Parsing marks_config from JSON string: $marksConfigJson');
          final parsed = jsonDecode(marksConfigJson);
          print('📊 [ExamCalendarModel] Parsed marks_config: $parsed (type: ${parsed.runtimeType})');
          if (parsed is List) {
            marksConfigList = (parsed)
                .map((item) => MarkConfigModel.fromJson(item as Map<String, dynamic>))
                .toList();
          } else if (parsed is Map<String, dynamic>) {
            print('📋 [ExamCalendarModel] Converting map format to list format');
            marksConfigList = _convertMapConfigToList(parsed);
            print('✅ [ExamCalendarModel] Converted to ${marksConfigList?.length ?? 0} mark configs');
          }
        } else if (marksConfigJson is List) {
          // Legacy list format
          marksConfigList = (marksConfigJson)
              .map((item) => MarkConfigModel.fromJson(item as Map<String, dynamic>))
              .toList();
        } else if (marksConfigJson is Map<String, dynamic>) {
          // New map format with selected_grades
          // Convert to legacy format for backward compatibility
          print('📋 [ExamCalendarModel] Converting map format to list format');
          marksConfigList = _convertMapConfigToList(marksConfigJson);
          print('✅ [ExamCalendarModel] Converted to ${marksConfigList?.length ?? 0} mark configs');
        }
      } catch (e) {
        print('⚠️ [ExamCalendarModel] Error parsing marks_config: $e');
      }
    }

    return ExamCalendarModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      examName: examName,
      examType: normalizedExamType,
      monthNumber: json['month_number'] as int,
      plannedStartDate:
          DateTime.parse(json['planned_start_date'] as String),
      plannedEndDate: DateTime.parse(json['planned_end_date'] as String),
      paperSubmissionDeadline: json['paper_submission_deadline'] != null
          ? DateTime.parse(json['paper_submission_deadline'] as String)
          : null,
      displayOrder: json['display_order'] as int? ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>?,
      marksConfig: marksConfigList,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert new map format to legacy list format
  /// Map format: {\"selected_grades\": [1,2,3,4,5], \"grades_1_to_5_marks\": 25, ...}
  static List<MarkConfigEntity>? _convertMapConfigToList(Map<String, dynamic> configMap) {
    print('🔄 [ExamCalendarModel] _convertMapConfigToList called with map: $configMap');
    final selectedGrades = configMap['selected_grades'] as List<dynamic>?;
    print('   selectedGrades: $selectedGrades');
    if (selectedGrades == null || selectedGrades.isEmpty) {
      print('   📭 No selected_grades, returning null');
      return null;
    }

    final grades = selectedGrades.cast<int>().toList()..sort();
    print('   Sorted grades: $grades');

    // Create mark configs for grade ranges
    List<MarkConfigEntity> configs = [];

    // Check for grades 1-5
    final grades1To5 = grades.where((g) => g <= 5).toList();
    if (grades1To5.isNotEmpty) {
      final marks1To5 = configMap['grades_1_to_5_marks'] as int?;
      print('   Grades 1-5: $grades1To5, marks: $marks1To5');
      if (marks1To5 != null) {
        configs.add(MarkConfigModel(
          minGrade: grades1To5.first,
          maxGrade: grades1To5.last,
          totalMarks: marks1To5,
          label: 'Grades ${grades1To5.first}-${grades1To5.last}',
        ));
      }
    }

    // Check for grades 6-12
    final grades6To12 = grades.where((g) => g >= 6).toList();
    if (grades6To12.isNotEmpty) {
      final marks6To12 = configMap['grades_6_to_12_marks'] as int?;
      print('   Grades 6-12: $grades6To12, marks: $marks6To12');
      if (marks6To12 != null) {
        configs.add(MarkConfigModel(
          minGrade: grades6To12.first,
          maxGrade: grades6To12.last,
          totalMarks: marks6To12,
          label: 'Grades ${grades6To12.first}-${grades6To12.last}',
        ));
      }
    }

    print('   ✅ Created ${configs.length} mark configs');
    return configs.isEmpty ? null : configs;
  }

  /// Convert to JSON for Supabase insert/update
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'exam_name': examName,
      'exam_type': examType,
      'month_number': monthNumber,
      'planned_start_date': plannedStartDate.toIso8601String(),
      'planned_end_date': plannedEndDate.toIso8601String(),
      'paper_submission_deadline': paperSubmissionDeadline?.toIso8601String(),
      'display_order': displayOrder,
      'metadata': metadata,
      'marks_config': marksConfig?.map((config) => config.toJson()).toList(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert to JSON for API requests (excludes system fields)
  Map<String, dynamic> toJsonRequest() {
    return {
      'exam_name': examName,
      'exam_type': examType,
      'month_number': monthNumber,
      'planned_start_date': plannedStartDate.toIso8601String(),
      'planned_end_date': plannedEndDate.toIso8601String(),
      'paper_submission_deadline': paperSubmissionDeadline?.toIso8601String(),
      'display_order': displayOrder,
      'metadata': metadata,
      'marks_config': marksConfig?.map((config) => config.toJson()).toList(),
    };
  }

  /// Normalize exam type value - handles corrupt database data
  /// Valid database values: 'monthlyTest', 'halfYearlyTest', 'quarterlyTest', 'finalExam', 'dailyTest'
  static String _normalizeExamType(String rawValue, String examName) {
    final normalized = rawValue.toLowerCase().trim();
    final validTypes = ['monthlytest', 'halfyearlytest', 'quarterlytest', 'finalexam', 'dailytest'];

    // If already valid (camelCase check), return as-is
    if (validTypes.contains(normalized)) {
      return rawValue; // Return original casing
    }

    // Map common variations to database enum values
    final typeMapping = {
      'monthly': 'monthlyTest',
      'monthly test': 'monthlyTest',
      'monthlytests': 'monthlyTest',
      'monthlytest': 'monthlyTest',
      'monthly exam': 'monthlyTest',
      'mid_term': 'halfYearlyTest',
      'mid term': 'halfYearlyTest',
      'midterm': 'halfYearlyTest',
      'mid-term': 'halfYearlyTest',
      'midyear': 'halfYearlyTest',
      'halfyearly': 'halfYearlyTest',
      'half yearly': 'halfYearlyTest',
      'half-yearly': 'halfYearlyTest',
      'quarterly': 'quarterlyTest',
      'quarterly test': 'quarterlyTest',
      'final': 'finalExam',
      'final exam': 'finalExam',
      'finalexam': 'finalExam',
      'finalsemester': 'finalExam',
      'unit': 'dailyTest',
      'unit test': 'dailyTest',
      'unittests': 'dailyTest',
      'unittest': 'dailyTest',
      'daily test': 'dailyTest',
      'november': 'monthlyTest',
      'december': 'monthlyTest',
      'october': 'monthlyTest',
      'september': 'monthlyTest',
    };

    // First try direct mapping
    if (typeMapping.containsKey(normalized)) {
      return typeMapping[normalized]!;
    }

    // If not found in mapping, try to extract from exam name
    final examNameLower = examName.toLowerCase();

    if (examNameLower.contains('monthly')) {
      return 'monthlyTest';
    }
    if (examNameLower.contains('mid term') || examNameLower.contains('midterm') || examNameLower.contains('mid-term') || examNameLower.contains('half yearly')) {
      return 'halfYearlyTest';
    }
    if (examNameLower.contains('quarterly') || examNameLower.contains('quarter')) {
      return 'quarterlyTest';
    }
    if (examNameLower.contains('final')) {
      return 'finalExam';
    }
    if (examNameLower.contains('unit test') || examNameLower.contains('unit-test') || examNameLower.contains('unittest') || examNameLower.contains('daily')) {
      return 'dailyTest';
    }

    // Default to 'monthlyTest' if cannot determine
    return 'monthlyTest';
  }
}
