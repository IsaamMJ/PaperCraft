import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiVisionService {
  static String get apiKey {
    const compileTimeKey = String.fromEnvironment('GEMINI_API_KEY');
    if (compileTimeKey.isNotEmpty) return compileTimeKey;
    return '';
  }

  /// Extract text from an exam paper image using Gemini Flash Vision
  /// Returns the raw text content of the paper
  static Future<String?> extractTextFromImage(Uint8List imageBytes) async {
    if (apiKey.isEmpty) {
      debugPrint('[Gemini Vision] No API key configured');
      return null;
    }

    try {
      // Try primary model first, fallback to older model
      final result = await _tryExtract(imageBytes, 'gemini-2.5-flash');
      if (result != null) return result;

      debugPrint('[Gemini Vision] Primary model failed, trying fallback...');
      return await _tryExtract(imageBytes, 'gemini-2.0-flash');
    } catch (e) {
      debugPrint('[Gemini Vision] Error: $e');
      return null;
    }
  }

  static Future<String?> _tryExtract(Uint8List imageBytes, String modelName) async {
    try {
      final model = GenerativeModel(
        model: modelName,
        apiKey: apiKey,
      );

      final prompt = TextPart('''You are an exam paper text extractor for Indian schools.

Extract ALL text from this exam paper image EXACTLY as written.

RULES:
1. Preserve section headers (e.g., "I. Choose the correct answer", "II. Fill in the blanks")
2. Preserve question numbers (1, 2, 3...)
3. Preserve marks notation (e.g., "5 x 1 = 5 marks", "2 marks each")
4. Preserve MCQ options (A, B, C, D) on separate lines
5. Preserve blanks as underscores (_____)
6. Preserve Match the Following pairs
7. Keep the original language (English, Tamil, Hindi, etc.)
8. Do NOT add any explanation or commentary
9. Do NOT correct spelling — extract exactly as written
10. If text is handwritten, do your best to read it accurately

Return ONLY the extracted text, nothing else.''');

      final imagePart = DataPart('image/jpeg', imageBytes);

      final response = await model.generateContent([
        Content.multi([prompt, imagePart]),
      ]).timeout(const Duration(seconds: 30));

      final text = response.text?.trim();
      if (text != null && text.isNotEmpty) {
        debugPrint('[Gemini Vision] Extracted ${text.length} characters');
        return text;
      }

      debugPrint('[Gemini Vision] Empty response');
      return null;
    } catch (e) {
      debugPrint('[Gemini Vision] Error: $e');
      return null;
    }
  }
}
