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
    List<String>? replies,
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
      replies: replies ?? [],
      exactMatch: exactMatch,
      containsMatch: containsMatch,
      caseSensitive: caseSensitive,
      isEnabled: isEnabled,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }


}
