// features/question_papers/pages/widgets/question_input/essay_input_widget.dart
import 'package:flutter/material.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../../../core/presentation/constants/ui_constants.dart';
import '../../../../paper_workflow/domain/entities/question_entity.dart';

class EssayInputWidget extends StatefulWidget {
  final Function(Question) onQuestionAdded;
  final bool isMobile;
  final bool isAdmin;
  final String? questionType;
  final double? marksPerQuestion;
  final String? sectionName;

  const EssayInputWidget({
    super.key,
    required this.onQuestionAdded,
    required this.isMobile,
    this.questionType,
    required this.isAdmin,
    this.marksPerQuestion,
    this.sectionName,
  });

  @override
  State<EssayInputWidget> createState() => _EssayInputWidgetState();
}

class _EssayInputWidgetState extends State<EssayInputWidget> with AutomaticKeepAliveClientMixin {
  final _questionController = TextEditingController();
  final _subQuestionController = TextEditingController();
  final _wordBankController = TextEditingController();
  late FocusNode _subQuestionFocusNode;
  late FocusNode _wordBankFocusNode;
  final List<SubQuestion> _subQuestions = [];
  final List<String> _wordBank = [];
  bool _isOptional = false;
  bool _showSubQuestions = false;
  bool _showWordBank = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _subQuestionFocusNode = FocusNode();
    _wordBankFocusNode = FocusNode();
    _questionController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    _subQuestionController.dispose();
    _wordBankController.dispose();
    _subQuestionFocusNode.dispose();
    _wordBankFocusNode.dispose();
    super.dispose();
  }

  bool get _isValid => _questionController.text.trim().isNotEmpty;

  void _clear() {
    _questionController.clear();
    _subQuestionController.clear();
    _wordBankController.clear();
    _subQuestions.clear();
    _wordBank.clear();
    setState(() {
      _isOptional = false;
      _showSubQuestions = false;
      _showWordBank = false;
    });
  }

  void _addSubQuestion() {
    final text = _subQuestionController.text.trim();

    // Validation
    if (text.isEmpty) return;

    // Prevent too many subquestions (max 26 = a to z)
    if (_subQuestions.length >= 26) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Maximum 26 sub-questions allowed'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Check for duplicates
    if (_subQuestions.any((sq) => sq.text.toLowerCase() == text.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('This sub-question already exists'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _subQuestions.add(SubQuestion(
        text: text,
      ));
      _subQuestionController.clear();
    });
  }

  void _removeSubQuestion(int index) {
    setState(() => _subQuestions.removeAt(index));
  }

  void _addWordBankWord() {
    final text = _wordBankController.text.trim();

    // Validation
    if (text.isEmpty) return;

    // Prevent too many words in word bank (max 26)
    if (_wordBank.length >= 26) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Maximum 26 words allowed in word bank'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Check for duplicates
    if (_wordBank.any((w) => w.toLowerCase() == text.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('This word already exists in word bank'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _wordBank.add(text);
      _wordBankController.clear();
    });

    // Re-request focus to continue adding words
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(_wordBankFocusNode);
      }
    });
  }

  void _removeWordBankWord(int index) {
    setState(() => _wordBank.removeAt(index));
  }


  String _getTitle() {
    // Use section name if available, otherwise use default based on question type
    if (widget.sectionName != null && widget.sectionName!.isNotEmpty) {
      return widget.sectionName!;
    }

    switch (widget.questionType) {
      case 'missing_letters': return 'Add Missing Letters Question';
      case 'word_forms': return 'Add Word Forms Question';
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
      case 'missing_letters': return 'Enter word (e.g., "CAT", "DOG", "BIRD")';
      case 'word_forms': return 'Enter word to transform (e.g., "Beautiful", "Hot", "Run")';
      case 'frame_sentences': return 'Enter word (e.g., "Beautiful")';
      case 'misc_grammar': return 'Enter word (e.g., "Child")';
      case 'true_false': return 'Enter statement (e.g., "The sun rises in the east")';
      default: return 'Enter your question here...';
    }
  }

  bool _isSingleLineType() {
    return widget.questionType == 'missing_letters' ||
           widget.questionType == 'word_forms' ||
           widget.questionType == 'frame_sentences' ||
           widget.questionType == 'misc_grammar' ||
           widget.questionType == 'short_answers' ||
           widget.questionType == 'long_answers' ||
           widget.questionType == 'true_false';
  }

  void _addQuestion() {
    if (!_isValid) return;

    // For fill_blanks questions, validate that subquestions are present
    final questionType = widget.questionType ?? 'short_answer';
    if (questionType == 'fill_blanks' && _subQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please add at least one sub-question (blank)'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final question = Question(
      text: _questionController.text.trim(),
      type: questionType,
      marks: _getDefaultMarks(), // Different marks for different types
      subQuestions: List.from(_subQuestions),
      options: _wordBank.isNotEmpty ? List.from(_wordBank) : null,
      isOptional: _isOptional,
    );

    widget.onQuestionAdded(question);
    _clear();
  }

  double _getDefaultMarks() {
    // If marksPerQuestion is provided from section, use it
    if (widget.marksPerQuestion != null) {
      return widget.marksPerQuestion!;
    }

    // Fallback to type-based defaults
    switch (widget.questionType) {
      case 'missing_letters':
      case 'word_forms':
      case 'frame_sentences':
      case 'misc_grammar':
      case 'true_false':
        return 1.0; // 1 mark each
      case 'short_answers':
        return 2.0; // 2 marks
      case 'long_answers':
        return 5.0; // 5 marks
      default:
        return 2.0;
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

        // Main question input
        TextField(
          controller: _questionController,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: _isSingleLineType() ? TextInputAction.done : TextInputAction.newline,
          maxLines: _isSingleLineType() ? 1 : (widget.isMobile ? 4 : 3),
          onSubmitted: _isSingleLineType() ? (_) {
            FocusScope.of(context).unfocus();
            if (_isValid) _addQuestion();
          } : null,
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

        // Word bank section (optional, for fill_blanks type)
        if (widget.questionType == 'fill_blanks') ...[
          InkWell(
            onTap: () => setState(() => _showWordBank = !_showWordBank),
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
                    _showWordBank ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                    size: widget.isMobile ? 28 : 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Word Bank (optional)',
                    style: TextStyle(
                      fontSize: widget.isMobile ? 16 : 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_wordBank.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary10,
                        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                      ),
                      child: Text(
                        '${_wordBank.length}',
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

          if (_showWordBank) ...[
            SizedBox(height: UIConstants.spacing16),

            // Word bank input
            TextField(
              controller: _wordBankController,
              focusNode: _wordBankFocusNode,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _addWordBankWord(),
              style: TextStyle(fontSize: widget.isMobile ? 16 : 14),
              decoration: InputDecoration(
                hintText: 'Enter word for word bank (e.g., "Apple", "Orange")',
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
                  onPressed: _addWordBankWord,
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

            // Display word bank words
            if (_wordBank.isNotEmpty) ...[
              SizedBox(height: UIConstants.spacing12),
              Text(
                'Words:',
                style: TextStyle(
                  fontSize: widget.isMobile ? 14 : 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: UIConstants.spacing8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _wordBank.asMap().entries.map((e) {
                  final index = e.key;
                  final word = e.value;

                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.isMobile ? 12 : 10,
                      vertical: widget.isMobile ? 8 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary10,
                      borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                      border: Border.all(color: AppColors.primary, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          word,
                          style: TextStyle(
                            fontSize: widget.isMobile ? 14 : 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _removeWordBankWord(index),
                          child: Icon(
                            Icons.close,
                            color: AppColors.error,
                            size: widget.isMobile ? 18 : 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],

          SizedBox(height: UIConstants.spacing16),
        ],

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
                      color: AppColors.primary10,
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
            focusNode: _subQuestionFocusNode,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) {
              // Add sub-question and re-open keyboard for next input
              if (_subQuestionController.text.trim().isNotEmpty) {
                _addSubQuestion();
                // Re-request focus to show keyboard (widget rebuild will clear the field)
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted) {
                    FocusScope.of(context).requestFocus(_subQuestionFocusNode);
                  }
                });
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
                        color: AppColors.primary10,
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