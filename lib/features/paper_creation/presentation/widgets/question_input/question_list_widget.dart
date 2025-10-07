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
  final bool isMobile;

  const QuestionListWidget({
    super.key,
    required this.sectionName,
    required this.questions,
    required this.onEditQuestion,
    required this.onRemoveQuestion,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('🔍 QuestionListWidget build - Section: $sectionName, Questions: ${questions.length}');

    if (questions.isEmpty) {
      debugPrint('⚠️ No questions to display for section: $sectionName');
      return const SizedBox.shrink();
    }

    // Debug each question
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      debugPrint('📝 Question ${i + 1}: ${q.text.substring(0, q.text.length > 50 ? 50 : q.text.length)}...');
      debugPrint('   Type: ${q.type}, Marks: ${q.marks}, Optional: ${q.isOptional}');
      debugPrint('   Options: ${q.options?.length ?? 0}, SubQuestions: ${q.subQuestions.length}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Questions Added (${questions.length})',
          style: TextStyle(
            fontSize: isMobile ? 18 : 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: UIConstants.spacing12),
        Container(
          constraints: BoxConstraints(maxHeight: isMobile ? 300 : 250),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final question = questions[index];
              return _buildQuestionCard(context, question, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(BuildContext context, Question question, int index) {
    return Container(
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
          // Question number badge
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
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
                          color: AppColors.warning.withOpacity(0.1),
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
                  debugPrint('✏️ Edit button clicked for question ${index + 1}');
                  _showEditDialog(context, question, index);
                },
                icon: const Icon(Icons.edit, size: 16),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  minimumSize: const Size(28, 28),
                ),
                color: AppColors.primary,
              ),
              SizedBox(height: UIConstants.spacing4),
              IconButton(
                onPressed: () {
                  debugPrint('🗑️ Delete button clicked for question ${index + 1}');
                  _showDeleteConfirmation(context, index);
                },
                icon: const Icon(Icons.delete_outline, size: 16),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.error.withOpacity(0.1),
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
    debugPrint('🔗 Building matching pairs - Total options: ${options.length}');

    final separatorIndex = options.indexOf('---SEPARATOR---');
    if (separatorIndex == -1) {
      debugPrint('⚠️ No separator found in matching question options');
      return const SizedBox.shrink();
    }

    final leftColumn = options.sublist(0, separatorIndex);
    final rightColumn = options.sublist(separatorIndex + 1);
    final pairCount = leftColumn.length < rightColumn.length
        ? leftColumn.length
        : rightColumn.length;

    debugPrint('📊 Matching pairs - Left: ${leftColumn.length}, Right: ${rightColumn.length}, Pairs: $pairCount');

    return Container(
      padding: const EdgeInsets.all(UIConstants.paddingSmall),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
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
    debugPrint('💬 Opening edit dialog for question ${index + 1}');
    debugPrint('   Question type: ${question.type}');
    debugPrint('   Has options: ${question.options != null}');
    debugPrint('   Options count: ${question.options?.length ?? 0}');

    final textController = TextEditingController(text: question.text);
    bool isOptional = question.isOptional;

    // For MCQ questions, prepare option controllers
    List<TextEditingController>? optionControllers;
    if (question.options != null && question.type != 'match_following') {
      optionControllers = List.generate(4, (i) =>
          TextEditingController(
              text: i < question.options!.length ? question.options![i] : ''
          ));
      debugPrint('📝 Created ${optionControllers.length} option controllers');
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
                      debugPrint('✅ Saving question without options via Enter key');
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
                      color: AppColors.warning.withOpacity(0.1),
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
                            debugPrint('✅ Saving question with options via Enter key');
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
                    debugPrint('☑️ Optional checkbox toggled: $value');
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
                debugPrint('❌ Edit dialog cancelled');
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                debugPrint('✅ Updating question ${index + 1}');
                debugPrint('   New text: ${textController.text.trim()}');
                debugPrint('   Optional: $isOptional');

                final updatedQuestion = question.copyWith(
                  text: textController.text.trim(),
                  isOptional: isOptional,
                  options: optionControllers?.map((c) => c.text.trim())
                      .where((t) => t.isNotEmpty).toList(),
                );

                debugPrint('   Updated options: ${updatedQuestion.options?.length ?? 0}');
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
    debugPrint('🗑️ Opening delete confirmation for question ${index + 1}');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Question ${index + 1}'),
        content: const Text('Are you sure you want to delete this question?'),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('❌ Delete cancelled');
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              debugPrint('✅ Deleting question ${index + 1}');
              onRemoveQuestion(index);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}