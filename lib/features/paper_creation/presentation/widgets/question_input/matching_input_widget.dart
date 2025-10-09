// features/question_papers/pages/widgets/question_input/matching_input_widget.dart
import 'package:flutter/material.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../../../core/presentation/constants/ui_constants.dart';
import '../../../../paper_workflow/domain/entities/question_entity.dart';

class MatchingInputWidget extends StatefulWidget {
  final Function(Question) onQuestionAdded;
  final bool isMobile;
  final int requiredPairs; // This is the number of pairs needed for this matching question
  final bool isAdmin;

  const MatchingInputWidget({
    super.key,
    required this.onQuestionAdded,
    required this.isMobile,
    required this.requiredPairs,
    required this.isAdmin,
  });

  @override
  State<MatchingInputWidget> createState() => MatchingInputWidgetState();
}

class MatchingInputWidgetState extends State<MatchingInputWidget> with AutomaticKeepAliveClientMixin {
  final _questionController = TextEditingController();
  final List<TextEditingController> _leftColumnControllers = List.generate(10, (_) => TextEditingController());
  final List<TextEditingController> _rightColumnControllers = List.generate(10, (_) => TextEditingController());
  bool _isOptional = false;
  late int _pairCount;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pairCount = widget.requiredPairs; // Set to exactly the required number of pairs
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

    // Check if ALL required pairs are filled
    int validPairs = 0;
    for (int i = 0; i < _pairCount; i++) {
      if (_leftColumnControllers[i].text.trim().isNotEmpty &&
          _rightColumnControllers[i].text.trim().isNotEmpty) {
        validPairs++;
      }
    }
    return validPairs == _pairCount;
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
    });
  }

  void _addQuestion() {
    if (!_isValid) return;

    // Collect all pairs
    final List<String> leftItems = [];
    final List<String> rightItems = [];

    for (int i = 0; i < _pairCount; i++) {
      final left = _leftColumnControllers[i].text.trim();
      final right = _rightColumnControllers[i].text.trim();
      leftItems.add(left);
      rightItems.add(right);
    }

    // FIXED: Create the question with proper type and structure
    final question = Question(
      text: _questionController.text.trim(),
      type: 'match_following', // Use the correct type from your exam configuration
      options: [...leftItems, '---SEPARATOR---', ...rightItems], // Store both columns
      marks: _pairCount, // Total marks = number of pairs
      subQuestions: [], // Keep empty for matching questions
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
        SizedBox(height: UIConstants.spacing12),

        // Instructions
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Create 1 matching question with $_pairCount pairs - students will match Column A to Column B',
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

        // Question instruction
        TextField(
          controller: _questionController,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.newline,
          maxLines: widget.isMobile ? 3 : 2,
          style: TextStyle(fontSize: widget.isMobile ? 16 : 14),
          decoration: InputDecoration(
            hintText: 'Enter instructions (e.g., "Match the following countries with their capitals:")',
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

        SizedBox(height: UIConstants.spacing20),

        // Show required pairs count
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
            border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.pin, color: AppColors.secondary, size: 16),
              const SizedBox(width: 8),
              Text(
                'Required pairs: $_pairCount',
                style: TextStyle(
                  fontSize: widget.isMobile ? 14 : 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
              const Spacer(),
              Text(
                'Total marks: $_pairCount',
                style: TextStyle(
                  fontSize: widget.isMobile ? 12 : 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: UIConstants.spacing16),

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

        SizedBox(height: UIConstants.spacing12),

        // Matching pairs input with Enter key navigation
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
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                      style: TextStyle(fontSize: widget.isMobile ? 14 : 13),
                      decoration: InputDecoration(
                        hintText: 'Item ${index + 1}',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                        contentPadding: EdgeInsets.all(widget.isMobile ? 12 : 10),
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(UIConstants.paddingSmall),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
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
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: index == _pairCount - 1 ? TextInputAction.done : TextInputAction.next,
                      onSubmitted: (value) {
                        if (index == _pairCount - 1) {
                          FocusScope.of(context).unfocus();
                          if (_isValid) _addQuestion();
                        } else {
                          FocusScope.of(context).nextFocus();
                        }
                      },
                      style: TextStyle(fontSize: widget.isMobile ? 14 : 13),
                      decoration: InputDecoration(
                        hintText: 'Match ${index + 1}',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                        contentPadding: EdgeInsets.all(widget.isMobile ? 12 : 10),
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(UIConstants.paddingSmall),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.1),
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
        (() {
          int validPairs = 0;
          for (int i = 0; i < _pairCount; i++) {
            if (_leftColumnControllers[i].text.trim().isNotEmpty &&
                _rightColumnControllers[i].text.trim().isNotEmpty) {
              validPairs++;
            }
          }

          return Container(
            padding: const EdgeInsets.all(UIConstants.paddingSmall),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: validPairs == _pairCount
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
            ),
            child: Row(
              children: [
                Icon(
                  validPairs == _pairCount ? Icons.check_circle_outline : Icons.warning_amber,
                  size: 16,
                  color: validPairs == _pairCount ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 8),
                Text(
                  '$validPairs of $_pairCount pairs completed ${validPairs < _pairCount ? '(${_pairCount - validPairs} remaining)' : '✓'}',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeSmall,
                    color: validPairs == _pairCount ? AppColors.success : AppColors.warning,
                  ),
                ),
              ],
            ),
          );
        })(),

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
            'Please complete all $_pairCount matching pairs',
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