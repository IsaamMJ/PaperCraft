// lib/core/ai/services/paper_parse_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../features/catalog/domain/entities/paper_section_entity.dart';
import '../../../features/paper_workflow/domain/entities/question_entity.dart';

/// Result of AI paper parsing
class PaperParseResult {
  final List<PaperSectionEntity> sections;
  final Map<String, List<Question>> questions; // section name -> questions
  final bool success;
  final String? error;

  PaperParseResult({
    required this.sections,
    this.questions = const {},
    required this.success,
    this.error,
  });

  factory PaperParseResult.failure(String error) {
    return PaperParseResult(sections: [], questions: {}, success: false, error: error);
  }
}

/// Service for parsing pasted paper text into structured sections and questions using AI.
/// Uses Groq API with llama-3.3-70b-versatile for structured extraction.
/// Completely separate from the existing GroqService (polish flow).
class PaperParseService {
  static String get _apiKey {
    const compileTimeKey = String.fromEnvironment('GROQ_API_KEY');
    if (compileTimeKey.isNotEmpty) return compileTimeKey;
    return dotenv.get('GROQ_API_KEY', fallback: '');
  }
  static const _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'llama-3.3-70b-versatile';
  static const _timeout = Duration(seconds: 30);

  static const Map<String, String> _typeMapping = {
    'mcq': 'multiple_choice',
    'multiple choice': 'multiple_choice',
    'choose the correct': 'multiple_choice',
    'tick': 'true_false',
    'true or false': 'true_false',
    'true/false': 'true_false',
    'state true': 'true_false',
    'fill in the blanks': 'fill_in_blanks',
    'fill blanks': 'fill_in_blanks',
    'fill in the blank': 'fill_in_blanks',
    'match the following': 'match_following',
    'match': 'match_following',
    'short answer': 'short_answer',
    'answer the following': 'short_answer',
    'answer': 'short_answer',
    'essay': 'short_answer',
    'write': 'short_answer',
    'say': 'short_answer',
    'missing letters': 'missing_letters',
    'fill in the missing': 'missing_letters',
    'word forms': 'word_forms',
    'rearrange': 'word_forms',
    'jumbled': 'word_forms',
    'general': 'short_answer',
    'oral': 'short_answer',
  };

  /// Parse pasted paper text into structured sections AND questions.
  static Future<PaperParseResult> parsePaperText(String text) async {
    if (text.trim().isEmpty) {
      return PaperParseResult.failure('No text provided');
    }

    const useAI = true;

    if (!useAI || _apiKey.isEmpty) {
      debugPrint('[PaperParse] Using local parsing');
      return _parseLocally(text);
    }

    try {
      final result = await _parseWithAI(text);
      if (result.success && result.sections.isNotEmpty) {
        return result;
      }
      debugPrint('[PaperParse] AI returned empty, falling back to local');
      return _parseLocally(text);
    } catch (e) {
      debugPrint('[PaperParse] AI failed: $e, falling back to local');
      return _parseLocally(text);
    }
  }

