import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/exam_timetable_bloc.dart';
import '../bloc/exam_timetable_event.dart';
import '../bloc/exam_timetable_state.dart';
import 'exam_timetable_wizard_page.dart';

/// Exam Timetable Edit Page
///
/// Handles both creating new timetables and editing existing ones.
/// For new timetables: uses wizard flow with optional calendar ID
/// For existing timetables: loads the timetable and allows editing
class ExamTimetableEditPage extends StatefulWidget {
  final String tenantId;
  final String createdBy;
  final String? examCalendarId;
  final String? timetableId;

  const ExamTimetableEditPage({
    required this.tenantId,
    required this.createdBy,
    this.examCalendarId,
    this.timetableId,
    super.key,
  });

  @override
  State<ExamTimetableEditPage> createState() => _ExamTimetableEditPageState();
}

class _ExamTimetableEditPageState extends State<ExamTimetableEditPage> {
  @override
  void initState() {
    super.initState();
    // If editing an existing timetable, load it
    if (widget.timetableId != null) {
      context.read<ExamTimetableBloc>().add(
            GetExamTimetableByIdEvent(
              timetableId: widget.timetableId!,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    // If creating a new timetable, use the wizard
    if (widget.timetableId == null) {
      return ExamTimetableWizardPage(
        tenantId: widget.tenantId,
        userId: widget.createdBy,
        academicYear: '', // Will be set from UserStateService in wizard
      );
    }

    // If editing, show loading or edit interface
    return BlocBuilder<ExamTimetableBloc, ExamTimetableState>(
      builder: (context, state) {
        if (state is ExamTimetableLoading) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Edit Exam Timetable'),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (state is ExamTimetableError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Edit Exam Timetable'),
            ),
            body: Center(
              child: Text('Error: ${state.message}'),
            ),
          );
        }

        if (state is ExamTimetableLoaded) {
          // For now, redirect to the wizard for editing
          // This can be replaced with a dedicated edit UI
          return ExamTimetableWizardPage(
            tenantId: widget.tenantId,
            userId: widget.createdBy,
            academicYear: '', // Will be set from UserStateService in wizard
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Edit Exam Timetable'),
          ),
          body: const Center(
            child: Text('Unable to load timetable'),
          ),
        );
      },
    );
  }
}
