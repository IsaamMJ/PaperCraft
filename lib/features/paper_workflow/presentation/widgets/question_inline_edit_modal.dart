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
  late List<TextEditingController> _columnAControllers;
  late List<TextEditingController> _columnBControllers;
  bool _isSaving = false;

  /// Helper method to check if question is "Match the Following" type
  bool _isMatchFollowing() => widget.question.type == 'match_following';

  /// Parse options into two columns for match_following questions
  void _parseMatchingPairs() {
    if (!_isMatchFollowing() || widget.question.options == null || widget.question.options!.isEmpty) {
      return;
    }

    final options = widget.question.options!;
    final separatorIndex = options.indexOf('---SEPARATOR---');

    if (separatorIndex == -1) return;

    final columnA = options.sublist(0, separatorIndex);
    final columnB = options.sublist(separatorIndex + 1);

    _columnAControllers = columnA.map((opt) => TextEditingController(text: opt)).toList();
    _columnBControllers = columnB.map((opt) => TextEditingController(text: opt)).toList();

  }

  @override
  void initState() {
    super.initState();

    _questionTextController = TextEditingController(text: widget.question.text);

    // Initialize option controllers
    if (_isMatchFollowing()) {
      // For match_following, parse pairs separately
      _optionControllers = [];
      _columnAControllers = [];
      _columnBControllers = [];
      _parseMatchingPairs();
    } else {
      // For other types, use regular option controllers
      _optionControllers = (widget.question.options ?? [])
          .map((option) => TextEditingController(text: option))
          .toList();
      _columnAControllers = [];
      _columnBControllers = [];
    }
  }

  @override
  void dispose() {
    _questionTextController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    for (var controller in _columnAControllers) {
      controller.dispose();
    }
    for (var controller in _columnBControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_isMatchFollowing()) {
      setState(() {
        _columnAControllers.add(TextEditingController());
        _columnBControllers.add(TextEditingController());
      });
    } else {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    }
  }

  void _removeOption(int index) {
    if (_isMatchFollowing()) {
      setState(() {
        _columnAControllers[index].dispose();
        _columnBControllers[index].dispose();
        _columnAControllers.removeAt(index);
        _columnBControllers.removeAt(index);
      });
    } else {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
      });
    }
  }

  void _saveChanges() {

    final updatedText = _questionTextController.text.trim();

    // Validation
    if (updatedText.isEmpty) {
      _showErrorSnackBar('Question text cannot be empty');
      return;
    }

    // Get updated options
    List<String>? updatedOptions;

    if (_isMatchFollowing()) {
      // Handle match_following - combine columns with separator
      final columnA = _columnAControllers
          .map((ctrl) => ctrl.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      final columnB = _columnBControllers
          .map((ctrl) => ctrl.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      if (columnA.isEmpty || columnB.isEmpty) {
        _showErrorSnackBar('Both columns must have at least one item');
        return;
      }

      // Ensure equal number of items
      if (columnA.length != columnB.length) {
        _showErrorSnackBar('Both columns must have the same number of items');
        return;
      }

      // Combine with separator
      updatedOptions = [...columnA, '---SEPARATOR---', ...columnB];
    } else if (_optionControllers.isNotEmpty) {
      updatedOptions = _optionControllers
          .map((ctrl) => ctrl.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      if (updatedOptions.isNotEmpty) {
        updatedOptions.asMap().forEach((index, option) {
        });
      }

      if (updatedOptions.isEmpty && widget.question.options != null && widget.question.options!.isNotEmpty) {
        // If options existed before, at least one must remain
        _showErrorSnackBar('At least one option is required');
        return;
      }
    }

    setState(() => _isSaving = true);

    // Call the save callback

    widget.onSave(updatedText, updatedOptions);

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

                    // Match the Following Options
                    if (widget.question.type == 'match_following')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Matching Pairs'),
                          SizedBox(height: UIConstants.spacing8),
                          Container(
                            padding: const EdgeInsets.all(UIConstants.paddingSmall),
                            decoration: BoxDecoration(
                              color: AppColors.primary05,
                              borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                              border: Border.all(color: AppColors.primary20),
                            ),
                            child: Column(
                              children: [
                                // Header
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Column A',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: UIConstants.fontSizeSmall,
                                            color: AppColors.primary,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        child: Icon(Icons.arrow_forward, size: 16, color: AppColors.textSecondary),
                                      ),
                                      Expanded(
                                        child: Text(
                                          'Column B',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: UIConstants.fontSizeSmall,
                                            color: AppColors.primary,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Pairs
                                ..._columnAControllers.asMap().entries.map((e) {
                                  final index = e.key;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _columnAControllers[index],
                                            decoration: InputDecoration(
                                              hintText: 'Item ${index + 1}',
                                              isDense: true,
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
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Icon(Icons.arrow_forward, size: 16, color: AppColors.textSecondary),
                                        ),
                                        Expanded(
                                          child: TextField(
                                            controller: _columnBControllers[index],
                                            decoration: InputDecoration(
                                              hintText: 'Match ${index + 1}',
                                              isDense: true,
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
                                        if (_columnAControllers.length > 2)
                                          IconButton(
                                            icon: Icon(Icons.delete_outline, color: AppColors.error),
                                            onPressed: () => _removeOption(index),
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                            padding: EdgeInsets.zero,
                                          ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                          SizedBox(height: UIConstants.spacing12),
                          TextButton.icon(
                            onPressed: _addOption,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Pair'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                          ),
                          SizedBox(height: UIConstants.spacing16),
                        ],
                      ),

                    // Options (if MCQ or fill_blanks)
                    if (!widget.question.type.contains('match') && (widget.question.type == 'multiple_choice' || widget.question.type == 'fill_blanks'))
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