  /// Parse using Groq AI — extracts both sections and questions
  static Future<PaperParseResult> _parseWithAI(String text) async {
    final prompt = '''You are an exam paper structure and question extractor. Extract each question section AND the individual questions from the paper text below.

RULES:
1. "name" = the ACTUAL instruction text from the paper (e.g., "Tick the correct answer", "Match the following", "Fill in the blanks"). Do NOT use generic names. Strip Roman numerals and marks info.

2. "type" = one of: multiple_choice, true_false, fill_in_blanks, match_following, short_answer, missing_letters, word_forms
   - Tick correct/wrong, state true or false = true_false
   - Choose correct answer, options in brackets = multiple_choice
   - Fill in the blanks with ____ = fill_in_blanks
   - Match Column A to Column B = match_following
   - Answer the following, Write, Explain = short_answer
   - Missing letters like h_ro = missing_letters
   - Jumbled letters, rearrange = word_forms
   - Say, Recite, Oral = short_answer

3. "questions_count" = number of questions

4. "marks_per_question" = total marks / question count

5. "question_texts" = array of the actual question text strings, one per question. Extract the exact text. For MCQ, include the question text only (not options). For fill_blanks, include the sentence with blanks. Strip question numbers (1., 2., etc).

6. "options" = for multiple_choice questions, extract options as array of strings per question. For other types, use null.

7. Ignore group headers like "Section A (Writing)", "Section B (Oral)".

8. If Match the Following has (A) and (B) sub-groups, treat as TWO sections.

9. If two sections have same name, add (A), (B) suffix.

10. CRITICAL for match_following type: Each line has format "Left item - Right item". Extract as:
   - "match_left": array of left-side items (before the dash)
   - "match_right": array of right-side items (after the dash)
   - "questions_count": number of pairs
   - "question_texts": ["Match the following"] (always just one entry)
   Example: "Anu Lululah - haram activities" → match_left: ["Anu Lululah"], match_right: ["haram activities"]

Return ONLY valid JSON array:
[{"name": "...", "type": "...", "questions_count": N, "marks_per_question": N.N, "question_texts": ["q1", "q2"], "options": [["opt1", "opt2"], null], "match_left": null, "match_right": null}]

Paper text:
$text''';

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': 'You are a precise exam paper extractor. Return ONLY valid JSON arrays.'},
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.1,
        'max_tokens': 4000,
      }),
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      return PaperParseResult.failure('API error: ${response.statusCode}');
    }

    final json = jsonDecode(response.body);
    final content = json['choices'][0]['message']['content'] as String;

    final jsonStr = _extractJson(content);
    if (jsonStr == null) {
      return PaperParseResult.failure('Could not parse AI response');
    }

    return _jsonToResult(jsonStr);
  }

  /// Extract JSON array from AI response
  static String? _extractJson(String content) {
    final trimmed = content.trim();
    if (trimmed.startsWith('[')) return trimmed;

    final codeBlockPattern = RegExp(r'```(?:json)?\s*(\[[\s\S]*?\])\s*```');
    final match = codeBlockPattern.firstMatch(trimmed);
    if (match != null) return match.group(1);

    final arrayPattern = RegExp(r'\[[\s\S]*\]');
    final arrayMatch = arrayPattern.firstMatch(trimmed);
    if (arrayMatch != null) return arrayMatch.group(0);

    return null;
  }

  /// Convert JSON to sections + questions
  static PaperParseResult _jsonToResult(String jsonStr) {
    try {
      final List<dynamic> parsed = jsonDecode(jsonStr);
      final sections = <PaperSectionEntity>[];
      final questions = <String, List<Question>>{};
      final usedNames = <String>{};

      for (final item in parsed) {
        final name = (item['name'] as String?) ?? 'Section';
        final type = (item['type'] as String?) ?? 'short_answer';
        final questionsCount = (item['questions_count'] as num?)?.toInt() ??
            (item['questions'] as num?)?.toInt() ?? 0;
        final marksPerQuestion = (item['marks_per_question'] as num?)?.toDouble() ?? 1.0;
        final questionTexts = (item['question_texts'] as List<dynamic>?)
            ?.map((t) => t.toString().trim())
            .where((t) => t.isNotEmpty)
            .toList() ?? [];
        final optionsList = item['options'] as List<dynamic>?;

        if (questionsCount <= 0 && questionTexts.isEmpty) continue;

        // Ensure unique name
        var uniqueName = name;
        if (usedNames.contains(name.toLowerCase())) {
          for (int i = 0; i < 26; i++) {
            final suffix = String.fromCharCode(65 + i);
            final candidate = '$name ($suffix)';
            if (!usedNames.contains(candidate.toLowerCase())) {
              uniqueName = candidate;
              break;
            }
          }
        }
        usedNames.add(uniqueName.toLowerCase());

        final actualCount = questionTexts.isNotEmpty ? questionTexts.length : questionsCount;

        sections.add(PaperSectionEntity(
          name: uniqueName,
          type: type,
          questions: actualCount,
          marksPerQuestion: marksPerQuestion,
        ));

        // Build Question objects
        if (type == 'match_following') {
          // Special handling: build single question with ---SEPARATOR--- format
          final matchLeft = (item['match_left'] as List<dynamic>?)
              ?.map((e) => e.toString().trim()).toList();
          final matchRight = (item['match_right'] as List<dynamic>?)
              ?.map((e) => e.toString().trim()).toList();

          if (matchLeft != null && matchRight != null && matchLeft.isNotEmpty) {
            final options = [...matchLeft, '---SEPARATOR---', ...matchRight];
            final totalSectionMarks = actualCount * marksPerQuestion;
            questions[uniqueName] = [
              Question(
                text: 'Match the following',
                type: type,
                marks: totalSectionMarks,
                options: options,
              ),
            ];
          } else if (questionTexts.isNotEmpty) {
            // Fallback: try to extract pairs from question_texts with "left - right" format
            final leftItems = <String>[];
            final rightItems = <String>[];
            for (final qt in questionTexts) {
              final dashIdx = qt.indexOf(' - ');
              if (dashIdx > 0) {
                leftItems.add(qt.substring(0, dashIdx).trim());
                rightItems.add(qt.substring(dashIdx + 3).trim());
              }
            }
            if (leftItems.isNotEmpty) {
              final options = [...leftItems, '---SEPARATOR---', ...rightItems];
              final totalSectionMarks = actualCount * marksPerQuestion;
              questions[uniqueName] = [
                Question(
                  text: 'Match the following',
                  type: type,
                  marks: totalSectionMarks,
                  options: options,
                ),
              ];
            }
          }
        } else if (questionTexts.isNotEmpty) {
          questions[uniqueName] = questionTexts.asMap().entries.map((entry) {
            final idx = entry.key;
            var text = entry.value;

            // Extract options for this question if available
            List<String>? opts;
            if (optionsList != null && idx < optionsList.length && optionsList[idx] != null) {
              opts = (optionsList[idx] as List<dynamic>?)
                  ?.map((o) => o.toString())
                  .toList();
            }

            // Clean MCQ question text: remove inline options like (day / night)
            if (type == 'multiple_choice' && opts != null && opts.isNotEmpty) {
              text = _cleanMcqText(text, opts);
            }

            return Question(
              text: text,
              type: type,
              marks: marksPerQuestion,
              options: opts,
            );
          }).toList();
        }
      }

      return PaperParseResult(
        sections: sections,
        questions: questions,
        success: sections.isNotEmpty,
      );
    } catch (e) {
      debugPrint('[PaperParse] JSON parse error: $e');
      return PaperParseResult.failure('Failed to parse response: $e');
    }
  }

  /// Fallback: parse paper text locally using pattern matching
  static PaperParseResult _parseLocally(String text) {
    final sections = <PaperSectionEntity>[];
    final questions = <String, List<Question>>{};
    final usedNames = <String>{};
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    final sectionPattern = RegExp(
      r'^(?:[IVXLC]+[\).\s]|Section\s+[A-Z])',
      caseSensitive: false,
    );
    final marksPattern = RegExp(r'\((\d+(?:\.\d+)?)\s*marks?\)', caseSensitive: false);
    final questionLinePattern = RegExp(r'^\d+[\).\s]+(.+)');

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];

      if (sectionPattern.hasMatch(line)) {
        var name = line.replaceFirst(RegExp(r'^[IVXLC]+[\).\s]+', caseSensitive: false), '').trim();
        name = name.replaceFirst(marksPattern, '').trim();
        name = name.replaceAll(RegExp(r'[:]+$'), '').trim();
        if (RegExp(r'^Section\s+[A-Z]\b', caseSensitive: false).hasMatch(name)) {
          i++;
          continue;
        }
        if (name.isEmpty) name = 'Section';

        final marksMatch = marksPattern.firstMatch(line);
        final totalMarks = marksMatch != null ? double.tryParse(marksMatch.group(1)!) ?? 0 : 0;
        final type = _detectType(name);

        // Collect questions
        final sectionQuestions = <String>[];
        int j = i + 1;
        while (j < lines.length && !sectionPattern.hasMatch(lines[j])) {
          final qMatch = questionLinePattern.firstMatch(lines[j]);
          if (qMatch != null) {
            sectionQuestions.add(qMatch.group(1)!.trim());
          }
          j++;
        }

        final questionCount = sectionQuestions.isNotEmpty ? sectionQuestions.length : 1;
        final marksPerQuestion = totalMarks > 0 && questionCount > 0
            ? totalMarks / questionCount
            : 1.0;

        // Ensure unique name
        var uniqueName = name;
        if (usedNames.contains(name.toLowerCase())) {
          for (int k = 0; k < 26; k++) {
            final suffix = String.fromCharCode(65 + k);
            final candidate = '$name ($suffix)';
            if (!usedNames.contains(candidate.toLowerCase())) {
              uniqueName = candidate;
              break;
            }
          }
        }
        usedNames.add(uniqueName.toLowerCase());

        sections.add(PaperSectionEntity(
          name: uniqueName,
          type: type,
          questions: questionCount,
          marksPerQuestion: double.parse(marksPerQuestion.toStringAsFixed(2)),
        ));

        // Build Question objects from extracted text
        if (type == 'match_following' && sectionQuestions.isNotEmpty) {
          // Extract "left - right" pairs for match_following
          final leftItems = <String>[];
          final rightItems = <String>[];
          for (final qText in sectionQuestions) {
            final dashIdx = qText.indexOf(' - ');
            if (dashIdx > 0) {
              leftItems.add(qText.substring(0, dashIdx).trim());
              rightItems.add(qText.substring(dashIdx + 3).trim());
            }
          }
          if (leftItems.isNotEmpty) {
            final options = [...leftItems, '---SEPARATOR---', ...rightItems];
            final totalSectionMarks = questionCount * double.parse(marksPerQuestion.toStringAsFixed(2));
            questions[uniqueName] = [
              Question(
                text: 'Match the following',
                type: type,
                marks: totalSectionMarks,
                options: options,
              ),
            ];
          }
        } else if (sectionQuestions.isNotEmpty) {
          questions[uniqueName] = sectionQuestions.map((qText) {
            return Question(
              text: qText,
              type: type,
              marks: double.parse(marksPerQuestion.toStringAsFixed(2)),
            );
          }).toList();
        }

        i = j;
      } else {
        i++;
      }
    }

    return PaperParseResult(
      sections: sections,
      questions: questions,
      success: sections.isNotEmpty,
      error: sections.isEmpty ? 'Could not detect any sections in the text' : null,
    );
  }

  /// Clean MCQ question text by removing inline options like (day / night) or [Umar (ra) / Abu Bakr (ra)]
  static String _cleanMcqText(String text, List<String> options) {
    // Pattern: (option1 / option2) or [option1 / option2]
    var cleaned = text;
    // Remove parenthesized options that contain a slash separator
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\s*[\(\[]\s*([^)\]]*?/[^)\]]*?)\s*[\)\]]'),
      (match) {
        final content = match.group(1)!;
        // Verify this contains at least one of the known options
        final containsOption = options.any((opt) =>
            content.toLowerCase().contains(opt.toLowerCase().trim()));
        return containsOption ? ' ____' : match.group(0)!;
      },
    );
    // Clean up multiple underscores and spaces
    cleaned = cleaned.replaceAll(RegExp(r'_{2,}'), '____');
    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ');
    return cleaned.trim();
  }

  /// Detect question type from section name
  static String _detectType(String name) {
    final lower = name.toLowerCase();
    for (final entry in _typeMapping.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return 'short_answer';
  }
}
