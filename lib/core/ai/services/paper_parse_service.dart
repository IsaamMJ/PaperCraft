// lib/core/ai/services/paper_parse_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../features/catalog/domain/entities/paper_section_entity.dart';

/// Result of AI paper parsing
class PaperParseResult {
  final List<PaperSectionEntity> sections;
  final bool success;
  final String? error;

  PaperParseResult({
    required this.sections,
    required this.success,
    this.error,
  });

  factory PaperParseResult.failure(String error) {
    return PaperParseResult(sections: [], success: false, error: error);
  }
}

/// Service for parsing pasted paper text into structured sections using AI.
/// Uses Groq API with llama-3.3-70b-versatile for structured extraction.
/// Completely separate from the existing GroqService (polish flow).
class PaperParseService {
  static String get _apiKey {
    // Prefer compile-time env (--dart-define), fallback to .env file for local dev
    const compileTimeKey = String.fromEnvironment('GROQ_API_KEY');
    if (compileTimeKey.isNotEmpty) return compileTimeKey;
    return dotenv.get('GROQ_API_KEY', fallback: '');
  }
  static const _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'llama-3.3-70b-versatile';
  static const _timeout = Duration(seconds: 20);

  /// Known question types and their keys
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

  /// Parse pasted paper text into structured sections.
  /// Returns a list of PaperSectionEntity objects.
  static Future<PaperParseResult> parsePaperText(String text) async {
    if (text.trim().isEmpty) {
      return PaperParseResult.failure('No text provided');
    }

    // Try AI first, fall back to local parsing if unavailable
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

  /// Parse using Groq AI
  static Future<PaperParseResult> _parseWithAI(String text) async {
    final prompt = '''You are an exam paper structure extractor. Extract each question section from the paper text below.

RULES:
1. "name" = the ACTUAL instruction text from the paper (e.g., "Tick the correct answer", "Match the following", "Fill in the blanks", "Answer the following", "Say"). Do NOT use generic names like "Section A" or "Section I". Strip any Roman numerals (I, II, III) or numbering prefixes. Strip any marks info like "(5 marks)".

2. "type" = one of these ONLY: multiple_choice, true_false, fill_in_blanks, match_following, short_answer, missing_letters, word_forms
   - Tick correct/wrong, state true or false = true_false
   - Choose correct answer, options in brackets like (a / b) = multiple_choice
   - Fill in the blanks, sentences with ____ = fill_in_blanks
   - Match the following, Column A to Column B = match_following
   - Answer the following, Write, Explain, essay-type = short_answer
   - Missing letters like h_ro, p_nce = missing_letters
   - Jumbled letters, rearrange, word forms = word_forms
   - Say, Recite, Oral sections = short_answer

3. "questions" = count the actual numbered questions (1, 2, 3...) in each section

4. "marks_per_question" = total section marks divided by question count. If marks not specified, use 1.

5. IMPORTANT: Ignore group headers like "Section A (Writing)", "Section B (Oral)" — these are NOT question sections. Only extract sections that have actual questions under them.

6. If Match the Following has sub-groups (A) and (B) with separate sets of pairs, treat them as TWO separate sections: "Match the following (A)" and "Match the following (B)".

7. If two sections have the same instruction (e.g., two "Answer the following"), add suffix (A), (B) to make names unique.

8. Single-item tasks like "Write your name in Arabic" count as 1 question.

Return ONLY a valid JSON array. No markdown, no explanation, no extra text:
[{"name": "...", "type": "...", "questions": N, "marks_per_question": N.N}]

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
          {'role': 'system', 'content': 'You are a precise exam paper structure extractor. Return ONLY valid JSON arrays.'},
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.1,
        'max_tokens': 1000,
      }),
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      return PaperParseResult.failure('API error: ${response.statusCode}');
    }

    final json = jsonDecode(response.body);
    final content = json['choices'][0]['message']['content'] as String;

    // Extract JSON from response (handle potential markdown wrapping)
    final jsonStr = _extractJson(content);
    if (jsonStr == null) {
      return PaperParseResult.failure('Could not parse AI response');
    }

    final sections = _jsonToSections(jsonStr);
    return PaperParseResult(sections: sections, success: sections.isNotEmpty);
  }

  /// Extract JSON array from AI response (handles ```json wrapping)
  static String? _extractJson(String content) {
    // Try direct parse first
    final trimmed = content.trim();
    if (trimmed.startsWith('[')) return trimmed;

    // Try extracting from markdown code block
    final codeBlockPattern = RegExp(r'```(?:json)?\s*(\[[\s\S]*?\])\s*```');
    final match = codeBlockPattern.firstMatch(trimmed);
    if (match != null) return match.group(1);

    // Try finding array in the text
    final arrayPattern = RegExp(r'\[[\s\S]*\]');
    final arrayMatch = arrayPattern.firstMatch(trimmed);
    if (arrayMatch != null) return arrayMatch.group(0);

    return null;
  }

  /// Convert JSON string to list of PaperSectionEntity
  static List<PaperSectionEntity> _jsonToSections(String jsonStr) {
    try {
      final List<dynamic> parsed = jsonDecode(jsonStr);
      final sections = <PaperSectionEntity>[];
      final usedNames = <String>{};

      for (final item in parsed) {
        final name = (item['name'] as String?) ?? 'Section';
        final type = (item['type'] as String?) ?? 'short_answer';
        final questions = (item['questions'] as num?)?.toInt() ?? 0;
        final marksPerQuestion = (item['marks_per_question'] as num?)?.toDouble() ?? 1.0;

        if (questions <= 0) continue;

        // Ensure unique names with (A), (B), (C) suffix
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

        sections.add(PaperSectionEntity(
          name: uniqueName,
          type: type,
          questions: questions,
          marksPerQuestion: marksPerQuestion,
        ));
      }

      return sections;
    } catch (e) {
      debugPrint('[PaperParse] JSON parse error: $e');
      return [];
    }
  }

  /// Fallback: parse paper text locally using pattern matching (no AI needed)
  static PaperParseResult _parseLocally(String text) {
    final sections = <PaperSectionEntity>[];
    final usedNames = <String>{};
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    // Pattern: Roman numeral or section header with marks
    // e.g., "I) Tick the correct answer (3 marks)"
    // e.g., "V) Answer the following: (10 marks)"
    final sectionPattern = RegExp(
      r'^(?:[IVXLC]+[\).\s]|Section\s+[A-Z])',
      caseSensitive: false,
    );
    final marksPattern = RegExp(r'\((\d+(?:\.\d+)?)\s*marks?\)', caseSensitive: false);

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];

      if (sectionPattern.hasMatch(line)) {
        // Extract section name: strip Roman numeral prefix, marks info, trailing colons
        var name = line.replaceFirst(RegExp(r'^[IVXLC]+[\).\s]+', caseSensitive: false), '').trim();
        name = name.replaceFirst(marksPattern, '').trim();
        name = name.replaceAll(RegExp(r'[:]+$'), '').trim();
        // Skip group headers like "Section A (Writing)", "Section B (Oral)"
        if (RegExp(r'^Section\s+[A-Z]\b', caseSensitive: false).hasMatch(name)) {
          i++;
          continue;
        }
        if (name.isEmpty) name = 'Section';

        // Extract total marks
        final marksMatch = marksPattern.firstMatch(line);
        final totalMarks = marksMatch != null ? double.tryParse(marksMatch.group(1)!) ?? 0 : 0;

        // Detect question type from name
        final type = _detectType(name);

        // Count questions (numbered lines following this header)
        int questionCount = 0;
        int j = i + 1;
        while (j < lines.length && !sectionPattern.hasMatch(lines[j])) {
          if (RegExp(r'^\d+[\).\s]').hasMatch(lines[j])) {
            questionCount++;
          }
          j++;
        }

        if (questionCount == 0) questionCount = 1;

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

        i = j;
      } else {
        i++;
      }
    }

    return PaperParseResult(
      sections: sections,
      success: sections.isNotEmpty,
      error: sections.isEmpty ? 'Could not detect any sections in the text' : null,
    );
  }

  /// Detect question type from section name
  static String _detectType(String name) {
    final lower = name.toLowerCase();
    for (final entry in _typeMapping.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return 'short_answer'; // default
  }
}
