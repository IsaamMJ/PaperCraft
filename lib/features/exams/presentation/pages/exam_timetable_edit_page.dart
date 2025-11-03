import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/exam_timetable_bloc.dart';
import '../bloc/exam_timetable_event.dart';
import '../bloc/exam_timetable_state.dart';
import '../../domain/entities/exam_timetable.dart';

/// Page to create and edit exam timetables
///
/// Allows admins to:
/// - Create new timetable
/// - Add entries (grade/subject/section exam slots)
/// - Edit entry times and dates
/// - Validate timetable before publishing
/// - Publish and trigger paper auto-creation
class ExamTimetableEditPage extends StatefulWidget {
  final String tenantId;
  final String createdBy;
  final String? examCalendarId;
  final String? timetableId; // If editing existing timetable

  const ExamTimetableEditPage({
    Key? key,
    required this.tenantId,
    required this.createdBy,
    this.examCalendarId,
    this.timetableId,
  }) : super(key: key);

  @override
  State<ExamTimetableEditPage> createState() => _ExamTimetableEditPageState();
}

class _ExamTimetableEditPageState extends State<ExamTimetableEditPage> {
  late TextEditingController _examNameController;
  late TextEditingController _gradeIdController;
  late TextEditingController _subjectIdController;
  late TextEditingController _sectionController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;

  DateTime? _selectedExamDate;
  ExamTimetable? _currentTimetable;

  @override
  void initState() {
    super.initState();
    _examNameController = TextEditingController();
    _gradeIdController = TextEditingController();
    _subjectIdController = TextEditingController();
    _sectionController = TextEditingController();
    _startTimeController = TextEditingController();
    _endTimeController = TextEditingController();

    // If editing, load existing timetable
    if (widget.timetableId != null) {
      // TODO: Load existing timetable details
    }
  }

