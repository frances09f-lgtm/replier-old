import 'dart:convert';

/// Mirrors native [CloudAiRequestBuilder] for unit tests (no HTTP).
class CloudAiRequestBuilder {
  static String buildFormattedSystemPrompt(
    String userSystemPrompt,
    String senderName,
  ) {
    final effectiveSender =
        senderName.trim().isEmpty ? 'the user' : senderName.trim();
    final buffer = StringBuffer()
      ..writeln(
        'You are an AI assistant auto-replying to incoming messages from '
        '$effectiveSender on behalf of the app user.',
      )
      ..writeln();

    final trimmedUserPrompt = userSystemPrompt.trim();
    if (trimmedUserPrompt.isNotEmpty) {
      buffer
        ..writeln('User Guidelines & Persona:')
        ..writeln(trimmedUserPrompt)
        ..writeln();
    }

    buffer
      ..writeln('Instructions:')
      ..writeln(
        '- Reply directly to $effectiveSender in a natural, friendly, and helpful tone.',
      )
      ..writeln(
        '- Reply in the same language as the incoming message (e.g. English, Marathi, or mixed).',
      )
      ..writeln('- Keep replies brief, conversational, and under 30 words.')
      ..writeln("- Do NOT repeat or echo $effectiveSender's message.")
      ..writeln(
        "- Do NOT include role prefixes like 'Assistant:', 'AI:', or '$effectiveSender:'. "
        'Output ONLY the message reply text.',
      );

    return buffer.toString().trimRight();
  }

  static Map<String, dynamic> buildOpenAiCompatiblePayload({
    required String model,
    required String systemPrompt,
    required String incomingMessage,
    required String senderName,
    List<Map<String, String>> history = const [],
    int maxTokens = 100,
    double temperature = 0.7,
  }) {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    for (final msg in history) {
      final role = msg['role'] == 'user' ? 'user' : 'assistant';
      var content = msg['content'] ?? '';
      if (msg['role'] == 'user' && !content.startsWith('$senderName:')) {
        content = '$senderName: $content';
      }
      messages.add({'role': role, 'content': content});
    }

    final currentContent = incomingMessage.startsWith('$senderName:')
        ? incomingMessage
        : '$senderName: $incomingMessage';
    messages.add({'role': 'user', 'content': currentContent});

    return {
      'model': model,
      'messages': messages,
      'max_tokens': maxTokens,
      'temperature': temperature,
    };
  }

  static Map<String, dynamic> buildGeminiPayload({
    required String systemPrompt,
    required String incomingMessage,
    required String senderName,
    List<Map<String, String>> history = const [],
    int maxOutputTokens = 100,
    double temperature = 0.7,
  }) {
    final contents = <Map<String, dynamic>>[];

    for (final msg in history) {
      final role = msg['role'] == 'user' ? 'user' : 'model';
      var contentText = msg['content'] ?? '';
      if (msg['role'] == 'user' && !contentText.startsWith('$senderName:')) {
        contentText = '$senderName: $contentText';
      }
      contents.add({
        'role': role,
        'parts': [
          {'text': contentText},
        ],
      });
    }

    final currentContent = incomingMessage.startsWith('$senderName:')
        ? incomingMessage
        : '$senderName: $incomingMessage';
    contents.add({
      'role': 'user',
      'parts': [
        {'text': currentContent},
      ],
    });

    return {
      'contents': contents,
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'generationConfig': {
        'maxOutputTokens': maxOutputTokens,
        'temperature': temperature,
      },
    };
  }

  /// Returns true if [payloadJson] includes the user message and configured system prompt.
  static bool openAiPayloadContainsMessageAndSystem(
    Map<String, dynamic> payload,
    String systemPrompt,
    String incomingMessage,
    String senderName,
  ) {
    final messages = payload['messages'] as List<dynamic>? ?? [];
    final hasSystem = messages.any((m) {
      final map = m as Map<String, dynamic>;
      return map['role'] == 'system' &&
          (map['content'] as String?)?.contains(systemPrompt.trim()) == true;
    });
    final userLine = incomingMessage.startsWith('$senderName:')
        ? incomingMessage
        : '$senderName: $incomingMessage';
    final hasUser = messages.any((m) {
      final map = m as Map<String, dynamic>;
      return map['role'] == 'user' && map['content'] == userLine;
    });
    return hasSystem && hasUser;
  }

  static String payloadToJson(Map<String, dynamic> payload) =>
      jsonEncode(payload);
}
