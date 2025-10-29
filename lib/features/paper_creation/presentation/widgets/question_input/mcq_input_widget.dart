// features/question_papers/pages/widgets/question_input/mcq_input_widget.dart
import 'package:flutter/material.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../../../core/presentation/constants/ui_constants.dart';
import '../../../../paper_workflow/domain/entities/question_entity.dart';

class McqInputWidget extends StatefulWidget {
  final Function(Question) onQuestionAdded;
  final bool isMobile;
  final bool isAdmin;

  const McqInputWidget({
    super.key,
    required this.onQuestionAdded,
    required this.isMobile,
    required this.isAdmin,
  });

  @override
  State<McqInputWidget> createState() => _McqInputWidgetState();
}

class _McqInputWidgetState extends State<McqInputWidget> with AutomaticKeepAliveClientMixin {
  final _questionController = TextEditingController();
  final _optionControllers = List.generate(4, (_) => TextEditingController());
  late List<FocusNode> _focusNodes;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(4, (_) => FocusNode());
    // Add listeners to trigger UI updates
    _questionController.addListener(() {
      if (mounted) setState(() {});
    });
    for (var controller in _optionControllers) {
      controller.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  bool get _isValid {
    if (_questionController.text.trim().isEmpty) return false;
    final filledOptions = _optionControllers
        .where((c) => c.text.trim().isNotEmpty)
        .length;
    return filledOptions >= 2;
  }

  void _clear() {
    _questionController.clear();
    for (var controller in _optionControllers) {
      controller.clear();
    }
  }



  void _addQuestion() {
    if (!_isValid) return;

    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final question = Question(
      text: _questionController.text.trim(),
      type: 'multiple_choice',
      options: options,
      correctAnswer: null,
      marks: 1, // Default marks for MCQ
      isOptional: false, // MCQ questions are always mandatory
    );

    widget.onQuestionAdded(question);
    _clear();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add Multiple Choice Question',
          style: TextStyle(
            fontSize: widget.isMobile ? 18 : 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: UIConstants.spacing12),

        // Question input
        TextField(
          controller: _questionController,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          maxLines: 1,
          onSubmitted: (_) => _focusNodes[0].requestFocus(),  // Focus on first option (A)
          style: TextStyle(fontSize: widget.isMobile ? 16 : 14),
          decoration: InputDecoration(
            hintText: 'Enter your multiple choice question here...',
            hintStyle: TextStyle(fontSize: widget.isMobile ? 16 : 14),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: EdgeInsets.all(widget.isMobile ? 16 : 12),
          ),
        ),

        SizedBox(height: UIConstants.spacing16),

        // Options with Enter key navigation
        Text(
          'Options (minimum 2 required)',
          style: TextStyle(
            fontSize: widget.isMobile ? 16 : 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: UIConstants.spacing12),

        ..._optionControllers.asMap().entries.map((e) {
          final index = e.key;
          final controller = e.value;
          final label = String.fromCharCode(65 + index); // A, B, C, D

          return Padding(
            padding: EdgeInsets.only(bottom: widget.isMobile ? 16 : 12),
            child: TextField(
              controller: controller,
              focusNode: _focusNodes[index],
              textCapitalization: TextCapitalization.sentences,
              textInputAction: index == _optionControllers.length - 1
                  ? TextInputAction.done
                  : TextInputAction.next,
              onSubmitted: (value) {
                if (index == _optionControllers.length - 1) {
                  // Last option field - unfocus and try to add question if valid
                  FocusScope.of(context).unfocus();
                  if (_isValid) _addQuestion();
                } else {
                  // Move to EXACTLY the next option field (not generic nextFocus which skips)
                  _focusNodes[index + 1].requestFocus();
                }
              },
              style: TextStyle(fontSize: widget.isMobile ? 16 : 14),
              decoration: InputDecoration(
                labelText: 'Option $label',
                labelStyle: TextStyle(fontSize: widget.isMobile ? 16 : 14),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                contentPadding: EdgeInsets.all(widget.isMobile ? 16 : 12),
                prefixIcon: Container(
                  margin: EdgeInsets.all(widget.isMobile ? 14 : 12),
                  width: widget.isMobile ? 28 : 24,
                  height: widget.isMobile ? 28 : 24,
                  decoration: BoxDecoration(
                    color: AppColors.primary10,
                    borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                  ),
                  child: Center(
                    child: Text(
                      label,
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

        SizedBox(height: UIConstants.spacing24),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _isValid ? _addQuestion : null,
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
                child: const Text('Add Question'),
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
              child: const Text('Clear'),
            ),
          ],
        ),

        // Validation hint
        if (!_isValid && (_questionController.text.isNotEmpty ||
            _optionControllers.any((c) => c.text.isNotEmpty)))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _questionController.text.trim().isEmpty
                  ? 'Please enter a question'
                  : 'Please provide at least 2 options',
              style: TextStyle(
                color: AppColors.error,
                fontSize: UIConstants.fontSizeSmall,
              ),
            ),
          ),
      ],
    );
  }
}