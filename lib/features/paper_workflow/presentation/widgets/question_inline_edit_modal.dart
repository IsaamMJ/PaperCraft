import 'package:flutter/material.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/question_entity.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';

class QuestionInlineEditModal extends StatefulWidget {
  final Question question;
  final int questionIndex;
  final String sectionName;
  final Function(String updatedText, List<String>? updatedOptions, double updatedMarks, String? updatedCorrectAnswer) onSave;
  final VoidCallback onCancel;

  const QuestionInlineEditModal({
    super.key,
    required this.question,
    required this.questionIndex,
    required this.sectionName,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<QuestionInlineEditModal> createState() => _QuestionInlineEditModalState();
}

class _QuestionInlineEditModalState extends State<QuestionInlineEditModal> {
  late TextEditingController _questionTextController;
  late TextEditingController _marksController;
  late TextEditingController _correctAnswerController;
  late List<TextEditingController> _optionControllers;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _questionTextController = TextEditingController(text: widget.question.text);
    _marksController = TextEditingController(text: widget.question.marks.toString());
    _correctAnswerController = TextEditingController(text: widget.question.correctAnswer ?? '');

    // Initialize option controllers
    _optionControllers = (widget.question.options ?? [])
        .map((option) => TextEditingController(text: option))
        .toList();
  }

  @override
  void dispose() {
    _questionTextController.dispose();
    _marksController.dispose();
    _correctAnswerController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
  }

  void _saveChanges() {
    final updatedText = _questionTextController.text.trim();
    final updatedMarksStr = _marksController.text.trim();

    // Validation
    if (updatedText.isEmpty) {
      _showErrorSnackBar('Question text cannot be empty');
      return;
    }

    final updatedMarks = double.tryParse(updatedMarksStr);
    if (updatedMarks == null || updatedMarks <= 0) {
      _showErrorSnackBar('Marks must be a positive number');
      return;
    }

    // Get updated options
    List<String>? updatedOptions;
    if (_optionControllers.isNotEmpty) {
      updatedOptions = _optionControllers
          .map((ctrl) => ctrl.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      if (updatedOptions.isEmpty && widget.question.options != null && widget.question.options!.isNotEmpty) {
        // If options existed before, at least one must remain
        _showErrorSnackBar('At least one option is required');
        return;
      }
    }

    setState(() => _isSaving = true);

    // Call the save callback
    widget.onSave(
      updatedText,
      updatedOptions,
      updatedMarks,
      _correctAnswerController.text.trim().isEmpty ? null : _correctAnswerController.text.trim(),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 48,
        vertical: isMobile ? 24 : 48,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(UIConstants.paddingMedium),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(UIConstants.radiusLarge),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Edit Question ${widget.questionIndex + 1}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onCancel,
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(UIConstants.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question Text
                    _buildLabel('Question Text'),
                    SizedBox(height: UIConstants.spacing8),
                    TextField(
                      controller: _questionTextController,
                      maxLines: 4,
                      minLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Enter the question text',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.all(UIConstants.paddingSmall),
                      ),
                    ),
                    SizedBox(height: UIConstants.spacing16),

                    // Marks
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Marks'),
                              SizedBox(height: UIConstants.spacing8),
                              TextField(
                                controller: _marksController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  hintText: 'Marks',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                                    borderSide: BorderSide(color: AppColors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                                    borderSide: BorderSide(color: AppColors.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                                  ),
                                  contentPadding: const EdgeInsets.all(UIConstants.paddingSmall),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: UIConstants.spacing16),

                    // Options (if MCQ or fill_blanks)
                    if (widget.question.type == 'multiple_choice' || widget.question.type == 'fill_blanks')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel(
                            widget.question.type == 'fill_blanks' ? 'Word Bank' : 'Options',
                          ),
                          SizedBox(height: UIConstants.spacing8),
                          ..._optionControllers.asMap().entries.map((e) {
                            final index = e.key;
                            final controller = e.value;
                            final label = String.fromCharCode(65 + index);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary10,
                                      borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                                    ),
                                    child: Center(
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: UIConstants.spacing8),
                                  Expanded(
                                    child: TextField(
                                      controller: controller,
                                      decoration: InputDecoration(
                                        hintText: 'Enter option',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                                          borderSide: BorderSide(color: AppColors.border),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                                          borderSide: BorderSide(color: AppColors.border),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                                        ),
                                        contentPadding: const EdgeInsets.all(UIConstants.paddingSmall),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: UIConstants.spacing8),
                                  if (_optionControllers.length > 2)
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, color: AppColors.error),
                                      onPressed: () => _removeOption(index),
                                    ),
                                ],
                              ),
                            );
                          }),
                          SizedBox(height: UIConstants.spacing8),
                          TextButton.icon(
                            onPressed: _addOption,
                            icon: const Icon(Icons.add),
                            label: Text(
                              widget.question.type == 'fill_blanks'
                                  ? 'Add Word'
                                  : 'Add Option',
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                          ),
                          SizedBox(height: UIConstants.spacing16),
                        ],
                      ),

                    // Correct Answer (if MCQ)
                    if (widget.question.type == 'multiple_choice')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Correct Answer'),
                          SizedBox(height: UIConstants.spacing8),
                          TextField(
                            controller: _correctAnswerController,
                            decoration: InputDecoration(
                              hintText: 'e.g., A',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                                borderSide: BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                                borderSide: BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                                borderSide: BorderSide(color: AppColors.primary, width: 2),
                              ),
                              contentPadding: const EdgeInsets.all(UIConstants.paddingSmall),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.all(UIConstants.paddingMedium),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : widget.onCancel,
                      child: const Text('Cancel'),
                    ),
                    SizedBox(width: UIConstants.spacing12),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveChanges,
                      icon: _isSaving
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}
