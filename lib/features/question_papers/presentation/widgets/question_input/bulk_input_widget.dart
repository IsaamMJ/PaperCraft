// features/question_papers/presentation/widgets/question_input/bulk_input_widget.dart
import 'package:flutter/material.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../domain/entities/question_entity.dart';

class BulkInputWidget extends StatefulWidget {
  final String questionType;
  final int questionCount;
  final Function(List<Question>) onQuestionsAdded;
  final bool isMobile;
  final bool isAdmin;

  const BulkInputWidget({
    super.key,
    required this.questionType,
    required this.questionCount,
    required this.onQuestionsAdded,
    required this.isMobile,
    required this.isAdmin,
  });

  @override
  State<BulkInputWidget> createState() => _BulkInputWidgetState();
}

class _BulkInputWidgetState extends State<BulkInputWidget> with AutomaticKeepAliveClientMixin {
  late List<TextEditingController> _controllers;
  bool _isOptionalAll = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.questionCount, (_) => TextEditingController());

    // Add listeners to trigger UI updates
    for (var controller in _controllers) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _isValid {
    return _controllers.every((controller) => controller.text.trim().isNotEmpty);
  }

  void _clear() {
    for (var controller in _controllers) {
      controller.clear();
    }
    setState(() => _isOptionalAll = false);
  }

  void _addAllQuestions() {
    if (!_isValid) return;

    final questions = <Question>[];

    for (int i = 0; i < _controllers.length; i++) {
      final text = _controllers[i].text.trim();
      if (text.isNotEmpty) {
        questions.add(Question(
          text: _formatQuestionText(text, i + 1), // Pass question number for variation
          type: widget.questionType,
          marks: _getDefaultMarks(),
          isOptional: _isOptionalAll,
        ));
      }
    }

    if (questions.isNotEmpty) {
      widget.onQuestionsAdded(questions);
      _clear();
    }
  }

  // FIXED: Simply return the input without any instruction prefix
  String _formatQuestionText(String input, int questionNumber) {
    switch (widget.questionType) {
      case 'missing_letters':
      // Just return the word/text as-is - the section heading is enough
        return input;

      case 'true_false':
      // Keep statements as-is - True/False will be handled by the system
        return input;

      case 'short_answers':
      // Ensure proper question format
        return input.endsWith('?') ? input : '$input?';

      default:
        return input;
    }
  }

  int _getDefaultMarks() {
    switch (widget.questionType) {
      case 'missing_letters':
      case 'true_false':
        return 1;
      case 'short_answers':
        return 2;
      default:
        return 1;
    }
  }

  String _getTitle() {
    switch (widget.questionType) {
      case 'missing_letters':
        return 'Add Missing Letters Questions';
      case 'true_false':
        return 'Add True/False Questions';
      case 'short_answers':
        return 'Add Short Answer Questions';
      default:
        return 'Add Questions';
    }
  }

  String _getFieldLabel(int index) {
    switch (widget.questionType) {
      case 'missing_letters':
        return 'Word ${index + 1}';
      case 'true_false':
        return 'Statement ${index + 1}';
      case 'short_answers':
        return 'Question ${index + 1}';
      default:
        return 'Question ${index + 1}';
    }
  }

  String _getHintText() {
    switch (widget.questionType) {
      case 'missing_letters':
        return 'e.g., BEA_TIFUL, C_T, H_USE';
      case 'true_false':
        return 'e.g., The sun rises in the east';
      case 'short_answers':
        return 'e.g., What is the capital of India?';
      default:
        return 'Enter your question here...';
    }
  }

  // NEW: Get instruction preview to show users what the final questions will look like
  String _getInstructionPreview() {
    switch (widget.questionType) {
      case 'missing_letters':
        return 'Questions will appear as simple numbered items (e.g., "1. BEA_TIFUL") under the section heading.';
      case 'true_false':
        return 'Each statement will be presented as True/False format automatically.';
      case 'short_answers':
        return 'Questions will be formatted properly with question marks if needed.';
      default:
        return 'Questions will be formatted appropriately for the question type.';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          _getTitle(),
          style: TextStyle(
            fontSize: widget.isMobile ? 18 : 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),

        // Instructions with preview
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fill all ${widget.questionCount} fields to add questions',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _getInstructionPreview(),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primary.withOpacity(0.8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Question input fields with Enter key navigation
        Column(
          children: List.generate(widget.questionCount, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: _controllers[index],
                textCapitalization: TextCapitalization.sentences,
                textInputAction: index == widget.questionCount - 1
                    ? TextInputAction.done
                    : TextInputAction.next,
                onSubmitted: (value) {
                  if (index == widget.questionCount - 1) {
                    // Last field - unfocus and try to add questions if valid
                    FocusScope.of(context).unfocus();
                    if (_isValid) _addAllQuestions();
                  } else {
                    // Move to next field
                    FocusScope.of(context).nextFocus();
                  }
                },
                style: TextStyle(fontSize: widget.isMobile ? 16 : 14),
                maxLines: widget.questionType == 'short_answers' ? 2 : 1,
                decoration: InputDecoration(
                  labelText: _getFieldLabel(index),
                  hintText: _getHintText(),
                  hintStyle: TextStyle(fontSize: widget.isMobile ? 14 : 12),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: EdgeInsets.all(widget.isMobile ? 16 : 12),
                  prefixIcon: Container(
                    margin: EdgeInsets.all(widget.isMobile ? 14 : 12),
                    width: widget.isMobile ? 28 : 24,
                    height: widget.isMobile ? 28 : 24,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: widget.isMobile ? 14 : 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),

        // Progress indicator
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: _isValid
                ? AppColors.success.withOpacity(0.1)
                : AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _isValid ? Icons.check_circle_outline : Icons.pending_outlined,
                size: 16,
                color: _isValid ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 8),
              Text(
                _getProgressText(),
                style: TextStyle(
                  fontSize: 12,
                  color: _isValid ? AppColors.success : AppColors.warning,
                ),
              ),
            ],
          ),
        ),

        // Optional checkbox
        InkWell(
          onTap: () => setState(() => _isOptionalAll = !_isOptionalAll),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Checkbox(
                  value: _isOptionalAll,
                  onChanged: (v) => setState(() => _isOptionalAll = v ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Text(
                  'Mark all questions as optional',
                  style: TextStyle(fontSize: widget.isMobile ? 16 : 14),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _isValid ? _addAllQuestions : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    vertical: widget.isMobile ? 16 : 12,
                  ),
                  minimumSize: Size(0, widget.isMobile ? 52 : 44),
                  textStyle: TextStyle(
                    fontSize: widget.isMobile ? 16 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text('Add All ${widget.questionCount} Questions'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _clear,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  vertical: widget.isMobile ? 16 : 12,
                  horizontal: widget.isMobile ? 20 : 16,
                ),
                minimumSize: Size(0, widget.isMobile ? 52 : 44),
                textStyle: TextStyle(
                  fontSize: widget.isMobile ? 16 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: const Text('Clear All'),
            ),
          ],
        ),

        // Validation hint
        if (!_isValid && _controllers.any((c) => c.text.isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Please fill all ${widget.questionCount} fields before adding',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  String _getProgressText() {
    final filledCount = _controllers.where((c) => c.text.trim().isNotEmpty).length;
    if (filledCount == widget.questionCount) {
      return 'All fields completed - ready to add!';
    }
    return '$filledCount of ${widget.questionCount} fields completed';
  }
}