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
          replyText: 'hey! bit busy rn, will msg u back soon',
          exactMatch: true,
          containsMatch: false,
        ),
        createRule(
          triggerText: 'hello',
          replyText: 'heya, cant talk atm, ill hit u up later',
          exactMatch: true,
          containsMatch: false,
        ),
        createRule(
          triggerText: 'hey',
          replyText: 'yo! give me a bit, ill reply in a sec',
          exactMatch: true,
          containsMatch: false,
        ),
        createRule(
          triggerText: 'good morning',
          replyText: 'morning! hope u have a good day, ill text u soon',
        ),
        createRule(
          triggerText: 'good afternoon',
          replyText: 'hey! bit swamped rn, talk in a bit',
        ),
        createRule(
          triggerText: 'good evening',
          replyText: 'hey, just saw this. will get back to u in a bit',
        ),
        createRule(
          triggerText: 'good night',
          replyText: 'gn! sleep well, talk tomorrow',
        ),

        // Availability
        createRule(
          triggerText: 'are you there',
          replyText: 'yeah im here, just busy atm. gimme a few',
        ),
        createRule(
          triggerText: 'are you free',
          replyText: 'not rn, but will be soon. ill msg u when i am',
        ),
        createRule(
          triggerText: 'are you busy',
          replyText: 'yeah a bit swamped rn, ill reply when im free',
        ),
        createRule(
          triggerText: 'where are you',
          replyText: 'im around, just caught up in smth. brb',
        ),
        createRule(
          triggerText: 'call me',
          replyText: 'cant call rn, ill ring u back when i can',
        ),
        createRule(
          triggerText: 'can you talk',
          replyText: 'not rn sorry, ill text u when im free',
        ),

        // Acknowledgements
        createRule(
          triggerText: 'ok',
          replyText: 'got it, talk soon!',
          exactMatch: true,
          containsMatch: false,
        ),
        createRule(
          triggerText: 'okay',
          replyText: 'cool, cya later',
          exactMatch: true,
          containsMatch: false,
        ),
        createRule(
          triggerText: 'thanks',
          replyText: 'np any time',
        ),
        createRule(
          triggerText: 'thank you',
          replyText: 'anytime!',
        ),
        createRule(
          triggerText: 'sorry',
          replyText: 'nah dw bout it',
        ),

        // Meeting & plans
        createRule(
          triggerText: 'when will you come',
          replyText: 'on my way, almost there',
        ),
        createRule(
          triggerText: 'where to meet',
          replyText: 'ill let u know once im free, gimme a bit',
        ),
        createRule(
          triggerText: 'what time',
          replyText: 'lemme check and tell u',
        ),
        createRule(
          triggerText: 'are we meeting',
          replyText: 'yeah! ill confirm the details soon',
        ),

        // Emergency / urgency
        createRule(
          triggerText: 'urgent',
          replyText: 'got it, ill get back to u asap',
        ),
        createRule(
          triggerText: 'emergency',
          replyText: 'ok i see this, responding as soon as i can',
        ),
        createRule(
          triggerText: 'asap',
          replyText: 'on it, will get back to u asap',
        ),

        // Small talk
        createRule(
          triggerText: 'how are you',
          replyText: 'im good thanks! how bout u?',
        ),
        createRule(
          triggerText: 'what\'s up',
          replyText: 'nm, busy rn. wbu?',
        ),
        createRule(
          triggerText: 'whats up',
          replyText: 'hey! bit busy rn but ill catch up with u soon',
        ),
        createRule(
          triggerText: 'miss you',
          replyText: 'miss u too! lets catch up soon',
        ),
        createRule(
          triggerText: 'thinking of you',
          replyText: 'awh thats sweet, talk soon!',
        ),

        // Goodbye
        createRule(
          triggerText: 'bye',
          replyText: 'bye! talk later, take care',
          exactMatch: true,
          containsMatch: false,
        ),
        createRule(
          triggerText: 'goodbye',
          replyText: 'bye! take care',
        ),
        createRule(
          triggerText: 'take care',
          replyText: 'u too! take care',
        ),
        createRule(
          triggerText: 'see you',
          replyText: 'cya! looking forward to it',
        ),
        createRule(
          triggerText: 'talk later',
          replyText: 'sure, talk later!',
        ),
      ];

      for (final rule in sampleRules) {
        await addRule(rule);
      }
    }
  }
}
