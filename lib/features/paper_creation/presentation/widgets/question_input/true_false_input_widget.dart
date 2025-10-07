// features/question_papers/pages/widgets/question_input/true_false_input_widget.dart
import 'package:flutter/material.dart';
import '../../../../../core/presentation/constants/app_colors.dart';

import '../../../../../core/presentation/constants/ui_constants.dart';


import '../../../../../core/presentation/constants/ui_constants.dart';
import '../../../../paper_workflow/domain/entities/question_entity.dart';

class TrueFalseInputWidget extends StatefulWidget {
  final Function(Question) onQuestionAdded;
  final bool isMobile;
  final bool isAdmin;

  const TrueFalseInputWidget({
    super.key,
    required this.onQuestionAdded,
    required this.isMobile,
    required this.isAdmin,
  });

  @override
  State<TrueFalseInputWidget> createState() => _TrueFalseInputWidgetState();
}

class _TrueFalseInputWidgetState extends State<TrueFalseInputWidget> with AutomaticKeepAliveClientMixin {
  final _questionController = TextEditingController();
  bool _isOptional = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _questionController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

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
    super.build(context);

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
        SizedBox(height: UIConstants.spacing12),

        // Question input with Enter key navigation
        TextField(
          controller: _questionController,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            FocusScope.of(context).unfocus();
            if (_isValid) _addQuestion();
          },
          maxLines: widget.isMobile ? 4 : 3,
          style: TextStyle(fontSize: widget.isMobile ? 16 : 14),
          decoration: InputDecoration(
            hintText: 'Enter your true/false statement...',
            hintStyle: TextStyle(fontSize: widget.isMobile ? 14 : 12),
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

        // Show True/False options
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Text(
                'Students will choose: True or False',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: UIConstants.fontSizeSmall,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: UIConstants.spacing16),

        // Optional checkbox
        InkWell(
          onTap: () => setState(() => _isOptional = !_isOptional),
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Checkbox(
                  value: _isOptional,
                  onChanged: (v) => setState(() => _isOptional = v ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Text(
                  'Optional question',
                  style: TextStyle(fontSize: widget.isMobile ? 16 : 14),
                ),
              ],
            ),
          ),
        ),

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
        if (!_isValid && _questionController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Please enter a statement',
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