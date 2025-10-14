// lib/core/services/groq_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class GroqService {
  static const apiKey = 'YOUR_GROQ_API_KEY'; // Or use env variable
  static const baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  static Future<String> polishText(String text) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'llama-3.1-8b-instant', // Fastest free model
        'messages': [
          {
            'role': 'system',
            'content': 'Fix grammar, spelling, and punctuation only. Keep meaning same.'
          },
          {'role': 'user', 'content': text}
        ],
        'temperature': 0.1,
        'max_tokens': 300,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    }
    throw Exception('Failed: ${response.statusCode}');
  }
}