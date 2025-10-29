// features/question_papers/pages/widgets/question_input/question_list_widget.dart
import 'package:flutter/material.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../../../core/presentation/constants/ui_constants.dart';
import '../../../../paper_workflow/domain/entities/question_entity.dart';

class QuestionListWidget extends StatelessWidget {
  final String sectionName;
  final List<Question> questions;
  final Function(int index, Question updatedQuestion) onEditQuestion;
  final Function(int index) onRemoveQuestion;
  final Function(int oldIndex, int newIndex)? onReorderQuestions;
  final bool isMobile;

  const QuestionListWidget({
    super.key,
    required this.sectionName,
    required this.questions,
    required this.onEditQuestion,
    required this.onRemoveQuestion,
    this.onReorderQuestions,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Questions Added (${questions.length})',
              style: TextStyle(
                fontSize: isMobile ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (onReorderQuestions != null && questions.length > 1) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.drag_indicator_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'Drag to reorder',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: UIConstants.spacing12),
        Container(
          constraints: BoxConstraints(maxHeight: isMobile ? 300 : 250),
          child: onReorderQuestions != null && questions.length > 1
              ? ReorderableListView.builder(
                  shrinkWrap: false, // Performance fix: removed shrinkWrap
                  itemCount: questions.length,
                  onReorder: onReorderQuestions!,
                  buildDefaultDragHandles: false,
                  itemBuilder: (context, index) {
                    final question = questions[index];
                    return _buildQuestionCard(context, question, index, key: ValueKey('question_$index'));
                  },
                )
              : ListView.builder(
                  shrinkWrap: false, // Performance fix: removed shrinkWrap
                  itemCount: questions.length,
                  addAutomaticKeepAlives: false, // Don't keep offscreen items alive
                  addRepaintBoundaries: true, // Isolate repaints
                  cacheExtent: 100, // Limited cache for better memory
                  itemBuilder: (context, index) {
                    final question = questions[index];
                    return _buildQuestionCard(context, question, index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(BuildContext context, Question question, int index, {Key? key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle (if reordering enabled)
          if (onReorderQuestions != null && questions.length > 1)
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.drag_handle_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
            ),

          // Question number badge
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primary10,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: UIConstants.fontSizeSmall,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Question content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.text,
                  style: TextStyle(fontSize: isMobile ? 14 : 13, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: UIConstants.spacing8),

                // SPECIAL HANDLING FOR MATCHING QUESTIONS
                if (question.type == 'match_following' && question.options != null) ...[
                  _buildMatchingPairs(question.options!),
                ]
                // MCQ and other question types
                else if (question.options != null && question.options!.isNotEmpty) ...[
                  Text(
                    'Options: ${question.options!.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],

                if (question.subQuestions.isNotEmpty) ...[
                  SizedBox(height: UIConstants.spacing4),
                  Text(
                    'Sub-questions: ${question.subQuestions.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],

                SizedBox(height: UIConstants.spacing4),
                Row(
                  children: [
                    Text(
                      '${question.marks} marks',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (question.isOptional) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning10,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Optional',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Action buttons
          Column(
            children: [
              IconButton(
                onPressed: () {
                  _showEditDialog(context, question, index);
                },
                icon: const Icon(Icons.edit, size: 16),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary10,
                  minimumSize: const Size(28, 28),
                ),
                color: AppColors.primary,
              ),
              SizedBox(height: UIConstants.spacing4),
              IconButton(
                onPressed: () {
                  _showDeleteConfirmation(context, index);
                },
                icon: const Icon(Icons.delete_outline, size: 16),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.error10,
                  minimumSize: const Size(28, 28),
                ),
                color: AppColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatchingPairs(List<String> options) {

    final separatorIndex = options.indexOf('---SEPARATOR---');
    if (separatorIndex == -1) {
      return const SizedBox.shrink();
    }

    final leftColumn = options.sublist(0, separatorIndex);
    final rightColumn = options.sublist(separatorIndex + 1);
    final pairCount = leftColumn.length < rightColumn.length
        ? leftColumn.length
        : rightColumn.length;


    return Container(
      padding: const EdgeInsets.all(UIConstants.paddingSmall),
      decoration: BoxDecoration(
        color: AppColors.primary05,
        borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
        border: Border.all(color: AppColors.primary20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Column A',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Column B',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: UIConstants.spacing6),
          ...List.generate(pairCount, (pairIndex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      leftColumn[pairIndex],
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward,
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rightColumn[pairIndex],
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, Question question, int index) {

    final textController = TextEditingController(text: question.text);
    bool isOptional = question.isOptional;

    // For MCQ questions, prepare option controllers
    List<TextEditingController>? optionControllers;
    if (question.options != null && question.type != 'match_following') {
      optionControllers = List.generate(4, (i) =>
          TextEditingController(
              text: i < question.options!.length ? question.options![i] : ''
          ));
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit Question ${index + 1}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: textController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: optionControllers != null
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onSubmitted: (_) {
                    if (optionControllers != null) {
                      FocusScope.of(context).nextFocus();
                    } else {
                      final updatedQuestion = question.copyWith(
                        text: textController.text.trim(),
                        isOptional: isOptional,
                      );
                      onEditQuestion(index, updatedQuestion);
                      Navigator.pop(context);
                    }
                  },
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Question Text',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: UIConstants.spacing16),

                // Show note for matching questions
                if (question.type == 'match_following') ...[
                  Container(
                    padding: const EdgeInsets.all(UIConstants.paddingSmall),
                    decoration: BoxDecoration(
                      color: AppColors.warning10,
                      borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Matching pairs cannot be edited here. Delete and recreate if needed.',
                            style: TextStyle(fontSize: UIConstants.fontSizeSmall, color: AppColors.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: UIConstants.spacing16),
                ],

                // MCQ options with Enter key navigation
                if (optionControllers != null) ...[
                  const Text('Options:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: UIConstants.spacing8),
                  ...optionControllers.asMap().entries.map((e) {
                    final optionIndex = e.key;
                    final optionController = e.value;
                    final label = String.fromCharCode(65 + optionIndex);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: optionController,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: optionIndex == optionControllers!.length - 1
                            ? TextInputAction.done
                            : TextInputAction.next,
                        onSubmitted: (_) {
                          if (optionIndex == optionControllers!.length - 1) {
                            final updatedQuestion = question.copyWith(
                              text: textController.text.trim(),
                              isOptional: isOptional,
                              options: optionControllers.map((c) => c.text.trim())
                                  .where((t) => t.isNotEmpty).toList(),
                            );
                            onEditQuestion(index, updatedQuestion);
                            Navigator.pop(context);
                          } else {
                            FocusScope.of(context).nextFocus();
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Option $label',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    );
                  }).toList(),
                  SizedBox(height: UIConstants.spacing16),
                ],

                // Optional checkbox
                CheckboxListTile(
                  value: isOptional,
                  onChanged: (value) {
                    setState(() => isOptional = value ?? false);
                  },
                  title: const Text('Optional question'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {

                final updatedQuestion = question.copyWith(
                  text: textController.text.trim(),
                  isOptional: isOptional,
                  options: optionControllers?.map((c) => c.text.trim())
                      .where((t) => t.isNotEmpty).toList(),
                );

                onEditQuestion(index, updatedQuestion);
                Navigator.pop(context);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, int index) {

    final question = questions[index];
    final questionPreview = question.text.length > 100
        ? '${question.text.substring(0, 100)}...'
        : question.text;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text('Delete Question ${index + 1}?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action cannot be undone.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary10,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          question.type.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${question.marks} marks',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    questionPreview,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              onRemoveQuestion(index);
              Navigator.pop(context);

              // Show undo snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Question ${index + 1} deleted'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_rounded, size: 18),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}