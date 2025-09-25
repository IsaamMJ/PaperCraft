// features/question_papers/presentation/widgets/question_input/matching_input_widget.dart
import 'package:flutter/material.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../domain/entities/question_entity.dart';

class MatchingInputWidget extends StatefulWidget {
  final Function(Question) onQuestionAdded;
  final bool isMobile;

  const MatchingInputWidget({
    super.key,
    required this.onQuestionAdded,
    required this.isMobile,
  });

  @override
  State<MatchingInputWidget> createState() => MatchingInputWidgetState();
}

class MatchingInputWidgetState extends State<MatchingInputWidget> with AutomaticKeepAliveClientMixin {
  final _questionController = TextEditingController();
  final List<TextEditingController> _leftColumnControllers = List.generate(5, (_) => TextEditingController());
  final List<TextEditingController> _rightColumnControllers = List.generate(5, (_) => TextEditingController());
  bool _isOptional = false;
  int _pairCount = 3; // Start with 3 pairs

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _questionController.addListener(() => setState(() {}));

    // Add listeners to pair controllers
    for (int i = 0; i < _leftColumnControllers.length; i++) {
      _leftColumnControllers[i].addListener(() => setState(() {}));
      _rightColumnControllers[i].addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (var controller in _leftColumnControllers) {
      controller.dispose();
    }
    for (var controller in _rightColumnControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _isValid {
    if (_questionController.text.trim().isEmpty) return false;

    // Check if we have at least the minimum number of valid pairs
    int validPairs = 0;
    for (int i = 0; i < _pairCount; i++) {
      if (_leftColumnControllers[i].text.trim().isNotEmpty &&
          _rightColumnControllers[i].text.trim().isNotEmpty) {
        validPairs++;
      }
    }
    return validPairs >= 2; // At least 2 pairs required
  }

  void _clear() {
    _questionController.clear();
    for (var controller in _leftColumnControllers) {
      controller.clear();
    }
    for (var controller in _rightColumnControllers) {
      controller.clear();
    }
    setState(() {
      _isOptional = false;
      _pairCount = 3;
    });
  }

  void _addPair() {
    if (_pairCount < 5) {
      setState(() => _pairCount++);
    }
  }

  void _removePair() {
    if (_pairCount > 2) {
      setState(() => _pairCount--);
    }
  }

  // Public method that can be called from coordinator
  void addQuestion() {
    if (_isValid) {
      _addQuestion();
    }
  }

  void _addQuestion() {
    if (!_isValid) return;

    // Collect valid pairs
    final List<String> leftItems = [];
    final List<String> rightItems = [];

    for (int i = 0; i < _pairCount; i++) {
      final left = _leftColumnControllers[i].text.trim();
      final right = _rightColumnControllers[i].text.trim();
      if (left.isNotEmpty && right.isNotEmpty) {
        leftItems.add(left);
        rightItems.add(right);
      }
    }

    // Store matching pairs as sub-questions for display purposes
    final subQuestions = <SubQuestion>[];
    for (int i = 0; i < leftItems.length; i++) {
      subQuestions.add(SubQuestion(
        text: '${leftItems[i]} → ${rightItems[i]}',
        marks: 1,
      ));
    }

    final question = Question(
      text: _questionController.text.trim(),
      type: 'matching',
      options: [...leftItems, '---SEPARATOR---', ...rightItems], // Store both columns
      marks: leftItems.length, // 1 mark per pair
      subQuestions: subQuestions,
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
          'Add Matching Question',
          style: TextStyle(
            fontSize: widget.isMobile ? 18 : 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        // Instructions
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Create matching pairs - students will match items from left column to right column',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Question instruction
        TextField(
          controller: _questionController,
          maxLines: widget.isMobile ? 3 : 2,
          style: TextStyle(fontSize: widget.isMobile ? 16 : 14),
          decoration: InputDecoration(
            hintText: 'Enter instructions (e.g., "Match the following countries with their capitals:")',
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
          ),
        ),

        const SizedBox(height: 20),

        // Pair count controls
        Row(
          children: [
            Text(
              'Number of pairs:',
              style: TextStyle(
                fontSize: widget.isMobile ? 16 : 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _pairCount > 2 ? _removePair : null,
              icon: const Icon(Icons.remove_circle_outline),
              iconSize: 20,
              color: _pairCount > 2 ? AppColors.primary : Colors.grey,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$_pairCount',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            IconButton(
              onPressed: _pairCount < 5 ? _addPair : null,
              icon: const Icon(Icons.add_circle_outline),
              iconSize: 20,
              color: _pairCount < 5 ? AppColors.primary : Colors.grey,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Column headers
        Row(
          children: [
            Expanded(
              child: Text(
                'Column A',
                style: TextStyle(
                  fontSize: widget.isMobile ? 14 : 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Column B',
                style: TextStyle(
                  fontSize: widget.isMobile ? 14 : 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Matching pairs input
        Column(
          children: List.generate(_pairCount, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  // Left column item
                  Expanded(
                    child: TextField(
                      controller: _leftColumnControllers[index],
                      style: TextStyle(fontSize: widget.isMobile ? 14 : 13),
                      decoration: InputDecoration(
                        hintText: 'Item ${index + 1}',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                        contentPadding: EdgeInsets.all(widget.isMobile ? 12 : 10),
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(8),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Arrow indicator
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward,
                      color: AppColors.textSecondary,
                      size: 16,
                    ),
                  ),

                  // Right column item
                  Expanded(
                    child: TextField(
                      controller: _rightColumnControllers[index],
                      style: TextStyle(fontSize: widget.isMobile ? 14 : 13),
                      decoration: InputDecoration(
                        hintText: 'Match ${index + 1}',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                        contentPadding: EdgeInsets.all(widget.isMobile ? 12 : 10),
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(8),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + index), // A, B, C...
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),

        // Validation indicator
            () {
          int validPairs = 0;
          for (int i = 0; i < _pairCount; i++) {
            if (_leftColumnControllers[i].text.trim().isNotEmpty &&
                _rightColumnControllers[i].text.trim().isNotEmpty) {
              validPairs++;
            }
          }

          if (validPairs > 0) {
            return Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: validPairs >= 2
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    validPairs >= 2 ? Icons.check_circle_outline : Icons.warning_amber,
                    size: 16,
                    color: validPairs >= 2 ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$validPairs valid pair${validPairs != 1 ? 's' : ''} ${validPairs < 2 ? '(minimum 2 required)' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: validPairs >= 2 ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }(),

        // Optional checkbox
        InkWell(
          onTap: () => setState(() => _isOptional = !_isOptional),
          borderRadius: BorderRadius.circular(8),
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

        const SizedBox(height: 24),

        // Action buttons (kept for backward compatibility, but coordinator button is primary)
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
          const SizedBox(height: 8),
          Text(
            'Please create at least 2 complete matching pairs',
            style: TextStyle(
              color: AppColors.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}