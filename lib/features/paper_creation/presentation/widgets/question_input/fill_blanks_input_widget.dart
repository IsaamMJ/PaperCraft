// features/question_papers/pages/widgets/question_input/fill_blanks_input_widget.dart
import 'package:flutter/material.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../../../core/presentation/constants/ui_constants.dart';

import '../../../../papers/domain/entities/question_entity.dart';

class FillBlanksInputWidget extends StatefulWidget {
  final Function(Question) onQuestionAdded;
  final bool isMobile;
  final bool isAdmin;
  final String? title; // Add this

  const FillBlanksInputWidget({
    super.key,
    required this.onQuestionAdded,
    required this.isAdmin,
    required this.isMobile,
    this.title, // Add this
  });

  @override
  State<FillBlanksInputWidget> createState() => _FillBlanksInputWidgetState();
}

class _FillBlanksInputWidgetState extends State<FillBlanksInputWidget> with AutomaticKeepAliveClientMixin {
  final _questionController = TextEditingController();
  bool _isOptional = false;
  List<String> _extractedBlanks = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _questionController.addListener(() {
      _extractBlanks();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  void _extractBlanks() {
    final text = _questionController.text;
    final regex = RegExp(r'_+'); // Match one or more underscores
    final matches = regex.allMatches(text);
    _extractedBlanks = matches.map((m) => 'Blank ${matches.toList().indexOf(m) + 1}').toList();
  }

  bool get _isValid {
    if (_questionController.text.trim().isEmpty) return false;
    return _extractedBlanks.isNotEmpty; // Just need blanks, no answers required
  }

  void _clear() {
    _questionController.clear();
    setState(() {
      _isOptional = false;
      _extractedBlanks.clear();
    });
  }

  void _addQuestion() {
    if (!_isValid) return;

    final question = Question(
      text: _questionController.text.trim(),
      type: 'fill_blanks',
      marks: _extractedBlanks.length, // 1 mark per blank
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
          widget.title ?? 'Add Fill in the Blanks Question',
          style: TextStyle(
            fontSize: widget.isMobile ? 18 : 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: UIConstants.spacing12),

        // Instructions
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
              Expanded(
                child: Text(
                  'Use underscores (___) to mark blanks in your question',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeSmall,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: UIConstants.spacing16),

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
            hintText: 'Enter your question with blanks (e.g., "The capital of France is ___")',
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

        // Show detected blanks
        if (_extractedBlanks.isNotEmpty) ...[
          SizedBox(height: UIConstants.spacing12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detected ${_extractedBlanks.length} blank(s):',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeSmall,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
                SizedBox(height: UIConstants.spacing4),
                Wrap(
                  spacing: 8,
                  children: _extractedBlanks.map((blank) => Chip(
                    label: Text(blank, style: const TextStyle(fontSize: 11)),
                    backgroundColor: AppColors.success.withOpacity(0.1),
                    side: BorderSide(color: AppColors.success.withOpacity(0.3)),
                  )).toList(),
                ),
              ],
            ),
          ),
        ],

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

        // Validation hints
        if (!_isValid && _questionController.text.isNotEmpty) ...[
          SizedBox(height: UIConstants.spacing8),
          Text(
            'Add blanks using underscores (___) in your question',
            style: TextStyle(
              color: AppColors.error,
              fontSize: UIConstants.fontSizeSmall,
            ),
          ),
        ],
      ],
    );
  }
}