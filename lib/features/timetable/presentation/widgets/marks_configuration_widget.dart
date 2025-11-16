import 'package:flutter/material.dart';

import '../../domain/entities/mark_config_entity.dart';
import '../../domain/services/grade_range_detection_service.dart';

/// Widget for configuring marks for different grade ranges
///
/// Allows users to:
/// - View auto-detected grade ranges and their default marks
/// - Edit marks for each grade range
/// - Add custom grade ranges
/// - Delete configurations (if more than one exists)
///
/// Usage:
/// ```dart
/// MarksConfigurationWidget(
///   allGrades: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
///   initialConfigs: [],
///   onConfigsChanged: (configs) {
///     // Handle updated configs
///   },
/// )
/// ```
class MarksConfigurationWidget extends StatefulWidget {
  /// All grades available in the school
  final List<int> allGrades;

  /// Initial mark configurations (empty if creating new calendar)
  final List<MarkConfigEntity> initialConfigs;

  /// Callback when configurations change
  final Function(List<MarkConfigEntity>) onConfigsChanged;

  const MarksConfigurationWidget({
    required this.allGrades,
    required this.initialConfigs,
    required this.onConfigsChanged,
    super.key,
  });

  @override
  State<MarksConfigurationWidget> createState() =>
      _MarksConfigurationWidgetState();
}

class _MarksConfigurationWidgetState extends State<MarksConfigurationWidget> {
  late List<MarkConfigEntity> _configs;
  late bool _useAutoDetection;

  @override
  void initState() {
    super.initState();
    _useAutoDetection = widget.initialConfigs.isEmpty;
    _configs = widget.initialConfigs.isEmpty
        ? GradeRangeDetectionService.detectDefaultRanges(widget.allGrades)
        : List.from(widget.initialConfigs);
  }

  void _onConfigsChanged() {
    widget.onConfigsChanged(_configs);
  }

  void _toggleAutoDetection() {
    setState(() {
      _useAutoDetection = !_useAutoDetection;
      if (_useAutoDetection) {
        // Reset to auto-detected values
        _configs =
            GradeRangeDetectionService.detectDefaultRanges(widget.allGrades);
      }
    });
    _onConfigsChanged();
  }

  void _updateMarks(int index, int newMarks) {
    setState(() {
      _configs[index] = _configs[index].copyWith(totalMarks: newMarks);
    });
    _onConfigsChanged();
  }

  void _deleteConfig(int index) {
    if (_configs.length > 1) {
      setState(() {
        _configs.removeAt(index);
      });
      _onConfigsChanged();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mark configuration removed')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one configuration is required')),
      );
    }
  }

  void _addCustomRange() {
    showDialog(
      context: context,
      builder: (context) => _AddCustomRangeDialog(
        existingConfigs: _configs,
        allGrades: widget.allGrades,
        onAdd: (config) {
          setState(() {
            _configs.add(config);
            _configs.sort((a, b) => a.minGrade.compareTo(b.minGrade));
          });
          _onConfigsChanged();
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gaps = GradeRangeDetectionService.findGradeCoverageGaps(
      widget.allGrades,
      _configs,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Mark Configuration',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_useAutoDetection)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Auto-Detected',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Auto-detection toggle
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Use auto-detected grades'),
          subtitle: const Text(
            'System will automatically suggest marks based on grade structure',
          ),
          value: _useAutoDetection,
          onChanged: (_) => _toggleAutoDetection(),
        ),
        const SizedBox(height: 12),

        // Configurations list
        if (_configs.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No mark configurations',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _configs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final config = _configs[index];
              return _MarkConfigCard(
                config: config,
                onMarksChanged: (newMarks) => _updateMarks(index, newMarks),
                onDelete: () => _deleteConfig(index),
                canDelete: _configs.length > 1,
              );
            },
          ),

        const SizedBox(height: 12),

        // Coverage warning
        if (gaps.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Grades ${gaps.join(", ")} not covered. Add a configuration.',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700]),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'All grades covered',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // Add button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: !_useAutoDetection ? _addCustomRange : null,
            icon: const Icon(Icons.add),
            label: const Text('Add Custom Range'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  !_useAutoDetection ? null : Colors.grey[300],
            ),
          ),
        ),
      ],
    );
  }
}

