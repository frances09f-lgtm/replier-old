import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/hive_config.dart';
import '../models/app_settings.dart';
import '../models/chat_message.dart';
import 'settings_provider.dart';

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier(ref);
});

final chatLoadingProvider = StateProvider<bool>((ref) => false);

final chatErrorProvider = StateProvider<String?>((ref) => null);

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref _ref;

  ChatNotifier(this._ref) : super([]) {
    print('[Chat] ChatNotifier constructor');
    _loadMessages();
  }

  void _loadMessages() {
    final box = HiveConfig.getChatBox();
    final messages = box.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    state = messages;
  }

  Future<void> sendMessage(String text) async {
    print('[Chat] sendMessage called with: "$text"');
    if (text.trim().isEmpty) return;

    _ref.read(chatErrorProvider.notifier).state = null;
    _ref.read(chatLoadingProvider.notifier).state = true;

    final userMessage = ChatMessage(role: 'user', content: text.trim());
    final box = HiveConfig.getChatBox();
    await box.put(userMessage.id, userMessage);
    state = [...state, userMessage];

    try {
      final settings = _ref.read(appSettingsProvider);
      final settingsModel = settings.aiModelType;

      if (settingsModel == 'smart_reply') {
        throw Exception('On-device Smart Reply is for auto-reply only. Switch to Groq/Gemini/Cerebras in Settings to use the chatbot.');
      } else if (settingsModel == 'gemma_local') {
        final reply = await _callGemmaLocal(text, settings);
        final aiMessage = ChatMessage(
          role: 'assistant', content: reply, model: 'gemma_local',
        );
        await box.put(aiMessage.id, aiMessage);
        state = [...state, aiMessage];
      } else if (settingsModel == 'gemini') {
        final keys = settings.geminiApiKeys;
        if (keys.isEmpty) {
          throw Exception('Gemini API key not set. Configure it in Settings.');
        }
        final reply = await _callGemini(text, settings);
        final aiMessage = ChatMessage(
          role: 'assistant', content: reply, model: 'gemini',
        );
        await box.put(aiMessage.id, aiMessage);
        state = [...state, aiMessage];
      } else if (settingsModel == 'cerebras') {
        if (settings.cerebrasApiKey.isEmpty) {
          throw Exception('Cerebras API key not set. Configure it in Settings.');
        }
        final reply = await _callCerebras(text, settings);
        final aiMessage = ChatMessage(
          role: 'assistant', content: reply, model: 'cerebras',
        );
        await box.put(aiMessage.id, aiMessage);
        state = [...state, aiMessage];
      } else {
        if (settings.groqApiKey.isEmpty) {
          throw Exception('Groq API key not set. Configure it in Settings.');
        }
        final reply = await _callGroq(text, settings);
        final aiMessage = ChatMessage(
          role: 'assistant', content: reply, model: 'groq',
        );
        await box.put(aiMessage.id, aiMessage);
        state = [...state, aiMessage];
      }

      // Check for busy/meeting intent in user message and set busy mode
      _checkAndSetBusyMode(text);
      _syncChatbotContext();
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      _ref.read(chatErrorProvider.notifier).state = msg;
      final errorMessage = ChatMessage(
        role: 'assistant', content: 'Error: $msg',
      );
      await box.put(errorMessage.id, errorMessage);
      state = [...state, errorMessage];
      _syncChatbotContext();
    } finally {
      _ref.read(chatLoadingProvider.notifier).state = false;
    }
  }

  void _checkAndSetBusyMode(String text) {
    final lower = text.toLowerCase();

    // Detect busy intent keywords
    bool hasMeeting = lower.contains('meeting');
    bool hasBusy = lower.contains('busy');
    bool hasAway = lower.contains('away') || lower.contains('afk') || lower.contains('leave');
    bool hasDriving = lower.contains('driving') || lower.contains('drive');
    bool hasWork = lower.contains('work') || lower.contains('office');
    bool hasSleep = lower.contains('sleep') || lower.contains('sleeping') || lower.contains('bed');
    bool hasClass = lower.contains('class') || lower.contains('lecture') || lower.contains('study');

    if (!hasMeeting && !hasBusy && !hasAway && !hasDriving && !hasWork && !hasSleep && !hasClass) return;

    // Determine reply text
    String replyText;
    if (hasMeeting) {
      replyText = "I'm currently in a meeting. I'll get back to you shortly.";
    } else if (hasDriving) {
      replyText = "I'm driving right now. I'll reply when I arrive.";
    } else if (hasSleep) {
      replyText = "I'm sleeping right now. I'll reply when I wake up.";
    } else if (hasClass) {
      replyText = "I'm in class right now. I'll reply after it ends.";
    } else if (hasAway) {
      replyText = "I'm away right now. I'll get back to you soon.";
    } else if (hasWork) {
      replyText = "I'm at work right now. I'll reply when I'm free.";
    } else {
      replyText = "I'm busy right now. I'll reply later.";
    }

    // Extract duration
    int durationMinutes = 120; // default 2 hours

    final durationRegex = RegExp(
      r'(?:for\s+)?(?:an?|one|two|three|four|five|six|seven|eight|nine|ten|'
      r'\d+|half\s+an?)\s*(hour|hr|minute|min|day|days|hours|hrs|minutes|mins)',
      caseSensitive: false,
    );
    final match = durationRegex.firstMatch(lower);
    if (match != null) {
      final numStr = match.group(0)!.toLowerCase();
      final unit = match.group(1)!.toLowerCase();

      int numericValue = 0;
      if (numStr.contains('an') || numStr.contains('one') || numStr.contains('a ')) {
        numericValue = 1;
      } else if (numStr.contains('two')) {
        numericValue = 2;
      } else if (numStr.contains('three')) {
        numericValue = 3;
      } else if (numStr.contains('four')) {
        numericValue = 4;
      } else if (numStr.contains('five')) {
        numericValue = 5;
      } else if (numStr.contains('six')) {
        numericValue = 6;
      } else if (numStr.contains('seven')) {
        numericValue = 7;
      } else if (numStr.contains('eight')) {
        numericValue = 8;
      } else if (numStr.contains('nine')) {
        numericValue = 9;
      } else if (numStr.contains('ten')) {
        numericValue = 10;
      } else if (numStr.contains('half')) {
        numericValue = 0;
        if (unit.startsWith('hour') || unit.startsWith('hr')) {
          durationMinutes = 30;
        } else {
          durationMinutes = 30;
        }
      } else {
        final digits = RegExp(r'\d+').firstMatch(numStr);
        if (digits != null) {
          numericValue = int.tryParse(digits.group(0)!) ?? 1;
        } else {
          numericValue = 1;
        }
      }

      if (unit.startsWith('day') || unit.startsWith('days')) {
        durationMinutes = numericValue * 24 * 60;
      } else if (unit.startsWith('hour') || unit.startsWith('hr')) {
        durationMinutes = numericValue * 60;
      } else {
        durationMinutes = numericValue;
      }
    }

    final untilTimestamp = DateTime.now().millisecondsSinceEpoch + (durationMinutes * 60 * 1000);
    _ref.read(appSettingsProvider.notifier).setBusyMode(replyText, untilTimestamp);

    final durationStr = durationMinutes >= 1440
        ? '${durationMinutes ~/ 1440} day(s)'
        : durationMinutes >= 60
            ? '${durationMinutes ~/ 60} hour(s)'
            : '$durationMinutes minute(s)';

    // Show confirmation in chat
    final confirmMsg = ChatMessage(
      role: 'assistant',
      content: '✅ Busy mode activated: "$replyText"\nDuration: $durationStr\nAuto-reply will use this message.',
      model: 'system',
    );
    final box = HiveConfig.getChatBox();
    box.put(confirmMsg.id, confirmMsg);
    state = [...state, confirmMsg];
    print('[Chat] Busy mode set: reply="$replyText", duration=${durationMinutes}min, until=$untilTimestamp');
  }

  List<Map<String, dynamic>> _buildMessages(String text) {
    final history = state
        .where((m) => m.role == 'user' || m.role == 'assistant')
        .map((m) => {
              'role': m.role,
              'content': _sanitize(m.content),
            })
        .toList();

    final recent = history.length > 30
        ? history.sublist(history.length - 30)
        : history;

    return [...recent, {'role': 'user', 'content': text}];
  }

  String _sanitize(String s) {
    final sb = StringBuffer();
    for (final rune in s.runes) {
      if (rune >= 0x20 && rune <= 0xD7FF ||
          rune >= 0xE000 && rune <= 0xFFFD ||
          rune >= 0x10000 && rune <= 0x10FFFF) {
        sb.writeCharCode(rune);
      } else if (rune == 0x0A || rune == 0x0D || rune == 0x09) {
        sb.writeCharCode(rune);
      }
    }
    return sb.toString();
  }

  Future<String> _callGroq(String text, AppSettings settings) async {
    final client = HttpClient();
    try {
      final messages = _buildMessages(text);
      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      final payload = {
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {'role': 'system', 'content': _sanitize(settings.aiSystemPrompt)},
          ...messages,
        ],
        'max_tokens': 500,
        'temperature': 0.7,
      };
      final requestBody = jsonEncode(payload);
      print('[Chat] Groq request: $url');
      print('[Chat] Groq body: $requestBody');

      final request = await client.postUrl(url);
      request.headers.set('Authorization', 'Bearer ${settings.groqApiKey}');
      request.headers.set('Content-Type', 'application/json');
      final bytes = utf8.encode(requestBody);
      request.contentLength = bytes.length;
      request.add(bytes);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      print('[Chat] Groq response status: ${response.statusCode}');
      print('[Chat] Groq response body: $body');

      if (response.statusCode != 200) {
        final err = jsonDecode(body);
        throw Exception(err['error']?['message'] ?? body);
      }

      final json = jsonDecode(body);
      final content = json['choices']?[0]?['message']?['content']?.toString().trim();
      if (content == null || content.isEmpty) throw Exception('Groq returned empty response. Body: $body');
      return content;
    } finally {
      client.close();
    }
  }

  Future<String> _callGemini(String text, AppSettings settings) async {
    final history = state
        .where((m) => m.role == 'user' || m.role == 'assistant')
        .map((m) => {
              'role': m.role == 'assistant' ? 'model' : 'user',
              'parts': [{'text': _sanitize(m.content)}],
            })
        .toList();

    final recent = history.length > 30
        ? history.sublist(history.length - 30)
        : history;

    final contents = [
      ...recent,
      {'role': 'user', 'parts': [{'text': text}]},
    ];

    print('[Chat] Gemini contents: ${jsonEncode(contents)}');

    var lastError = '';
    for (final apiKey in settings.geminiApiKeys) {
      final client = HttpClient();
      try {
        final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');
        print('[Chat] Gemini request: $url');
        final request = await client.postUrl(url);
        request.headers.set('Content-Type', 'application/json');
        final requestBody = {
          'contents': contents,
          'system_instruction': {
            'parts': [{'text': _sanitize(settings.aiSystemPrompt)}]
          },
          'generationConfig': {
            'maxOutputTokens': 500,
            'temperature': 0.7,
          },
        };
        final encoded = jsonEncode(requestBody);
        print('[Chat] Gemini body: $encoded');
        final geminiBytes = utf8.encode(encoded);
        request.contentLength = geminiBytes.length;
        request.add(geminiBytes);
        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();

        print('[Chat] Gemini response status: ${response.statusCode}');
        print('[Chat] Gemini response body: $responseBody');

        if (response.statusCode == 200) {
          final json = jsonDecode(responseBody);
          final reply = json['candidates']?[0]?['content']?['parts']?[0]?['text']?.trim();
          if (reply != null && reply.isNotEmpty) return reply;
        }

        lastError = responseBody;
      } catch (e) {
        print('[Chat] Gemini exception: $e');
        lastError = e.toString();
      } finally {
        client.close();
      }
    }
    throw Exception(lastError);
  }

  Future<String> _callCerebras(String text, AppSettings settings) async {
    final client = HttpClient();
    try {
      final messages = _buildMessages(text);
      final url = Uri.parse('https://api.cerebras.ai/v1/chat/completions');
      final payload = {
        'model': 'gpt-oss-120b',
        'messages': [
          {'role': 'system', 'content': _sanitize(settings.aiSystemPrompt)},
          ...messages,
        ],
        'max_tokens': 500,
        'temperature': 0.7,
      };
      final requestBody = jsonEncode(payload);
      print('[Chat] Cerebras request: $url');
      print('[Chat] Cerebras body: $requestBody');

      final request = await client.postUrl(url);
      request.headers.set('Authorization', 'Bearer ${settings.cerebrasApiKey}');
      request.headers.set('Content-Type', 'application/json');
      final cerebBytes = utf8.encode(requestBody);
      request.contentLength = cerebBytes.length;
      request.add(cerebBytes);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      print('[Chat] Cerebras response status: ${response.statusCode}');
      print('[Chat] Cerebras response body: $body');

      if (response.statusCode != 200) {
        final err = jsonDecode(body);
        throw Exception(err['error']?['message'] ?? body);
      }

      final json = jsonDecode(body);
      final content = json['choices']?[0]?['message']?['content']?.toString().trim();
      if (content == null || content.isEmpty) throw Exception('Cerebras returned empty response. Body: $body');
      return content;
    } finally {
      client.close();
    }
  }

  Future<String> _callGemmaLocal(String text, AppSettings settings) async {
    const channel = MethodChannel('com.example.auto_reply_assistant/native');
    try {
      final history = state
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .map((m) => {
                'role': m.role,
                'content': _sanitize(m.content),
              })
          .toList();

      final recent = history.length > 10
          ? history.sublist(history.length - 10)
          : history;

      final result = await channel.invokeMethod<String>('chatWithGemmaLocal', {
        'message': text,
        'systemPrompt': _sanitize(settings.aiSystemPrompt),
        'history': recent,
      });

      if (result == null || result.isEmpty) {
        throw Exception('Gemma Local returned empty response');
      }
      return result;
    } catch (e) {
      if (e is MissingPluginException) {
        throw Exception('Gemma Local not available. Download the model in Settings first.');
      }
      rethrow;
    }
  }

  Future<void> clearConversation() async {
    final box = HiveConfig.getChatBox();
    await box.clear();
    state = [];
    _ref.read(chatErrorProvider.notifier).state = null;
    _syncChatbotContext();
  }

  void _syncChatbotContext() {
    try {
      final recent = state
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .where((m) => !m.content.startsWith('Error:'))
          .map((m) => '${m.role == 'user' ? 'Abhi' : 'Assistant'}: ${m.content}')
          .toList();

      final context = recent.length > 6
          ? recent.sublist(recent.length - 6).join('\n')
          : recent.join('\n');

      const channel = MethodChannel('com.example.auto_reply_assistant/native');
      channel.invokeMethod('setChatbotContext', {'context': context});
      print('[Chat] Synced chatbot context to Kotlin (${context.length} chars)');
    } catch (e) {
      print('[Chat] Failed to sync chatbot context: $e');
    }
  }
}
