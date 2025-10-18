// features/catalog/presentation/widgets/add_edit_section_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../domain/entities/paper_section_entity.dart';

/// Dialog for adding or editing a paper section
class AddEditSectionDialog extends StatefulWidget {
  final PaperSectionEntity? section; // null for add, non-null for edit

  const AddEditSectionDialog({
    Key? key,
    this.section,
  }) : super(key: key);

  @override
  State<AddEditSectionDialog> createState() => _AddEditSectionDialogState();
}

class _AddEditSectionDialogState extends State<AddEditSectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _questionsController;
  late TextEditingController _marksController;
  late String _selectedType;

  final List<Map<String, dynamic>> _questionTypes = [
    {'value': 'multiple_choice', 'label': 'Multiple Choice (MCQ)', 'icon': Icons.radio_button_checked},
    {'value': 'short_answer', 'label': 'Short Answer', 'icon': Icons.short_text},
    {'value': 'fill_in_blanks', 'label': 'Fill in the Blanks', 'icon': Icons.edit_note},
    {'value': 'true_false', 'label': 'True/False', 'icon': Icons.toggle_on},
    {'value': 'match_following', 'label': 'Match the Following', 'icon': Icons.compare_arrows},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.section?.name ?? '');
    _questionsController = TextEditingController(
      text: widget.section?.questions.toString() ?? '',
    );
    _marksController = TextEditingController(
      text: widget.section?.marksPerQuestion.toString() ?? '',
    );
    _selectedType = widget.section?.type ?? 'multiple_choice';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _questionsController.dispose();
    _marksController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final questions = int.parse(_questionsController.text);
      final marksPerQuestion = int.parse(_marksController.text);
      final totalMarks = questions * marksPerQuestion;

      // Warn if section marks are very high
      if (totalMarks > 200) {
        _showWarningDialog(
          'High Section Marks',
          'This section will have $totalMarks marks. Are you sure this is correct?',
          () {
            final section = PaperSectionEntity(
              name: _nameController.text.trim(),
              type: _selectedType,
              questions: questions,
              marksPerQuestion: marksPerQuestion,
            );
            Navigator.of(context).pop(section);
          },
        );
        return;
      }

      final section = PaperSectionEntity(
        name: _nameController.text.trim(),
        type: _selectedType,
        questions: questions,
        marksPerQuestion: marksPerQuestion,
      );
      Navigator.of(context).pop(section);
    }
  }

  void _showWarningDialog(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalMarksPreview() {
    final questions = int.tryParse(_questionsController.text) ?? 0;
    final marksPerQuestion = int.tryParse(_marksController.text) ?? 0;
    final totalMarks = questions * marksPerQuestion;
    final isHighMarks = totalMarks > 200;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighMarks ? Colors.orange.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighMarks ? AppColors.warning : Colors.blue.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Marks:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '$questions × $marksPerQuestion = $totalMarks',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isHighMarks ? Colors.orange.shade700 : Colors.blue.shade700,
                ),
              ),
            ],
          ),
          if (isHighMarks) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This section has high marks. Please verify.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.section != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Section' : 'Add Section'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section name
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Section Name',
                  hintText: 'e.g., Part A, Section 1',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter section name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Question type dropdown
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Question Type',
                  border: OutlineInputBorder(),
                ),
                items: _questionTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type['value'],
                    child: Row(
                      children: [
                        Icon(type['icon'], size: 20),
                        const SizedBox(width: 12),
                        Text(type['label']),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Number of questions
              TextFormField(
                controller: _questionsController,
                decoration: const InputDecoration(
                  labelText: 'Number of Questions',
                  hintText: 'e.g., 10',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter number of questions';
                  }
                  final number = int.tryParse(value);
                  if (number == null || number <= 0) {
                    return 'Must be greater than 0';
                  }
                  if (number > 100) {
                    return 'Too many questions (max 100)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Marks per question
              TextFormField(
                controller: _marksController,
                decoration: const InputDecoration(
                  labelText: 'Marks per Question',
                  hintText: 'e.g., 2',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter marks per question';
                  }
                  final number = int.tryParse(value);
                  if (number == null || number <= 0) {
                    return 'Must be greater than 0';
                  }
                  if (number > 100) {
                    return 'Too many marks (max 100 per question)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Preview
              if (_questionsController.text.isNotEmpty &&
                  _marksController.text.isNotEmpty)
                _buildTotalMarksPreview(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