  @override
  void dispose() {
    _examNameController.dispose();
    _gradeIdController.dispose();
    _subjectIdController.dispose();
    _sectionController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context, TextEditingController controller) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      controller.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedExamDate = picked;
      });
    }
  }

  void _showAddEntryDialog() {
    _gradeIdController.clear();
    _subjectIdController.clear();
    _sectionController.clear();
    _startTimeController.clear();
    _endTimeController.clear();
    _selectedExamDate = null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Timetable Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _gradeIdController,
                  decoration: const InputDecoration(
                    labelText: 'Grade ID',
                    hintText: 'e.g., Grade 5',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _subjectIdController,
                  decoration: const InputDecoration(
                    labelText: 'Subject ID',
                    hintText: 'e.g., Maths',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _sectionController,
                  decoration: const InputDecoration(
                    labelText: 'Section',
                    hintText: 'A, B, C, etc.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // Exam date picker
                ListTile(
                  title: const Text('Exam Date'),
                  subtitle: Text(
                    _selectedExamDate != null
                        ? DateFormat('MMM d, yyyy').format(_selectedExamDate!)
                        : 'Select date',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectDate(context),
                ),
                const SizedBox(height: 8),
                // Start time picker
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _startTimeController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Start Time',
                          hintText: 'HH:mm',
                          border: OutlineInputBorder(),
                        ),
                        onTap: () => _selectTime(context, _startTimeController),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _endTimeController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'End Time',
                          hintText: 'HH:mm',
                          border: OutlineInputBorder(),
                        ),
                        onTap: () => _selectTime(context, _endTimeController),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_gradeIdController.text.isEmpty ||
                    _subjectIdController.text.isEmpty ||
                    _sectionController.text.isEmpty ||
                    _selectedExamDate == null ||
                    _startTimeController.text.isEmpty ||
                    _endTimeController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in all fields')),
                  );
                  return;
                }

                // Parse times
                final startParts = _startTimeController.text.split(':');
                final endParts = _endTimeController.text.split(':');
                final startTime = TimeOfDay(
                  hour: int.parse(startParts[0]),
                  minute: int.parse(startParts[1]),
                );
                final endTime = TimeOfDay(
                  hour: int.parse(endParts[0]),
                  minute: int.parse(endParts[1]),
                );

                if (_currentTimetable != null) {
                  context.read<ExamTimetableBloc>().add(
                        AddTimetableEntryEvent(
                          tenantId: widget.tenantId,
                          timetableId: _currentTimetable!.id,
                          gradeId: _gradeIdController.text.trim(),
                          subjectId: _subjectIdController.text.trim(),
                          section: _sectionController.text.trim(),
                          examDate: _selectedExamDate!,
                          startTime: startTime,
                          endTime: endTime,
                        ),
                      );
                }

                Navigator.pop(context);
              },
              child: const Text('Add Entry'),
            ),
          ],
        ),
      ),
    );
  }

  void _validateAndPublish() {
    if (_currentTimetable == null) return;

    // First validate
    context.read<ExamTimetableBloc>().add(
          ValidateTimetableEvent(timetableId: _currentTimetable!.id),
        );

    // Show validation results
    showDialog(
      context: context,
      builder: (context) => BlocBuilder<ExamTimetableBloc, ExamTimetableState>(
        builder: (context, state) {
          if (state is TimetableValidationSuccess) {
            return AlertDialog(
              title: const Text('Validation Passed ✓'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Timetable is ready to publish.'),
                  if (state.warnings.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Warnings:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...state.warnings.map((w) => Text('⚠ $w')),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    context.read<ExamTimetableBloc>().add(
                          PublishTimetableEvent(timetableId: _currentTimetable!.id),
                        );
                    Navigator.pop(context);
                  },
                  child: const Text('Publish'),
                ),
              ],
            );
          } else if (state is TimetableValidationFailed) {
            return AlertDialog(
              title: const Text('Validation Failed'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Please fix the following issues:'),
                  const SizedBox(height: 8),
                  ...state.errors.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text('• $e'),
                  )),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          }

          return const AlertDialog(
            content: CircularProgressIndicator(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Timetable'),
        elevation: 0,
      ),
      body: BlocListener<ExamTimetableBloc, ExamTimetableState>(
        listener: (context, state) {
          if (state is ExamTimetableCreated) {
            setState(() {
              _currentTimetable = state.timetable;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${state.timetable.displayName} created'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is TimetableEntryAdded) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Entry added: ${state.entry.displayName}'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is TimetablePublished) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${state.timetable.displayName} published!'),
                backgroundColor: Colors.green,
              ),
            );
            // Navigate back
            Navigator.pop(context);
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Create timetable section
              if (_currentTimetable == null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Create New Timetable',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _examNameController,
                          decoration: const InputDecoration(
                            labelText: 'Exam Name',
                            hintText: 'e.g., June Monthly Test',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (_examNameController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter exam name'),
                                ),
                              );
                              return;
                            }

                            context.read<ExamTimetableBloc>().add(
                              CreateExamTimetableEvent(
                                tenantId: widget.tenantId,
                                createdBy: widget.createdBy,
                                examCalendarId: widget.examCalendarId,
                                examName: _examNameController.text.trim(),
                                examType: 'custom',
                                academicYear: '2024-2025',
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Timetable'),
                        ),
                      ],
                    ),
                  ),
                ),
              // Timetable details and entries section
              if (_currentTimetable != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _currentTimetable!.displayName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _currentTimetable!.status.toShortString(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                Chip(
                                  label: Text(_currentTimetable!.status.toShortString()),
                                  backgroundColor: Colors.blue.shade100,
                                  labelStyle: const TextStyle(color: Colors.blue),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Entries section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Timetable Entries',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _showAddEntryDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Entry'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    BlocBuilder<ExamTimetableBloc, ExamTimetableState>(
                      builder: (context, state) {
                        if (state is TimetableEntriesLoading) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (state is TimetableEntriesEmpty) {
                          return const Center(
                            child: Text('No entries yet'),
                          );
                        }
                        if (state is TimetableEntriesLoaded) {
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: state.entries.length,
                            itemBuilder: (context, index) {
                              final entry = state.entries[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(entry.displayName),
                                  subtitle: Text(
                                    '${entry.formattedDate} • ${entry.timeRange}',
                                  ),
                                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                                ),
                              );
                            },
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: 24),
                    // Publish button
                    if (_currentTimetable!.isDraft)
                      ElevatedButton.icon(
                        onPressed: _validateAndPublish,
                        icon: const Icon(Icons.publish),
                        label: const Text('Validate & Publish'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
