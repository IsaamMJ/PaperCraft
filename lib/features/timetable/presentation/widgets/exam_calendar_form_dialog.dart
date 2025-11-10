import 'package:flutter/material.dart';

import '../../domain/entities/exam_calendar_entity.dart';

/// Exam Calendar Form Dialog
///
/// Dialog for creating and editing exam calendars.
/// Validates:
/// - Exam name (required)
/// - Exam type (required)
/// - Date ranges (start < end)
/// - Submission deadline
///
/// Emits the completed ExamCalendarEntity via onSubmit callback.
class ExamCalendarFormDialog extends StatefulWidget {
  final String tenantId;
  final ExamCalendarEntity? initialCalendar;
  final Function(ExamCalendarEntity) onSubmit;

  const ExamCalendarFormDialog({
    required this.tenantId,
    this.initialCalendar,
    required this.onSubmit,
    super.key,
  });

  @override
  State<ExamCalendarFormDialog> createState() => _ExamCalendarFormDialogState();
}

class _ExamCalendarFormDialogState extends State<ExamCalendarFormDialog> {
  late final TextEditingController _examNameController;
  late final TextEditingController _examTypeController;
  late final TextEditingController _monthController;

  DateTime? _plannedStartDate;
  DateTime? _plannedEndDate;
  DateTime? _paperSubmissionDeadline;

  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  final List<String> _examTypes = [
    'Unit Test',
    'Mid Term',
    'Final',
    'Semester',
    'Annual',
    'Mock',
  ];

  @override
  void initState() {
    super.initState();
    _examNameController = TextEditingController(
      text: widget.initialCalendar?.examName ?? '',
    );
    _examTypeController = TextEditingController(
      text: widget.initialCalendar?.examType ?? '',
    );
    _monthController = TextEditingController(
      text: widget.initialCalendar?.monthNumber.toString() ?? '',
    );

    _plannedStartDate = widget.initialCalendar?.plannedStartDate;
    _plannedEndDate = widget.initialCalendar?.plannedEndDate;
    _paperSubmissionDeadline =
        widget.initialCalendar?.paperSubmissionDeadline;
  }

  @override
  void dispose() {
    _examNameController.dispose();
    _examTypeController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialCalendar != null
            ? 'Edit Exam Calendar'
            : 'Create Exam Calendar',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Exam Name
              TextFormField(
                controller: _examNameController,
                decoration: const InputDecoration(
                  labelText: 'Exam Name',
                  hintText: 'e.g., Unit Test - November 2025',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Exam name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Exam Type
              DropdownButtonFormField<String>(
                value: _examTypeController.text.isEmpty
                    ? null
                    : _examTypeController.text,
                decoration: const InputDecoration(
                  labelText: 'Exam Type',
                  border: OutlineInputBorder(),
                ),
                items: _examTypes
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    _examTypeController.text = value;
                  }
                },
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Exam type is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Month Number
              TextFormField(
                controller: _monthController,
                decoration: const InputDecoration(
                  labelText: 'Month Number (1-12)',
                  hintText: '11',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Month is required';
                  }
                  final month = int.tryParse(value!);
                  if (month == null || month < 1 || month > 12) {
                    return 'Please enter a valid month (1-12)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Start Date
              GestureDetector(
                onTap: _isSubmitting ? null : () => _selectStartDate(context),
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Planned Start Date',
                      hintText: 'Select date',
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    controller: TextEditingController(
                      text: _plannedStartDate != null
                          ? '${_plannedStartDate!.day}/${_plannedStartDate!.month}/${_plannedStartDate!.year}'
                          : '',
                    ),
                    validator: (value) {
                      if (_plannedStartDate == null) {
                        return 'Start date is required';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // End Date
              GestureDetector(
                onTap: _isSubmitting ? null : () => _selectEndDate(context),
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Planned End Date',
                      hintText: 'Select date',
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    controller: TextEditingController(
                      text: _plannedEndDate != null
                          ? '${_plannedEndDate!.day}/${_plannedEndDate!.month}/${_plannedEndDate!.year}'
                          : '',
                    ),
                    validator: (value) {
                      if (_plannedEndDate == null) {
                        return 'End date is required';
                      }
                      if (_plannedStartDate != null &&
                          _plannedEndDate!.isBefore(_plannedStartDate!)) {
                        return 'End date must be on or after start date';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Paper Submission Deadline
              GestureDetector(
                onTap: _isSubmitting ? null : () => _selectSubmissionDeadline(context),
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Paper Submission Deadline',
                      hintText: 'Select date',
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    controller: TextEditingController(
                      text: _paperSubmissionDeadline != null
                          ? '${_paperSubmissionDeadline!.day}/${_paperSubmissionDeadline!.month}/${_paperSubmissionDeadline!.year}'
                          : '',
                    ),
                    validator: (value) {
                      if (_paperSubmissionDeadline == null) {
                        return 'Submission deadline is required';
                      }
                      if (_plannedStartDate != null &&
                          _paperSubmissionDeadline!
                              .isBefore(_plannedStartDate!)) {
                        return 'Deadline must be on or after start date';
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitForm,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  /// Select start date
  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _plannedStartDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _plannedStartDate = picked;
      });
    }
  }

  /// Select end date
  Future<void> _selectEndDate(BuildContext context) async {
    final defaultDate = _plannedStartDate?.add(const Duration(days: 30)) ??
        DateTime.now().add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: _plannedEndDate ?? defaultDate,
      firstDate: _plannedStartDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _plannedEndDate = picked;
      });
    }
  }

  /// Select submission deadline
  Future<void> _selectSubmissionDeadline(BuildContext context) async {
    final defaultDate = _plannedStartDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _paperSubmissionDeadline ?? defaultDate,
      firstDate: _plannedStartDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _paperSubmissionDeadline = picked;
      });
    }
  }

  /// Submit form
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final month = int.parse(_monthController.text);

      final calendar = ExamCalendarEntity(
        id: widget.initialCalendar?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        tenantId: widget.tenantId,
        examName: _examNameController.text,
        examType: _examTypeController.text,
        monthNumber: month,
        plannedStartDate: _plannedStartDate!,
        plannedEndDate: _plannedEndDate!,
        paperSubmissionDeadline: _paperSubmissionDeadline!,
        displayOrder: widget.initialCalendar?.displayOrder ?? 0,
        metadata: widget.initialCalendar?.metadata ?? {},
        isActive: widget.initialCalendar?.isActive ?? true,
        createdAt: widget.initialCalendar?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      widget.onSubmit(calendar);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
