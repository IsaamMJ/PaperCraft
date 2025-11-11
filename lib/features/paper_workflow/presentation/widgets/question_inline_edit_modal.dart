import 'package:flutter/material.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/question_entity.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';

class QuestionInlineEditModal extends StatefulWidget {
  final Question question;
  final int questionIndex;
  final String sectionName;
  final Function(String updatedText, List<String>? updatedOptions) onSave;
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
  late List<TextEditingController> _optionControllers;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    print('🔍 [InlineEditModal] Opened edit modal for question ${widget.questionIndex + 1} in section "${widget.sectionName}"');
    print('   - Original text: "${widget.question.text}"');
    print('   - Question type: "${widget.question.type}"');
    print('   - Has options: ${widget.question.options?.isNotEmpty ?? false}');
    print('   - Options count: ${widget.question.options?.length ?? 0}');

    _questionTextController = TextEditingController(text: widget.question.text);

    // Initialize option controllers
    _optionControllers = (widget.question.options ?? [])
        .map((option) => TextEditingController(text: option))
        .toList();
  }

  @override
  void dispose() {
    print('🔍 [InlineEditModal] Disposing edit modal for question ${widget.questionIndex + 1}');
    _questionTextController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    print('➕ [InlineEditModal] Added new option (total: ${_optionControllers.length + 1})');
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    print('➖ [InlineEditModal] Removed option at index $index (total before: ${_optionControllers.length})');
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
  }

  void _saveChanges() {
    print('💾 [InlineEditModal] Save button clicked for question ${widget.questionIndex + 1}');

    final updatedText = _questionTextController.text.trim();
    print('   - Updated text length: ${updatedText.length}');
    print('   - Text changed: ${updatedText != widget.question.text}');

    // Validation
    if (updatedText.isEmpty) {
      print('   ❌ Validation failed: Question text is empty');
      _showErrorSnackBar('Question text cannot be empty');
      return;
    }

    // Get updated options
    List<String>? updatedOptions;
    if (_optionControllers.isNotEmpty) {
      updatedOptions = _optionControllers
          .map((ctrl) => ctrl.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      print('   - Options count: ${updatedOptions.length}');
      if (updatedOptions.isNotEmpty) {
        updatedOptions.asMap().forEach((index, option) {
          print('     Option ${String.fromCharCode(65 + index)}: "$option"');
        });
      }

      if (updatedOptions.isEmpty && widget.question.options != null && widget.question.options!.isNotEmpty) {
        // If options existed before, at least one must remain
        print('   ❌ Validation failed: At least one option is required');
        _showErrorSnackBar('At least one option is required');
        return;
      }
    }

    print('   ✅ Validation passed - proceeding to save');
    setState(() => _isSaving = true);

    // Call the save callback
    print('   📤 Calling onSave callback with:');
    print('      - Updated text: "${updatedText.substring(0, updatedText.length > 50 ? 50 : updatedText.length)}${updatedText.length > 50 ? '...' : ''}"');
    print('      - Updated options: ${updatedOptions?.length ?? 0} items');

    widget.onSave(updatedText, updatedOptions);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        print('   🔙 Closing edit modal for question ${widget.questionIndex + 1}');
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
