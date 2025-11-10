import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/exam_calendar.dart';

/// Abstract interface for exam calendar remote data operations
abstract class ExamCalendarRemoteDataSource {
  /// Fetch all exams in the calendar for a tenant
  Future<List<ExamCalendar>> getExamCalendars({
    required String tenantId,
    String? academicYear,
    bool activeOnly = true,
    bool sortByMonth = true,
  });

  /// Fetch a single exam calendar by ID
  Future<ExamCalendar?> getExamCalendarById(String id);

  /// Fetch exam calendar by name
  Future<ExamCalendar?> getExamCalendarByName({
    required String tenantId,
    required String examName,
  });

  /// Create a new exam in the calendar
  Future<ExamCalendar> createExamCalendar(ExamCalendar calendar);

  /// Update an existing exam calendar
  Future<void> updateExamCalendar(ExamCalendar calendar);

  /// Soft delete an exam (set is_active = false)
  Future<void> deleteExamCalendar(String id);

  /// Get exams for a specific month
  Future<List<ExamCalendar>> getExamsForMonth({
    required String tenantId,
    required int monthNumber,
    bool activeOnly = true,
  });

  /// Get upcoming exams (planned_start_date is in future)
  Future<List<ExamCalendar>> getUpcomingExams({
    required String tenantId,
    bool activeOnly = true,
  });

  /// Check if exam name already exists
  Future<bool> examNameExists({
    required String tenantId,
    required String examName,
  });
}

/// Implementation using Supabase
class ExamCalendarRemoteDataSourceImpl implements ExamCalendarRemoteDataSource {
  final SupabaseClient supabaseClient;

  ExamCalendarRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<ExamCalendar>> getExamCalendars({
    required String tenantId,
    String? academicYear,
    bool activeOnly = true,
    bool sortByMonth = true,
  }) async {
    try {
      print('[ExamCalendarRemoteDataSource] Fetching exam calendars...');
      print('[ExamCalendarRemoteDataSource] TenantId: $tenantId');
      print('[ExamCalendarRemoteDataSource] AcademicYear: $academicYear');
      print('[ExamCalendarRemoteDataSource] ActiveOnly: $activeOnly');

      var query = supabaseClient
          .from('exam_calendar')
          .select()
          .eq('tenant_id', tenantId);

      if (academicYear != null) {
        // exam_calendar table doesn't have academic_year, but we can filter by date range
        // For now, just get all and filter by activeOnly
        print('[ExamCalendarRemoteDataSource] Filtering by academic year (not implemented yet)');
      }

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await (sortByMonth
          ? query.order('month_number', ascending: true)
          : query);

      print('[ExamCalendarRemoteDataSource] Successfully fetched ${response.length} calendars');

      final calendars = List<ExamCalendar>.from(
        response.map((json) => ExamCalendar.fromJson(json as Map<String, dynamic>)),
      );

      return calendars;
    } catch (e) {
      print('[ExamCalendarRemoteDataSource] ERROR fetching calendars: $e');
      rethrow;
    }
  }

  @override
  Future<ExamCalendar?> getExamCalendarById(String id) async {
    try {
      final response = await supabaseClient
          .from('exam_calendar')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      return ExamCalendar.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ExamCalendar?> getExamCalendarByName({
    required String tenantId,
    required String examName,
  }) async {
    try {
      final response = await supabaseClient
          .from('exam_calendar')
          .select()
          .eq('tenant_id', tenantId)
          .eq('exam_name', examName)
          .maybeSingle();

      if (response == null) return null;

      return ExamCalendar.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ExamCalendar> createExamCalendar(ExamCalendar calendar) async {
    try {
      print('[ExamCalendarRemoteDataSource] Creating exam calendar...');
      print('[ExamCalendarRemoteDataSource] Calendar: ${calendar.examName}');
      print('[ExamCalendarRemoteDataSource] Calendar ID: ${calendar.id}');

      final jsonData = calendar.toJson();
      print('[ExamCalendarRemoteDataSource] JSON being sent: $jsonData');

      final response = await supabaseClient
          .from('exam_calendar')
          .insert(jsonData)
          .select()
          .single();

      print('[ExamCalendarRemoteDataSource] Response: $response');
      print('[ExamCalendarRemoteDataSource] Calendar created successfully with ID: ${response['id']}');
      return ExamCalendar.fromJson(response as Map<String, dynamic>);
    } catch (e, stackTrace) {
      print('[ExamCalendarRemoteDataSource] ERROR creating calendar: $e');
      print('[ExamCalendarRemoteDataSource] StackTrace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> updateExamCalendar(ExamCalendar calendar) async {
    try {
      print('[ExamCalendarRemoteDataSource] Updating exam calendar with ID: ${calendar.id}');
      await supabaseClient
          .from('exam_calendar')
          .update(calendar.toJson())
          .eq('id', calendar.id);
      print('[ExamCalendarRemoteDataSource] Calendar updated successfully');
    } catch (e) {
      print('[ExamCalendarRemoteDataSource] ERROR updating calendar: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteExamCalendar(String id) async {
    try {
      print('[ExamCalendarRemoteDataSource] Deleting exam calendar with ID: $id');
      await supabaseClient
          .from('exam_calendar')
          .update({'is_active': false})
          .eq('id', id);
      print('[ExamCalendarRemoteDataSource] Calendar deleted successfully');
    } catch (e) {
      print('[ExamCalendarRemoteDataSource] ERROR deleting calendar: $e');
      rethrow;
    }
  }

  @override
  Future<List<ExamCalendar>> getExamsForMonth({
    required String tenantId,
    required int monthNumber,
    bool activeOnly = true,
  }) async {
    try {
      var query = supabaseClient
          .from('exam_calendar')
          .select()
          .eq('tenant_id', tenantId)
          .eq('month_number', monthNumber);

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query.order('display_order', ascending: true);

      return List<ExamCalendar>.from(
        response.map((json) => ExamCalendar.fromJson(json as Map<String, dynamic>)),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<ExamCalendar>> getUpcomingExams({
    required String tenantId,
    bool activeOnly = true,
  }) async {
    try {
      var query = supabaseClient
          .from('exam_calendar')
          .select()
          .eq('tenant_id', tenantId)
          .gte('planned_start_date', DateTime.now().toIso8601String());

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query.order('planned_start_date', ascending: true);

      return List<ExamCalendar>.from(
        response.map((json) => ExamCalendar.fromJson(json as Map<String, dynamic>)),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> examNameExists({
    required String tenantId,
    required String examName,
  }) async {
    try {
      final response = await supabaseClient
          .from('exam_calendar')
          .select('id')
          .eq('tenant_id', tenantId)
          .eq('exam_name', examName)
          .eq('is_active', true);

      return response.isNotEmpty;
    } catch (e) {
      rethrow;
    }
  }
}
