import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import '../core/hive_config.dart';
import '../core/constants.dart';
import '../models/reply_log.dart';

/// Repository for managing reply logs
@injectable
class LogRepository {
  final Uuid _uuid = const Uuid();

  /// Get all logs
  List<ReplyLog> getAllLogs() {
    final box = HiveConfig.getLogsBox();
    return box.values.toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  /// Get logs by app name
  List<ReplyLog> getLogsByApp(String appName) {
    final logs = getAllLogs();
    return logs.where((log) => log.appName == appName).toList();
  }

  /// Get logs filtered by app name
  List<ReplyLog> filterLogsByApp(String? appName) {
    if (appName == null || appName.isEmpty) {
      return getAllLogs();
    }
    return getLogsByApp(appName);
  }

  /// Add a new log
  Future<void> addLog(ReplyLog log) async {
    final box = HiveConfig.getLogsBox();
    await box.put(log.id, log);

    // Enforce maximum log limit
    final logs = getAllLogs();
    if (logs.length > AppConstants.maxLogs) {
      // Remove oldest logs
      final logsToRemove = logs.skip(AppConstants.maxLogs);
      for (final log in logsToRemove) {
        await box.delete(log.id);
      }
    }
  }

  /// Clear all logs
  Future<void> clearLogs() async {
    final box = HiveConfig.getLogsBox();
    await box.clear();
  }

  /// Clear logs by app name
  Future<void> clearLogsByApp(String appName) async {
    final box = HiveConfig.getLogsBox();
    final logs = getLogsByApp(appName);
    for (final log in logs) {
      await box.delete(log.id);
    }
  }

  /// Get total logs count (replies sent)
  int getTotalLogsCount() {
    final box = HiveConfig.getLogsBox();
    return box.length;
  }

  /// Increment notifications received counter
  Future<void> incrementNotificationsReceived() async {
    final statsBox = HiveConfig.getStatsBox();
    final current = statsBox.get('totalNotificationsReceived', defaultValue: 0) as int;
    await statsBox.put('totalNotificationsReceived', current + 1);
  }

  /// Get total notifications received
  int getTotalNotificationsReceived() {
    final statsBox = HiveConfig.getStatsBox();
    return statsBox.get('totalNotificationsReceived', defaultValue: 0) as int;
  }

  /// Get logs count by app
  int getLogsCountByApp(String appName) {
    final box = HiveConfig.getLogsBox();
    return box.values.where((log) => log.appName == appName).length;
  }

  /// Check if a similar reply was recently sent (for duplicate prevention)
  bool wasReplyRecentlySent(String sender, String message, String reply, {Duration within = const Duration(minutes: 5)}) {
    final logs = getAllLogs();
    final now = DateTime.now();
    
    return logs.any((log) =>
      log.sender == sender &&
      log.originalMessage == message &&
      log.autoReplySent == reply &&
      now.difference(log.dateTime) <= within
    );
  }

  /// Get replies count grouped by AI model (today only, resets at midnight)
  Map<String, int> getAiReplyCounts() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final logs = getAllLogs();
    final counts = <String, int>{};
    for (final log in logs) {
      if (log.aiModel.isNotEmpty && log.dateTime.isAfter(todayStart.subtract(const Duration(seconds: 1)))) {
        counts[log.aiModel] = (counts[log.aiModel] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Get last reply log
  ReplyLog? getLastReplyLog() {
    final logs = getAllLogs();
    return logs.isNotEmpty ? logs.first : null;
  }

  /// Create a new log
  ReplyLog createLog({
    required String sender,
    required String originalMessage,
    required String autoReplySent,
    required String appName,
    required String ruleId,
  }) {
    return ReplyLog(
      id: _uuid.v4(),
      sender: sender,
      originalMessage: originalMessage,
      autoReplySent: autoReplySent,
      appName: appName,
      dateTime: DateTime.now(),
      ruleId: ruleId,
    );
  }
}
