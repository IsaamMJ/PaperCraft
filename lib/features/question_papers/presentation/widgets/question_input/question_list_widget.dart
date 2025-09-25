// features/question_papers/presentation/widgets/question_input/question_list_widget.dart
import 'package:flutter/material.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../domain/entities/question_entity.dart';

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
    if (questions.isEmpty) return const SizedBox.shrink();

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
        const SizedBox(height: 12),
        Container(
          constraints: BoxConstraints(maxHeight: isMobile ? 200 : 150),
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

  Widget _buildQuestionCard(BuildContext context, Question question,
      int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
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
                  fontSize: 12,
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
                  style: TextStyle(fontSize: isMobile ? 14 : 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (question.options != null &&
                    question.options!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Options: ${question.options!.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (question.subQuestions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Sub-questions: ${question.subQuestions.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
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
                onPressed: () => _showEditDialog(context, question, index),
                icon: const Icon(Icons.edit, size: 16),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  minimumSize: const Size(28, 28),
                ),
                color: AppColors.primary,
              ),
              const SizedBox(height: 4),
              IconButton(
                onPressed: () => _showDeleteConfirmation(context, index),
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

  void _showEditDialog(BuildContext context, Question question, int index) {
    final textController = TextEditingController(text: question.text);
    bool isOptional = question.isOptional;

    // For MCQ questions, prepare option controllers
    List<TextEditingController>? optionControllers;
    if (question.options != null) {
      optionControllers = List.generate(4, (i) =>
          TextEditingController(
              text: i < question.options!.length ? question.options![i] : ''
          ));
    }

    showDialog(
      context: context,
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setState) =>
                AlertDialog(
                  title: Text('Edit Question ${index + 1}'),
                  content: SizedBox(
                    width: 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: textController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Question Text',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // MCQ options
                        if (optionControllers != null) ...[
                          const Text('Options:',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          ...optionControllers
                              .asMap()
                              .entries
                              .map((e) {
                            final label = String.fromCharCode(65 + e.key);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: TextField(
                                controller: e.value,
                                decoration: InputDecoration(
                                  labelText: 'Option $label',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 16),
                        ],

                        // Optional checkbox
                        CheckboxListTile(
                          value: isOptional,
                          onChanged: (value) =>
                              setState(() => isOptional = value ?? false),
                          title: const Text('Optional question'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
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
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text('Delete Question ${index + 1}'),
            content: const Text(
                'Are you sure you want to delete this question?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  onRemoveQuestion(index);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }
}