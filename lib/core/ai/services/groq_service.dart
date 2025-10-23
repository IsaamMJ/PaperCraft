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

  /// Polish educational question text with grammar, spelling, and punctuation fixes
  static Future<PolishResult> polishText(String text) async {
    if (text.trim().isEmpty) {
      return PolishResult.noChanges(text);
    }

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
                    'content':
                        'You are a proofreader for Papercraft, a question paper creation tool for teachers.\n\n'
                        'TASK: Fix ONLY spelling, grammar, and punctuation errors. Do NOT rephrase or change meaning.\n\n'
                        'CRITICAL CONSTRAINTS:\n'
                        '1. Keep questions exactly as intended - preserve difficulty level and wording intent\n'
                        '2. Do NOT convert questions to answers or provide explanations\n'
                        '3. Do NOT add, remove, or change words except to fix spelling/grammar\n'
                        '4. Preserve ALL technical terms, numbers, formulas, variables, and names exactly\n'
                        '5. If a question needs major restructuring, return it unchanged with no explanation\n\n'
                        'BLANKS (____) - ABSOLUTELY SACRED:\n'
                        '6. NEVER fill in blanks marked with underscores (____)\n'
                        '7. NEVER replace ____  with any words\n'
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
                        'Remember: Fix spelling/grammar only. Keep questions as questions. Never fill blanks.'
                  },
                  {
                    'role': 'user',
                    'content': 'Proofread this exam question (fix only spelling/grammar):\n\n' + text
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
}