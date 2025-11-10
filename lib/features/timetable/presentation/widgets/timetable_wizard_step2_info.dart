import 'package:flutter/material.dart';

import '../pages/exam_timetable_create_wizard_page.dart';

/// Step 2: Timetable Information
///
/// Collects basic information about the timetable:
/// - Exam name
/// - Exam type
/// - Academic year
class TimetableWizardStep2Info extends StatefulWidget {
  final WizardData wizardData;
  final Function(String examName, String examType, String academicYear)
      onDataChanged;

  const TimetableWizardStep2Info({
    required this.wizardData,
    required this.onDataChanged,
    super.key,
  });

  @override
  State<TimetableWizardStep2Info> createState() =>
      _TimetableWizardStep2InfoState();
}

class _TimetableWizardStep2InfoState extends State<TimetableWizardStep2Info> {
  late TextEditingController _examNameController;
  late TextEditingController _examTypeController;
  late TextEditingController _academicYearController;

  final _formKey = GlobalKey<FormState>();

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
    _examNameController =
        TextEditingController(text: widget.wizardData.examName);
    _examTypeController =
        TextEditingController(text: widget.wizardData.examType);
    _academicYearController =
        TextEditingController(text: widget.wizardData.academicYear);
  }

  @override
  void dispose() {
    _examNameController.dispose();
    _examTypeController.dispose();
    _academicYearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instructions
              Text(
                'Enter the timetable details',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 24),

              // Exam Name
              TextFormField(
                controller: _examNameController,
                decoration: InputDecoration(
                  labelText: 'Exam Name',
                  hintText: 'e.g., Mid-term Examination 2025',
                  prefixIcon: const Icon(Icons.edit),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Exam name is required';
                  }
                  return null;
                },
                onChanged: (value) {
                  _notifyChanges();
                },
              ),
              const SizedBox(height: 20),

              // Exam Type
              DropdownButtonFormField<String>(
                value: _examTypeController.text.isEmpty
                    ? null
                    : _examTypeController.text,
                decoration: InputDecoration(
                  labelText: 'Exam Type',
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                    _notifyChanges();
                  }
                },
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Exam type is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Academic Year
              TextFormField(
                controller: _academicYearController,
                decoration: InputDecoration(
                  labelText: 'Academic Year',
                  hintText: 'e.g., 2025-2026',
                  prefixIcon: const Icon(Icons.calendar_month),
                  helperText: 'Format: YYYY-YYYY (e.g., 2025-2026)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Academic year is required';
                  }
                  // Basic format validation
                  final regex = RegExp(r'^\d{4}-\d{4}$');
                  if (!regex.hasMatch(value!)) {
                    return 'Format should be YYYY-YYYY';
                  }
                  return null;
                },
                onChanged: (value) {
                  _notifyChanges();
                },
              ),
              const SizedBox(height: 24),

              // Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Summary',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow('Exam Name', _examNameController.text),
                    _buildSummaryRow('Type', _examTypeController.text),
                    _buildSummaryRow(
                        'Academic Year', _academicYearController.text),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build summary row
  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          Text(
            value.isEmpty ? '—' : value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  /// Notify parent of changes
  void _notifyChanges() {
    widget.onDataChanged(
      _examNameController.text,
      _examTypeController.text,
      _academicYearController.text,
    );
  }
}
