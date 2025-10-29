// features/question_papers/pages/widgets/question_input/fill_blanks_input_widget.dart
import 'package:flutter/material.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../../../core/presentation/constants/ui_constants.dart';
import '../../../../paper_workflow/domain/entities/question_entity.dart';


class FillBlanksInputWidget extends StatefulWidget {
  final Function(Question) onQuestionAdded;
  final bool isMobile;
  final bool isAdmin;
  final String? title;

  const FillBlanksInputWidget({
    super.key,
    required this.onQuestionAdded,
    required this.isAdmin,
    required this.isMobile,
    this.title,
  });

  @override
  State<FillBlanksInputWidget> createState() => _FillBlanksInputWidgetState();
}

class _FillBlanksInputWidgetState extends State<FillBlanksInputWidget> with AutomaticKeepAliveClientMixin {
  final _questionController = TextEditingController();
  final _wordBankController = TextEditingController();
  late FocusNode _wordBankFocusNode;
  bool _isOptional = false;
  bool _showWordBank = false;
  List<String> _extractedBlanks = [];
  List<String> _wordBank = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _wordBankFocusNode = FocusNode();

    _questionController.addListener(() {
      _extractBlanks();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    _wordBankController.dispose();
    _wordBankFocusNode.dispose();
    super.dispose();
  }

  void _extractBlanks() {
    final text = _questionController.text;
    final regex = RegExp(r'_+'); // Match one or more underscores
    final matches = regex.allMatches(text);
    _extractedBlanks = matches.map((m) => 'Blank ${matches.toList().indexOf(m) + 1}').toList();
  }

  void _addWordBankWord() {
    final text = _wordBankController.text.trim();
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

  bool get _isValid {
    if (_questionController.text.trim().isEmpty) return false;
    return _extractedBlanks.isNotEmpty; // Just need blanks, no answers required
  }

  void _clear() {
    _questionController.clear();
    _wordBankController.clear();
    setState(() {
      _isOptional = false;
      _extractedBlanks.clear();
      _wordBank.clear();
      _showWordBank = false;
    });
  }

  void _addQuestion() {
    if (!_isValid) return;

    final question = Question(
      text: _questionController.text.trim(),
      type: 'fill_in_blanks',
      marks: _extractedBlanks.length.toDouble(), // 1 mark per blank
      isOptional: _isOptional,
      options: _wordBank.isNotEmpty ? List.from(_wordBank) : null,
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
            color: AppColors.primary10,
            borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
            border: Border.all(color: AppColors.primary30),
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

        // Question input
        TextField(
          controller: _questionController,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          maxLines: 1,
          onSubmitted: (_) {
            FocusScope.of(context).unfocus();
            if (_isValid) _addQuestion();
          },
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
              color: AppColors.success10,
              borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              border: Border.all(color: AppColors.success),
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
                    backgroundColor: AppColors.success10,
                    side: BorderSide(color: AppColors.success),
                  )).toList(),
                ),
              ],
            ),
          ),
        ],

        SizedBox(height: UIConstants.spacing16),

        // Word bank section (optional)
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