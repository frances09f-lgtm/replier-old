import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/statistics_repository.dart';
import 'settings_provider.dart';
import 'rule_provider.dart';
import 'log_provider.dart';

/// Provider for statistics repository
final statisticsRepositoryProvider = Provider<StatisticsRepository>((ref) {
  return StatisticsRepository(
    ref.watch(settingsRepositoryProvider),
    ref.watch(ruleRepositoryProvider),
    ref.watch(logRepositoryProvider),
  );
});

/// Provider for dashboard statistics
final dashboardStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final repository = ref.watch(statisticsRepositoryProvider);
  return repository.getDashboardStats();
});

/// Provider for total notifications received
final totalNotificationsProvider = Provider<int>((ref) {
  final repository = ref.watch(statisticsRepositoryProvider);
  return repository.getTotalNotificationsReceived();
});

/// Provider for total replies sent
final totalRepliesProvider = Provider<int>((ref) {
  final repository = ref.watch(statisticsRepositoryProvider);
  return repository.getTotalRepliesSent();
});

/// Provider for last reply sent
final lastReplyProvider = Provider<DateTime?>((ref) {
  final repository = ref.watch(statisticsRepositoryProvider);
  return repository.getLastReplySent();
});

/// Provider for active rules count
final activeRulesCountProvider = Provider<int>((ref) {
  final repository = ref.watch(statisticsRepositoryProvider);
  return repository.getActiveRulesCount();
});
