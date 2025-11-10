import 'package:flutter/material.dart';

import '../../domain/entities/exam_timetable_entry_entity.dart';
import '../pages/exam_timetable_create_wizard_page.dart';

/// Step 4: Add Exam Entries
///
/// Allows users to add individual exam entries (grade + subject + date/time).
/// Provides a form to add entries one by one, with a list of added entries.
class TimetableWizardStep4Entries extends StatefulWidget {
  final WizardData wizardData;
  final Function(List<ExamTimetableEntryEntity>) onEntriesChanged;

  const TimetableWizardStep4Entries({
    required this.wizardData,
    required this.onEntriesChanged,
    super.key,
  });

  @override
  State<TimetableWizardStep4Entries> createState() =>
      _TimetableWizardStep4EntriesState();
}

class _TimetableWizardStep4EntriesState
    extends State<TimetableWizardStep4Entries> {
  late TextEditingController _subjectController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;

  DateTime? _selectedDate;
  String? _selectedGrade;
  String? _selectedSection;

  final _formKey = GlobalKey<FormState>();

  /// Mock subjects - In production, fetch from API
  final List<String> _subjects = [
    'Mathematics',
    'English',
    'Science',
    'Social Studies',
    'Hindi',
    'Computer',
    'Physical Education',
    'Art',
  ];

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController();
    _startTimeController = TextEditingController();
    _endTimeController = TextEditingController();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Text(
              'Add exam entries for the selected grades and sections',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),

            // Add Entry Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New Entry',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),

                      // Grade Selection
                      DropdownButtonFormField<String>(
                        value: _selectedGrade,
                        decoration: InputDecoration(
                          labelText: 'Grade',
                          prefixIcon: const Icon(Icons.grade),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: widget.wizardData.selectedGrades
                            .map((g) => DropdownMenuItem(
                                  value: g.gradeId,
                                  child: Text(g.gradeName),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedGrade = value;
                            _selectedSection = null;
                          });
                        },
                        validator: (value) => value == null
                            ? 'Please select a grade'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Section Selection
                      if (_selectedGrade != null)
                        DropdownButtonFormField<String>(
                          value: _selectedSection,
                          decoration: InputDecoration(
                            labelText: 'Section',
                            prefixIcon: const Icon(Icons.layers),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: _getSelectedGradeSections()
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text('Section $s'),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedSection = value;
                            });
                          },
                          validator: (value) => value == null
                              ? 'Please select a section'
                              : null,
                        ),
                      const SizedBox(height: 12),

                      // Subject Selection
                      DropdownButtonFormField<String>(
                        value: _subjectController.text.isEmpty
                            ? null
                            : _subjectController.text,
                        decoration: InputDecoration(
                          labelText: 'Subject',
                          prefixIcon: const Icon(Icons.book),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: _subjects
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            _subjectController.text = value;
                          }
                        },
                        validator: (value) => value == null
                            ? 'Please select a subject'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Exam Date
                      GestureDetector(
                        onTap: _selectDate,
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Exam Date',
                              hintText: 'Select date',
                              prefixIcon: const Icon(Icons.calendar_today),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            controller: TextEditingController(
                              text: _selectedDate != null
                                  ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                  : '',
                            ),
                            validator: (value) => _selectedDate == null
                                ? 'Please select a date'
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Start Time
                      TextFormField(
                        controller: _startTimeController,
                        decoration: InputDecoration(
                          labelText: 'Start Time (HH:MM)',
                          hintText: '09:00',
                          prefixIcon: const Icon(Icons.schedule),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Start time is required';
                          }
                          if (!_isValidTime(value!)) {
                            return 'Format should be HH:MM';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // End Time
                      TextFormField(
                        controller: _endTimeController,
                        decoration: InputDecoration(
                          labelText: 'End Time (HH:MM)',
                          hintText: '11:00',
                          prefixIcon: const Icon(Icons.schedule),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'End time is required';
                          }
                          if (!_isValidTime(value!)) {
                            return 'Format should be HH:MM';
                          }
                          if (!_isEndTimeAfterStartTime()) {
                            return 'End time must be after start time';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Add button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _addEntry,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Entry'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Added entries table
            if (widget.wizardData.entries.isNotEmpty) ...[
              Text(
                'Added Entries (${widget.wizardData.entries.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              _buildEntriesSmartTable(context),
            ],
          ],
        ),
      ),
    );
  }

  /// Build smart table for displaying entries
  Widget _buildEntriesSmartTable(BuildContext context) {
    final entries = widget.wizardData.entries;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const <DataColumn>[
          DataColumn(label: Text('Grade')),
          DataColumn(label: Text('Section')),
          DataColumn(label: Text('Subject')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Time')),
          DataColumn(label: Text('Duration')),
          DataColumn(label: Text('Action')),
        ],
        rows: entries.map((entry) {
          return DataRow(
            cells: <DataCell>[
              DataCell(Text(entry.gradeId)),
              DataCell(Text(entry.section)),
              DataCell(Text(entry.subjectId, overflow: TextOverflow.ellipsis)),
              DataCell(Text(entry.examDateDisplay, style: const TextStyle(fontSize: 12))),
              DataCell(
                Text(
                  entry.scheduleDisplay,
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DataCell(Text('${entry.durationMinutes} min')),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  tooltip: 'Delete entry',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => _removeEntry(entry),
                ),
              ),
            ],
          );
        }).toList(),
        headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
        dataRowColor: WidgetStateProperty.all(Colors.grey[50]),
        headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        dataTextStyle: const TextStyle(fontSize: 11),
        border: TableBorder(
          borderRadius: BorderRadius.circular(4),
          horizontalInside: BorderSide(color: Colors.grey[300]!),
          verticalInside: BorderSide(color: Colors.grey[300]!),
        ),
      ),
    );
  }

  /// Add new entry
  void _addEntry() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final now = DateTime.now();
    final startDuration = _parseTime(_startTimeController.text);
    final endDuration = _parseTime(_endTimeController.text);
    final durationMinutes = endDuration.inMinutes - startDuration.inMinutes;

    final entry = ExamTimetableEntryEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tenantId: widget.wizardData.tenantId,
      timetableId: '', // Will be set when timetable is created
      gradeId: _selectedGrade!,
      subjectId: _subjectController.text,
      section: _selectedSection!,
      examDate: _selectedDate!,
      startTime: startDuration,
      endTime: endDuration,
      durationMinutes: durationMinutes,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    setState(() {
      widget.wizardData.entries.add(entry);
      _clearForm();
    });

    widget.onEntriesChanged(widget.wizardData.entries);
  }

  /// Remove entry
  void _removeEntry(ExamTimetableEntryEntity entry) {
    setState(() {
      widget.wizardData.entries.removeWhere((e) => e.id == entry.id);
    });
    widget.onEntriesChanged(widget.wizardData.entries);
  }

  /// Select date
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// Clear form
  void _clearForm() {
    _subjectController.clear();
    _startTimeController.clear();
    _endTimeController.clear();
    _selectedGrade = null;
    _selectedSection = null;
    _selectedDate = null;
  }

  /// Get sections for selected grade
  List<String> _getSelectedGradeSections() {
    final grade = widget.wizardData.selectedGrades
        .firstWhere((g) => g.gradeId == _selectedGrade);
    return grade.sections;
  }

  /// Parse time string to Duration
  Duration _parseTime(String time) {
    final parts = time.split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    return Duration(hours: hours, minutes: minutes);
  }

  /// Check if time format is valid
  bool _isValidTime(String time) {
    final regex = RegExp(r'^\d{2}:\d{2}$');
    if (!regex.hasMatch(time)) return false;
    final parts = time.split(':');
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    return hours != null && minutes != null && hours >= 0 && hours < 24 && minutes >= 0 && minutes < 60;
  }

  /// Check if end time is after start time
  bool _isEndTimeAfterStartTime() {
    if (_startTimeController.text.isEmpty ||
        _endTimeController.text.isEmpty) {
      return true;
    }
    final startDuration = _parseTime(_startTimeController.text);
    final endDuration = _parseTime(_endTimeController.text);
    return endDuration.inMinutes > startDuration.inMinutes;
  }
}
