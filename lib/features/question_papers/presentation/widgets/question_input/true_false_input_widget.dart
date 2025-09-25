// features/question_papers/presentation/widgets/question_input/true_false_input_widget.dart
import 'package:flutter/material.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../domain/entities/question_entity.dart';

class TrueFalseInputWidget extends StatefulWidget {
  final Function(Question) onQuestionAdded;
  final bool isMobile;

  const TrueFalseInputWidget({
    super.key,
    required this.onQuestionAdded,
    required this.isMobile,
  });

  @override
  State<TrueFalseInputWidget> createState() => _TrueFalseInputWidgetState();
}

class _TrueFalseInputWidgetState extends State<TrueFalseInputWidget> {
  final _questionController = TextEditingController();
  bool _isOptional = false;

  bool get _isValid => _questionController.text.trim().isNotEmpty;

  void _clear() {
    _questionController.clear();
    setState(() => _isOptional = false);
  }

  void _addQuestion() {
    if (!_isValid) return;

    final question = Question(
      text: _questionController.text.trim(),
      type: 'true_false',
      options: ['True', 'False'], // Fixed options
      marks: 1,
      isOptional: _isOptional,
    );

    widget.onQuestionAdded(question);
    _clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add True/False Question',
          style: TextStyle(
            fontSize: widget.isMobile ? 18 : 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _questionController,
          maxLines: widget.isMobile ? 4 : 3,
          decoration: InputDecoration(
            hintText: 'Enter your true/false statement...',
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
          ),
        ),

        const SizedBox(height: 16),

        // Show True/False options
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Text('Students will choose: True or False',
                  style: TextStyle(color: AppColors.primary, fontSize: 12)),
            ],
          ),
        ),

        const SizedBox(height: 16),

        CheckboxListTile(
          value: _isOptional,
          onChanged: (v) => setState(() => _isOptional = v ?? false),
          title: const Text('Optional question'),
          contentPadding: EdgeInsets.zero,
        ),

        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _isValid ? _addQuestion : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: widget.isMobile ? 16 : 12),
                ),
                child: const Text('Add Question'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _clear,
              child: const Text('Clear'),
            ),
          ],
        ),
      ],
    );
  }
}