/// Card displaying a single mark configuration
class _MarkConfigCard extends StatefulWidget {
  final MarkConfigEntity config;
  final Function(int) onMarksChanged;
  final VoidCallback onDelete;
  final bool canDelete;

  const _MarkConfigCard({
    required this.config,
    required this.onMarksChanged,
    required this.onDelete,
    required this.canDelete,
  });

  @override
  State<_MarkConfigCard> createState() => _MarkConfigCardState();
}

class _MarkConfigCardState extends State<_MarkConfigCard> {
  late TextEditingController _marksController;

  @override
  void initState() {
    super.initState();
    _marksController = TextEditingController(
      text: widget.config.totalMarks.toString(),
    );
  }

  @override
  void dispose() {
    _marksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grade range header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.config.label != null)
                      Text(
                        widget.config.label!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    Text(
                      'Grades ${widget.config.minGrade}-${widget.config.maxGrade}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                if (widget.canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                    onPressed: widget.onDelete,
                    tooltip: 'Delete',
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Marks input
            SizedBox(
              width: 200,
              child: TextFormField(
                controller: _marksController,
                decoration: const InputDecoration(
                  labelText: 'Total Marks',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final marks = int.tryParse(value);
                  if (marks != null && marks > 0) {
                    widget.onMarksChanged(marks);
                  }
                },
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Required';
                  }
                  final marks = int.tryParse(value!);
                  if (marks == null || marks <= 0) {
                    return 'Must be positive';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for adding custom grade ranges
class _AddCustomRangeDialog extends StatefulWidget {
  final List<MarkConfigEntity> existingConfigs;
  final List<int> allGrades;
  final Function(MarkConfigEntity) onAdd;

  const _AddCustomRangeDialog({
    required this.existingConfigs,
    required this.allGrades,
    required this.onAdd,
  });

  @override
  State<_AddCustomRangeDialog> createState() => _AddCustomRangeDialogState();
}

class _AddCustomRangeDialogState extends State<_AddCustomRangeDialog> {
  late TextEditingController _minGradeController;
  late TextEditingController _maxGradeController;
  late TextEditingController _marksController;
  late TextEditingController _labelController;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _minGradeController = TextEditingController();
    _maxGradeController = TextEditingController();
    _marksController = TextEditingController();
    _labelController = TextEditingController();
  }

  @override
  void dispose() {
    _minGradeController.dispose();
    _maxGradeController.dispose();
    _marksController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Custom Range'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _minGradeController,
                decoration: const InputDecoration(
                  labelText: 'Min Grade',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  final grade = int.tryParse(value!);
                  if (grade == null || grade < 1)
                    return 'Must be >= 1';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxGradeController,
                decoration: const InputDecoration(
                  labelText: 'Max Grade',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  final grade = int.tryParse(value!);
                  if (grade == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _marksController,
                decoration: const InputDecoration(
                  labelText: 'Total Marks',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  final marks = int.tryParse(value!);
                  if (marks == null || marks <= 0)
                    return 'Must be positive';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Label (Optional)',
                  hintText: 'e.g., Advanced',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitForm,
          child: const Text('Add'),
        ),
      ],
    );
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    final minGrade = int.parse(_minGradeController.text);
    final maxGrade = int.parse(_maxGradeController.text);
    final marks = int.parse(_marksController.text);
    final label = _labelController.text.isEmpty ? null : _labelController.text;

    if (minGrade > maxGrade) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Min grade must be <= Max grade')),
      );
      return;
    }

    final config = MarkConfigEntity(
      minGrade: minGrade,
      maxGrade: maxGrade,
      totalMarks: marks,
      label: label,
    );

    widget.onAdd(config);
  }
}
