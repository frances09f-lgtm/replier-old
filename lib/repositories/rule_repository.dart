import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import '../core/hive_config.dart';
import '../models/rule.dart';

/// Repository for managing rules
@injectable
class RuleRepository {
  final Uuid _uuid = const Uuid();

  /// Get all rules
  List<Rule> getAllRules() {
    final box = HiveConfig.getRulesBox();
    return box.values.toList();
  }

  /// Get rule by ID
  Rule? getRuleById(String id) {
    final box = HiveConfig.getRulesBox();
    return box.get(id);
  }

  /// Get enabled rules
  List<Rule> getEnabledRules() {
    final rules = getAllRules();
    return rules.where((rule) => rule.isEnabled).toList();
  }

  /// Get active rules count
  int getActiveRulesCount() {
    return getEnabledRules().length;
  }

  /// Add a new rule
  Future<void> addRule(Rule rule) async {
    final box = HiveConfig.getRulesBox();
    await box.put(rule.id, rule);
  }

  /// Update an existing rule
  Future<void> updateRule(Rule rule) async {
    final box = HiveConfig.getRulesBox();
    final updatedRule = rule.copyWith(updatedAt: DateTime.now());
    await box.put(rule.id, updatedRule);
  }

  /// Delete a rule
  Future<void> deleteRule(String id) async {
    final box = HiveConfig.getRulesBox();
    await box.delete(id);
  }

  /// Toggle rule enabled status
  Future<void> toggleRuleEnabled(String id) async {
    final rule = getRuleById(id);
    if (rule != null) {
      final updatedRule = rule.copyWith(
        isEnabled: !rule.isEnabled,
        updatedAt: DateTime.now(),
      );
      await updateRule(updatedRule);
    }
  }

