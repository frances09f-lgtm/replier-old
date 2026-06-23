import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/rule.dart';
import '../repositories/rule_repository.dart';
import '../services/native_sync_service.dart';

/// Provider for rule repository
final ruleRepositoryProvider = Provider<RuleRepository>((ref) {
  return RuleRepository();
});

final _nativeSyncServiceProvider = Provider<NativeSyncService>((ref) {
  return NativeSyncService();
});

/// Provider for all rules
final rulesProvider = StateNotifierProvider<RulesNotifier, List<Rule>>((ref) {
  final repository = ref.watch(ruleRepositoryProvider);
  final syncService = ref.watch(_nativeSyncServiceProvider);
  return RulesNotifier(repository, syncService);
});

/// Notifier for rules
class RulesNotifier extends StateNotifier<List<Rule>> {
  final RuleRepository _repository;
  final NativeSyncService _syncService;

  RulesNotifier(this._repository, this._syncService) : super([]) {
    _loadRules();
  }

  Future<void> _loadRules() async {
    state = _repository.getAllRules();
    await _syncService.syncRules(state);
  }

  Future<void> refreshRules() async {
    state = _repository.getAllRules();
    await _syncService.syncRules(state);
  }

  Future<void> addRule(Rule rule) async {
    await _repository.addRule(rule);
    state = _repository.getAllRules();
    await _syncService.syncRules(state);
  }

  Future<void> updateRule(Rule rule) async {
    await _repository.updateRule(rule);
    state = _repository.getAllRules();
    await _syncService.syncRules(state);
  }

  Future<void> deleteRule(String id) async {
    await _repository.deleteRule(id);
    state = _repository.getAllRules();
    await _syncService.syncRules(state);
  }

  Future<void> toggleRuleEnabled(String id) async {
    await _repository.toggleRuleEnabled(id);
    state = _repository.getAllRules();
    await _syncService.syncRules(state);
  }

  List<Rule> searchRules(String query) {
    return _repository.searchRules(query);
  }

  Rule? findMatchingRule(String message) {
    return _repository.findMatchingRule(message);
  }

  Future<void> addSampleRules() async {
    await _repository.addSampleRules();
    state = _repository.getAllRules();
    await _syncService.syncRules(state);
  }

  Rule createRule({
    required String triggerText,
    required String replyText,
    List<String>? triggerTexts,
    bool exactMatch = false,
    bool containsMatch = true,
    bool caseSensitive = false,
    bool isEnabled = true,
  }) {
    return _repository.createRule(
      triggerText: triggerText,
      replyText: replyText,
      triggerTexts: triggerTexts,
      exactMatch: exactMatch,
      containsMatch: containsMatch,
      caseSensitive: caseSensitive,
      isEnabled: isEnabled,
    );
  }
}

/// Provider for search query
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Provider for filtered rules
final filteredRulesProvider = Provider<List<Rule>>((ref) {
  final rules = ref.watch(rulesProvider);
  final searchQuery = ref.watch(searchQueryProvider);

  if (searchQuery.isEmpty) {
    return rules;
  }

  final rulesNotifier = ref.watch(rulesProvider.notifier);
  return rulesNotifier.searchRules(searchQuery);
});
