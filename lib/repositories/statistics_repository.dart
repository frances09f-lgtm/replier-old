import 'package:injectable/injectable.dart';
import 'settings_repository.dart';
import 'rule_repository.dart';
import 'log_repository.dart';

/// Repository for statistics and dashboard data
@injectable
class StatisticsRepository {
  final SettingsRepository _settingsRepository;
  final RuleRepository _ruleRepository;
  final LogRepository _logRepository;

  StatisticsRepository(
    this._settingsRepository,
    this._ruleRepository,
    this._logRepository,
  );

  /// Get dashboard statistics
  Map<String, dynamic> getDashboardStats() {
    return {
      'totalNotificationsReceived': _logRepository.getTotalLogsCount(),
      'totalRepliesSent': _logRepository.getTotalLogsCount(),
      'lastReplySent': _logRepository.getLastReplyLog()?.dateTime,
      'activeRulesCount': _ruleRepository.getActiveRulesCount(),
      'masterEnabled': _settingsRepository.getSettings().masterEnabled,
    };
  }

  /// Get total notifications received
  int getTotalNotificationsReceived() {
    return _logRepository.getTotalLogsCount();
  }

  /// Get total replies sent
  int getTotalRepliesSent() {
    return _logRepository.getTotalLogsCount();
  }

  /// Get last reply sent
  DateTime? getLastReplySent() {
    return _logRepository.getLastReplyLog()?.dateTime;
  }

  /// Get active rules count
  int getActiveRulesCount() {
    return _ruleRepository.getActiveRulesCount();
  }

  /// Get logs count by app
  int getLogsCountByApp(String appName) {
    return _logRepository.getLogsCountByApp(appName);
  }
}
