// lib/core/ai/services/groq_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Result of AI text polishing with changes tracked
class PolishResult {
  final String original;
  final String polished;
  final bool hasChanges;
  final List<String> changesSummary;

  PolishResult({
    required this.original,
    required this.polished,
    required this.hasChanges,
    required this.changesSummary,
  });

  factory PolishResult.noChanges(String text) {
    return PolishResult(
      original: text,
      polished: text,
      hasChanges: false,
      changesSummary: [],
    );
  }
}

class GroqService {
  // API key is loaded from .env file
  static String get apiKey => dotenv.get('GROQ_API_KEY', fallback: '');
  static const baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const timeoutDuration = Duration(seconds: 15);
  static const maxRetries = 3;

  /// Toggle to enable dry-run mode (AI polishing flow without making actual changes)
  /// When true: Shows loading & review dialogs, but returns original text unchanged
  /// When false: Calls Groq API for actual AI polishing
  static bool isDryRun = true;

  /// Polish educational question text with grammar, spelling, and punctuation fixes
  ///
  /// Optional [questionType] parameter provides context to the AI for better understanding
  /// of the question format (e.g., 'mcq', 'short_answer', 'fill_in_blanks', etc.)
  static Future<PolishResult> polishText(String text, {String? questionType}) async {
    if (text.trim().isEmpty) {
      return PolishResult.noChanges(text);
    }

    // Dry-run mode: skip API call and return original unchanged
    if (isDryRun) {
      return PolishResult.noChanges(text);
    }

    final systemPrompt = _buildSystemPrompt(questionType);
    final userPrompt = _buildUserPrompt(text, questionType);

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse(baseUrl),
              headers: {
                'Authorization': 'Bearer $apiKey',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'model': 'llama-3.1-8b-instant',
                'messages': [
                  {
                    'role': 'system',
                    'content': systemPrompt
                  },
                  {
                    'role': 'user',
                    'content': userPrompt
                  }
                ],
                'temperature': 0.1,
                'max_tokens': 500,
              }),
            )
            .timeout(timeoutDuration);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final polished = data['choices'][0]['message']['content'].trim();

          // Detect if changes were made
          final hasChanges = polished != text.trim();
          final changes = hasChanges ? _detectChanges(text, polished) : <String>[];

          return PolishResult(
            original: text,
            polished: polished,
            hasChanges: hasChanges,
            changesSummary: changes,
          );
        } else if (response.statusCode == 429) {
          // Rate limit - wait and retry
          if (attempt < maxRetries - 1) {
            await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
            continue;
          }
          throw Exception('Rate limit exceeded. Please try again later.');
        } else {
          throw Exception('API error: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        if (attempt == maxRetries - 1) {
          // Last attempt failed
          throw Exception('Failed to polish text after $maxRetries attempts: $e');
        }
        // Retry after delay
        await Future.delayed(Duration(seconds: attempt + 1));
      }
    }

    // Fallback: return original text if all retries failed
    return PolishResult.noChanges(text);
  }

  /// Detect changes between original and polished text (simple word-level diff)
  static List<String> _detectChanges(String original, String polished) {
    final changes = <String>[];

    // Simple word comparison
    final originalWords = original.split(RegExp(r'\s+'));
    final polishedWords = polished.split(RegExp(r'\s+'));

    // Track word replacements
    for (int i = 0; i < originalWords.length && i < polishedWords.length; i++) {
      if (originalWords[i] != polishedWords[i]) {
        changes.add('${originalWords[i]} → ${polishedWords[i]}');
      }
    }

    // Check for added/removed words
    if (polishedWords.length > originalWords.length) {
      changes.add('Added ${polishedWords.length - originalWords.length} word(s)');
    } else if (originalWords.length > polishedWords.length) {
      changes.add('Removed ${originalWords.length - polishedWords.length} word(s)');
    }

    return changes.take(5).toList(); // Limit to first 5 changes
  }

  /// Build system prompt with question-type-specific guidance
  static String _buildSystemPrompt(String? questionType) {
    final basePrompt = 'You are a proofreader for Papercraft, a question paper creation tool for teachers.\n\n'
        'TASK: Fix ONLY spelling, grammar, and punctuation errors. Do NOT rephrase or change meaning.\n\n'
        'CRITICAL CONSTRAINTS:\n'
        '1. Keep questions exactly as intended - preserve difficulty level and wording intent\n'
        '2. Do NOT convert questions to answers or provide explanations\n'
        '3. Do NOT add, remove, or change words except to fix spelling/grammar\n'
        '4. Preserve ALL technical terms, numbers, formulas, variables, and names exactly\n'
        '5. If a question needs major restructuring, return it unchanged with no explanation\n\n'
        'BLANKS (____) - ABSOLUTELY SACRED:\n'
        '6. NEVER fill in blanks marked with underscores (____)\n'
        '7. NEVER replace ____ with any words\n'
        '8. Keep all blanks exactly as-is in output\n\n'
        'OUTPUT:\n'
        '9. Return ONLY the corrected text with no explanations\n'
        '10. Preserve original formatting and line breaks\n\n'
        'EXAMPLES - CORRECT:\n'
        'Input: "What is photosyntesis?"\n'
        'Output: "What is photosynthesis?"\n\n'
        'Input: "Mammals are ____ animals"\n'
        'Output: "Mammals are ____ animals"\n\n'
        'EXAMPLES - WRONG (NEVER DO):\n'
        'Input: "Mammals are ____ animals"\n'
        'Output: "Mammals are warm-blooded animals" ❌\n\n'
        'Remember: Fix spelling/grammar only. Keep questions as questions. Never fill blanks.';

    // Add question-type-specific guidance
    if (questionType != null && questionType.isNotEmpty) {
      switch (questionType.toLowerCase()) {
        case 'mcq':
        case 'multiple_choice':
          return basePrompt +
              '\n\nQUESTION TYPE: Multiple Choice\n'
              'Context: You are proofreading a multiple-choice option in context of its question. Fix ONLY spelling mistakes in the option. Do NOT rephrase, add, or remove words. Do NOT change meaning or difficulty of the option.';
        case 'short_answer':
          return basePrompt +
              '\n\nQUESTION TYPE: Short Answer\n'
              'Context: This is a short-answer question. Proofreading should improve clarity while maintaining the question\'s difficulty level.';
        case 'fill_in_blanks':
        case 'fill_blanks':
          return basePrompt +
              '\n\nQUESTION TYPE: Fill in the Blanks\n'
              'Context: This question has [BLANK] markers that represent answer spaces. These are CRITICAL - never modify or fill them.';
        case 'missing_letters':
          return basePrompt +
              '\n\nQUESTION TYPE: Missing Letters\n'
              'Context: This question has [HIDDEN] markers representing incomplete words. These are CRITICAL - never modify or fill them.';
        case 'match_following':
        case 'matching':
          return basePrompt +
              '\n\nQUESTION TYPE: Matching/Pairing\n'
              'Context: This is a matching question with items to pair. Fix only spelling/grammar in the items. Do NOT change the pairing logic or structure.';
        case 'true_false':
          return basePrompt +
              '\n\nQUESTION TYPE: True/False\n'
              'Context: This is a true/false question. Ensure the question is clear and unambiguous after proofreading.';
        default:
          return basePrompt;
      }
    }

    return basePrompt;
  }

  /// Build user prompt with question-type context
  static String _buildUserPrompt(String text, String? questionType) {
    if (questionType != null && questionType.isNotEmpty) {
      if (questionType.toLowerCase() == 'mcq') {
        // Special handling for MCQ - provide clearer instructions for option extraction
        return 'Proofread this multiple-choice question and option. Fix ONLY spelling mistakes:\n\n$text\n\nReturn the output in exactly this format:\nQuestion: [proofread question]\nOption: [proofread option]';
      }
      return 'This is a $questionType exam question. Proofread it and fix only spelling/grammar:\n\n$text';
    }
    return 'Proofread this exam question (fix only spelling/grammar):\n\n$text';
  }

  /// Polish multiple questions in a single API call (per-section optimization)
  ///
  /// This method sends all questions in a section to Groq at once,
  /// reducing API calls from N to 1 and significantly improving performance.
  ///
  /// [questions] - List of question texts to polish
  /// [questionTypes] - Optional list of question types corresponding to each question
  /// Returns a List of PolishResult in the same order as input questions
  static Future<List<PolishResult>> polishSection(
    List<String> questions, {
    List<String>? questionTypes,
  }) async {
    if (questions.isEmpty) {
      return [];
    }

    // Dry-run mode: skip API call and return all originals unchanged
    if (isDryRun) {
      return List.generate(
        questions.length,
        (i) => PolishResult.noChanges(questions[i]),
      );
    }

    // Filter out empty questions
    final nonEmptyQuestions = <({int originalIndex, String text, String? type})>[];
    for (int i = 0; i < questions.length; i++) {
      if (questions[i].trim().isNotEmpty) {
        nonEmptyQuestions.add((
          originalIndex: i,
          text: questions[i],
          type: questionTypes != null && i < questionTypes.length ? questionTypes[i] : null,
        ));
      }
    }

    if (nonEmptyQuestions.isEmpty) {
      // Return no-changes results for all empty questions
      return List.generate(
        questions.length,
        (i) => PolishResult.noChanges(questions[i]),
      );
    }

    // Build section-specific system prompt
    final systemPrompt = _buildSectionSystemPrompt(questionTypes);

    // Format all questions with markers for extraction
    final formattedQuestions = nonEmptyQuestions.map((q) {
      return '[QUESTION_${q.originalIndex}_START]\n${q.text}\n[QUESTION_${q.originalIndex}_END]';
    }).join('\n\n');

    // Build user prompt requesting structured output
    final userPrompt = '''Proofread these exam questions (fix only spelling/grammar):

$formattedQuestions

IMPORTANT: Return results in EXACTLY this format, preserving the markers:
[QUESTION_X_START]
[polished text here]
[QUESTION_X_END]

Return one polished question per pair of markers. Do NOT add any other text.''';

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse(baseUrl),
              headers: {
                'Authorization': 'Bearer $apiKey',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'model': 'llama-3.1-8b-instant',
                'messages': [
                  {
                    'role': 'system',
                    'content': systemPrompt,
                  },
                  {
                    'role': 'user',
                    'content': userPrompt,
                  }
                ],
                'temperature': 0.1,
                'max_tokens': 2000, // Increased for multiple questions
              }),
            )
            .timeout(Duration(seconds: 30)); // Longer timeout for section processing

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final responseText = data['choices'][0]['message']['content'].trim();

          // Parse responses using regex to extract individual polished questions
          final results = _parseSectionResults(responseText, questions, nonEmptyQuestions);
          return results;
        } else if (response.statusCode == 429) {
          // Rate limit - wait and retry
          if (attempt < maxRetries - 1) {
            await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
            continue;
          }
          throw Exception('Rate limit exceeded for section polishing. Please try again later.');
        } else {
          throw Exception('API error: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        if (attempt == maxRetries - 1) {
          // Last attempt failed - return original questions
          return List.generate(
            questions.length,
            (i) => PolishResult.noChanges(questions[i]),
          );
        }
        // Retry after delay
        await Future.delayed(Duration(seconds: attempt + 1));
      }
    }

    // Fallback: return all original questions if all retries failed
    return List.generate(
      questions.length,
      (i) => PolishResult.noChanges(questions[i]),
    );
  }

  /// Build system prompt for section-level polishing with type information
  static String _buildSectionSystemPrompt(List<String>? questionTypes) {
    final basePrompt = 'You are a proofreader for Papercraft, a question paper creation tool for teachers.\n\n'
        'TASK: Fix ONLY spelling, grammar, and punctuation errors in ALL provided questions. Do NOT rephrase or change meaning.\n\n'
        'CRITICAL CONSTRAINTS:\n'
        '1. Keep questions exactly as intended - preserve difficulty level and wording intent\n'
        '2. Do NOT convert questions to answers or provide explanations\n'
        '3. Do NOT add, remove, or change words except to fix spelling/grammar\n'
        '4. Preserve ALL technical terms, numbers, formulas, variables, and names exactly\n'
        '5. If a question needs major restructuring, return it unchanged with no explanation\n\n'
        'BLANKS (____) - ABSOLUTELY SACRED:\n'
        '6. NEVER fill in blanks marked with underscores (____)\n'
        '7. NEVER replace ____ with any words\n'
        '8. Keep all blanks exactly as-is in output\n\n'
        'SECTION PROCESSING:\n'
        '9. Process all questions independently\n'
        '10. Maintain exact formatting and line breaks\n'
        '11. Return results using the [QUESTION_X_START/END] markers provided\n\n'
        'OUTPUT:\n'
        '12. Return ONLY the corrected text within markers - NO explanations\n'
        '13. Preserve original formatting and line breaks\n'
        '14. Process questions in order\n\n'
        'EXAMPLES:\n'
        'Input: [QUESTION_0_START]What is photosyntesis?[QUESTION_0_END]\n'
        'Output: [QUESTION_0_START]What is photosynthesis?[QUESTION_0_END]\n\n'
        'Remember: Fix spelling/grammar only. Keep questions as questions. Never fill blanks.';

    // Add question-type context if available
    if (questionTypes != null && questionTypes.isNotEmpty) {
      final typeInfo = questionTypes.where((t) => t.isNotEmpty).toSet().join(', ');
      if (typeInfo.isNotEmpty) {
        return basePrompt + '\n\nQUESTION TYPES IN THIS SECTION: $typeInfo\n'
            'Context: Handle each question type appropriately (MCQ options, matching pairs, fill-in-blanks, etc.).';
      }
    }

    return basePrompt;
  }

  /// Parse section polishing results from Groq response
  static List<PolishResult> _parseSectionResults(
    String responseText,
    List<String> originalQuestions,
    List<({int originalIndex, String text, String? type})> nonEmptyQuestions,
  ) {
    final results = <PolishResult>[];

    // Extract all polished questions using regex
    final regex = RegExp(
      r'\[QUESTION_(\d+)_START\](.*?)\[QUESTION_\1_END\]',
      dotAll: true,
    );

    // Create a map of index -> polished text for quick lookup
    final polishedMap = <int, String>{};
    for (final match in regex.allMatches(responseText)) {
      final questionIndex = int.tryParse(match.group(1) ?? '');
      final polishedText = match.group(2)?.trim() ?? '';

      if (questionIndex != null && polishedText.isNotEmpty) {
        polishedMap[questionIndex] = polishedText;
      }
    }

    // Build results in original order, using polished text if available
    for (int i = 0; i < originalQuestions.length; i++) {
      final original = originalQuestions[i].trim();

      if (original.isEmpty) {
        results.add(PolishResult.noChanges(originalQuestions[i]));
      } else if (polishedMap.containsKey(i)) {
        final polished = polishedMap[i]!;
        final hasChanges = polished != original;
        final changes = hasChanges ? _detectChanges(original, polished) : <String>[];

        results.add(PolishResult(
          original: original,
          polished: polished,
          hasChanges: hasChanges,
          changesSummary: changes,
        ));
      } else {
        // If parsing failed for this question, return original
        results.add(PolishResult.noChanges(originalQuestions[i]));
      }
    }

    return results;
  }
}