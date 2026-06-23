import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for AI-powered replies using Groq API
class AiService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  
  // Available Groq models (free tier)
  static const List<String> availableModels = [
    'llama-3.3-70b-versatile',      // Best quality
    'llama-3.1-8b-instant',         // Fast, good quality
    'mixtral-8x7b-32768',           // Good balance
    'gemma2-9b-it',                 // Fast, lightweight
  ];

  String? _apiKey;
  String _currentModel = 'llama-3.1-8b-instant';
  String _systemPrompt = 'You are a helpful auto-reply assistant. Keep responses brief, friendly, and conversational. Respond as if you are the person receiving the message.';

  /// Set the API key
  void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  /// Get the current API key
  String? getApiKey() {
    return _apiKey;
  }

  /// Set the AI model
  void setModel(String model) {
    if (availableModels.contains(model)) {
      _currentModel = model;
    }
  }

  /// Get the current model
  String getModel() {
    return _currentModel;
  }

  /// Set the system prompt (personality)
  void setSystemPrompt(String prompt) {
    _systemPrompt = prompt;
  }

  /// Get the system prompt
  String getSystemPrompt() {
    return _systemPrompt;
  }

  /// Check if API key is configured
  bool isConfigured() {
    return _apiKey != null && _apiKey!.isNotEmpty;
  }

  /// Generate an AI reply for a given message
  /// Returns the AI-generated reply or null if failed
  Future<String?> generateReply({
    required String message,
    String? senderName,
    String? context, // Optional conversation context
  }) async {
    if (!isConfigured()) {
      throw Exception('API key not configured');
    }

    try {
      final messages = <Map<String, String>>[
        {'role': 'system', 'content': _systemPrompt},
      ];

      // Add context if available
      if (context != null && context.isNotEmpty) {
        messages.add({
          'role': 'system',
          'content': 'Recent conversation context:\n$context',
        });
      }

      // Add the user's message
      String userMessage = message;
      if (senderName != null && senderName.isNotEmpty) {
        userMessage = 'Message from $senderName: $message';
      }
      messages.add({'role': 'user', 'content': userMessage});

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _currentModel,
          'messages': messages,
          'max_tokens': 150, // Keep replies short for auto-reply
          'temperature': 0.7, // Balanced creativity
          'top_p': 0.9,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List;
        if (choices.isNotEmpty) {
          final firstChoice = choices[0] as Map<String, dynamic>;
          final message = firstChoice['message'] as Map<String, dynamic>;
          final content = message['content'] as String;
          return content.trim();
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception('API error: ${error['error']['message']}');
      }
    } catch (e) {
      throw Exception('Failed to generate AI reply: $e');
    }

    return null;
  }

  /// Test the API connection
  /// Returns true if successful
  Future<bool> testConnection() async {
    try {
      final reply = await generateReply(message: 'Hello');
      return reply != null && reply.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
