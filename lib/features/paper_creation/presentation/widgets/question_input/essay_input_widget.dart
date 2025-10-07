// features/question_papers/pages/widgets/question_input/essay_input_widget.dart
import 'package:flutter/material.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../../../core/presentation/constants/ui_constants.dart';
import '../../../../papers/domain/entities/question_entity.dart';

class EssayInputWidget extends StatefulWidget {
  final Function(Question) onQuestionAdded;
  final bool isMobile;
  final bool isAdmin;
  final String? questionType;

  const EssayInputWidget({
    super.key,
    required this.onQuestionAdded,
    required this.isMobile,
    this.questionType,
    required this.isAdmin,
  });

  @override
  State<EssayInputWidget> createState() => _EssayInputWidgetState();
}

class _EssayInputWidgetState extends State<EssayInputWidget> with AutomaticKeepAliveClientMixin {
  final _questionController = TextEditingController();
  final _subQuestionController = TextEditingController();
  final List<SubQuestion> _subQuestions = [];
  bool _isOptional = false;
  bool _showSubQuestions = false;

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
    _subQuestionController.dispose();
    super.dispose();
  }

  bool get _isValid => _questionController.text.trim().isNotEmpty;

  void _clear() {
    _questionController.clear();
    _subQuestionController.clear();
    _subQuestions.clear();
    setState(() {
      _isOptional = false;
      _showSubQuestions = false;
    });
  }

  void _addSubQuestion() {
    if (_subQuestionController.text.trim().isEmpty) return;

    setState(() {
      _subQuestions.add(SubQuestion(
        text: _subQuestionController.text.trim(),
        marks: 1,
      ));
      _subQuestionController.clear();
    });
  }

  void _removeSubQuestion(int index) {
    setState(() => _subQuestions.removeAt(index));
  }


  String _getTitle() {
    switch (widget.questionType) {
      case 'missing_letters': return 'Add Missing Letters Question';
      case 'meanings': return 'Add Word Meanings Question';
      case 'opposites': return 'Add Opposites Question';
      case 'frame_sentences': return 'Add Frame Sentences Question';
      case 'misc_grammar': return 'Add Grammar Question';
      case 'true_false': return 'Add True/False Question';
      case 'short_answers': return 'Add Short Answer Question';
      case 'long_answers': return 'Add Long Answer Question';
      default: return 'Add Essay/Short Answer Question';
    }
  }

  String _getHint() {
    switch (widget.questionType) {
      case 'missing_letters': return 'e.g., "Fill the missing letters: C_T, D_G, B_RD"';
      case 'meanings': return 'e.g., "Write the meaning of: Beautiful"';
      case 'opposites': return 'e.g., "Write the opposite of: Hot"';
      case 'frame_sentences': return 'e.g., "Make a sentence using: Beautiful"';
      case 'misc_grammar': return 'e.g., "Write the plural of: Child"';
      case 'true_false': return 'e.g., "The sun rises in the east"';
      default: return 'Enter your question here...';
    }
  }

  void _addQuestion() {
    if (!_isValid) return;

    final question = Question(
      text: _questionController.text.trim(),
      type: widget.questionType ?? 'short_answer', // Use the actual type
      marks: _getDefaultMarks(), // Different marks for different types
      subQuestions: List.from(_subQuestions),
      isOptional: _isOptional,
    );

    widget.onQuestionAdded(question);
    _clear();
  }

  int _getDefaultMarks() {
    switch (widget.questionType) {
      case 'missing_letters':
      case 'meanings':
      case 'opposites':
      case 'frame_sentences':
      case 'misc_grammar':
      case 'true_false':
        return 1; // 1 mark each
      case 'short_answers':
        return 2; // 2 marks
      case 'long_answers':
        return 5; // 5 marks
      default:
        return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getTitle(),
          style: TextStyle(
            fontSize: widget.isMobile ? 18 : 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: UIConstants.spacing12),

        // Main question input with Enter key navigation
        TextField(
          controller: _questionController,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) {
            if (_showSubQuestions) {
              // Move to sub-question field if expanded
              FocusScope.of(context).nextFocus();
            } else {
              // Add question if valid
              FocusScope.of(context).unfocus();
              if (_isValid) _addQuestion();
            }
          },
          maxLines: widget.isMobile ? 4 : 3,
          style: TextStyle(fontSize: widget.isMobile ? 16 : 14),
          decoration: InputDecoration(
            hintText: _getHint(),
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

        // Sub-questions section
        InkWell(
          onTap: () => setState(() => _showSubQuestions = !_showSubQuestions),
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          child: Container(
            padding: const EdgeInsets.all(UIConstants.paddingMedium),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
            ),
            child: Row(
              children: [
                Icon(
                  _showSubQuestions ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.textSecondary,
                  size: widget.isMobile ? 28 : 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sub-questions (optional)',
                  style: TextStyle(
                    fontSize: widget.isMobile ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                if (_subQuestions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                    ),
                    child: Text(
                      '${_subQuestions.length}',
                      style: TextStyle(
                        fontSize: widget.isMobile ? 14 : 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        if (_showSubQuestions) ...[
          SizedBox(height: UIConstants.spacing16),

          // Sub-question input with Enter key navigation
          TextField(
            controller: _subQuestionController,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              // Add sub-question and stay focused for more sub-questions
              if (_subQuestionController.text.trim().isNotEmpty) {
                _addSubQuestion();
              }
            },
            style: TextStyle(fontSize: widget.isMobile ? 16 : 14),
            decoration: InputDecoration(
              hintText: 'Enter sub-question (e.g., "a) Explain the concept...")',
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
              suffixIcon: IconButton(
                onPressed: _addSubQuestion,
                icon: const Icon(Icons.add),
                iconSize: widget.isMobile ? 28 : 24,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: Size(widget.isMobile ? 44 : 40, widget.isMobile ? 44 : 40),
                ),
              ),
            ),
          ),

          // Display sub-questions
          if (_subQuestions.isNotEmpty) ...[
            SizedBox(height: UIConstants.spacing12),
            Text(
              'Sub-questions:',
              style: TextStyle(
                fontSize: widget.isMobile ? 14 : 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: UIConstants.spacing8),
            ..._subQuestions.asMap().entries.map((e) {
              final index = e.key;
              final subQuestion = e.value;
              final label = String.fromCharCode(97 + index); // a, b, c...

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(widget.isMobile ? 12 : 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Container(
                      width: widget.isMobile ? 24 : 20,
                      height: widget.isMobile ? 24 : 20,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: widget.isMobile ? 12 : 10,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        subQuestion.text,
                        style: TextStyle(fontSize: widget.isMobile ? 14 : 12),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removeSubQuestion(index),
                      icon: const Icon(Icons.delete_outline),
                      iconSize: widget.isMobile ? 20 : 18,
                      color: AppColors.error,
                      style: IconButton.styleFrom(
                        minimumSize: Size(widget.isMobile ? 32 : 28, widget.isMobile ? 32 : 28),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
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

        // Validation hint
        if (!_isValid && _questionController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Please enter a question',
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