  /// Search rules by trigger text
  List<Rule> searchRules(String query) {
    final rules = getAllRules();
    if (query.isEmpty) return rules;

    final lowerQuery = query.toLowerCase();
    return rules.where((rule) {
      final matchesTriggers = rule.effectiveTriggers
          .any((t) => t.toLowerCase().contains(lowerQuery));
      return matchesTriggers ||
          rule.replyText.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Find matching rule for a message
  Rule? findMatchingRule(String message) {
    final enabledRules = getEnabledRules();
    for (final rule in enabledRules) {
      if (rule.matches(message)) {
        return rule;
      }
    }
    return null;
  }

  /// Create a new rule with default values
  Rule createRule({
    required String triggerText,
    required String replyText,
    List<String>? triggerTexts,
    bool exactMatch = false,
    bool containsMatch = true,
    bool caseSensitive = false,
    bool isEnabled = true,
  }) {
    return Rule(
      id: _uuid.v4(),
      triggerText: triggerText,
      triggerTexts: triggerTexts ?? [],
      replyText: replyText,
      exactMatch: exactMatch,
      containsMatch: containsMatch,
      caseSensitive: caseSensitive,
      isEnabled: isEnabled,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Add sample rules for demonstration
  Future<void> addSampleRules() async {
    final box = HiveConfig.getRulesBox();
    if (box.isEmpty) {
      final sampleRules = [
        // Greetings
        createRule(
          triggerText: 'hi',
          replyText:
              'Hey! I\'m a bit busy right now, I\'ll get back to you soon. 😊',
          exactMatch: true,
          containsMatch: false,
        ),
        createRule(
          triggerText: 'hello',
          replyText: 'Hello! Can\'t talk right now, will reply shortly.',
          exactMatch: true,
          containsMatch: false,
        ),
        createRule(
          triggerText: 'hey',
          replyText: 'Hey! I\'ll get back to you in a bit.',
          exactMatch: true,
          containsMatch: false,
        ),
        createRule(
          triggerText: 'good morning',
          replyText:
              'Good morning! 🌅 Hope you have a great day. I\'ll reply soon.',
        ),
        createRule(
          triggerText: 'good afternoon',
          replyText:
              'Good afternoon! I\'m currently busy, will respond shortly.',
        ),
        createRule(
          triggerText: 'good evening',
          replyText: 'Good evening! 🌙 I\'ll get back to you soon.',
        ),
        createRule(
          triggerText: 'good night',
          replyText: 'Good night! 😴 Sweet dreams. Talk tomorrow!',
        ),

        // Availability
        createRule(
          triggerText: 'are you there',
          replyText:
              'Yes, I\'m here! Just a bit occupied at the moment. Give me a few minutes.',
        ),
        createRule(
          triggerText: 'are you free',
          replyText:
              'Not right now, but I\'ll be free soon. I\'ll reach out then!',
        ),
        createRule(
          triggerText: 'are you busy',
          replyText:
              'Yes, a little busy at the moment. I\'ll reply as soon as I\'m free.',
        ),
        createRule(
          triggerText: 'where are you',
          replyText:
              'I\'m around, just occupied right now. I\'ll get back to you soon!',
        ),
        createRule(
          triggerText: 'call me',
          replyText:
              'Can\'t call right now. I\'ll call you back as soon as possible! 📞',
        ),
        createRule(
          triggerText: 'can you talk',
          replyText:
              'Not at the moment, sorry! I\'ll message you when I\'m free.',
        ),

        // Acknowledgements
        createRule(
          triggerText: 'ok',
          replyText: 'Got it! I\'ll get back to you shortly. 👍',
          exactMatch: true,
          containsMatch: false,
        ),
        createRule(
          triggerText: 'okay',
          replyText: 'Noted! Talk soon.',
          exactMatch: true,
          containsMatch: false,
        ),
        createRule(
          triggerText: 'thanks',
          replyText: 'You\'re welcome! 😊',
        ),
        createRule(
          triggerText: 'thank you',
          replyText: 'My pleasure! Happy to help. 😊',
        ),
        createRule(
          triggerText: 'sorry',
          replyText: 'No worries at all! Don\'t stress about it. 🙂',
        ),

        // Meeting & plans
        createRule(
          triggerText: 'when will you come',
          replyText: 'I\'m on my way! Will be there soon. 🚗',
        ),
        createRule(
          triggerText: 'where to meet',
          replyText:
              'Let\'s discuss when I\'m free. I\'ll message you shortly!',
        ),
        createRule(
          triggerText: 'what time',
          replyText: 'Let me check and get back to you on the timing.',
        ),
        createRule(
          triggerText: 'are we meeting',
          replyText: 'Yes! I\'ll confirm the details shortly.',
        ),

        // Emergency / urgency
        createRule(
          triggerText: 'urgent',
          replyText: '⚠️ Noted as urgent! I\'ll respond as quickly as I can.',
        ),
        createRule(
          triggerText: 'emergency',
          replyText: '🚨 I see this is urgent! Responding as soon as possible.',
        ),
        createRule(
          triggerText: 'asap',
          replyText: 'On it! I\'ll get back to you ASAP.',
        ),

        // Small talk
        createRule(
          triggerText: 'how are you',
          replyText: 'I\'m doing well, thanks for asking! How about you? 😊',
        ),
        createRule(
          triggerText: 'what\'s up',
          replyText: 'Not much! Busy at the moment. What\'s up with you?',
        ),
        createRule(
          triggerText: 'whats up',
          replyText: 'Hey! A little occupied right now. Will catch up soon!',
        ),
        createRule(
          triggerText: 'miss you',
          replyText: 'Miss you too! 💙 Let\'s catch up soon.',
        ),
        createRule(
          triggerText: 'thinking of you',
          replyText: 'Aww, thinking of you too! 😊 Talk soon.',
        ),

        // Goodbye
        createRule(
          triggerText: 'bye',
          replyText: 'Bye! Talk later. Take care! 👋',
          exactMatch: true,
          containsMatch: false,
        ),
        createRule(
          triggerText: 'goodbye',
          replyText: 'Goodbye! Take care. 😊',
        ),
        createRule(
          triggerText: 'take care',
          replyText: 'You too! Take care. 💙',
        ),
        createRule(
          triggerText: 'see you',
          replyText: 'See you! Looking forward to it. 😊',
        ),
        createRule(
          triggerText: 'talk later',
          replyText: 'Sure! Talk later. 👋',
        ),
      ];

      for (final rule in sampleRules) {
        await addRule(rule);
      }
    }
  }
}
