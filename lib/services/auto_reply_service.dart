import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../models/notification_data.dart';
import '../providers/log_provider.dart';
import '../repositories/log_repository.dart';
import '../repositories/rule_repository.dart';

/// Listens to the notification MethodChannel for logging purposes only.
///
/// The actual auto-reply logic runs entirely on the native (Kotlin) side.
/// This class must NOT send any replies — doing so causes double-replies.
/// It only writes log entries to Hive when the native side reports a success.
class AutoReplyService {
  final RuleRepository _ruleRepository;
  final LogRepository _logRepository;
  final ProviderContainer? _providerContainer;

  static const MethodChannel _notificationChannel =
      MethodChannel(AppConstants.notificationChannel);

  static AutoReplyService? _instance;

  /// Callback for AI usage updates
  static Function(Map<String, dynamic>)? onAiUsageUpdate;

  /// Callback for reply scheduled (countdown)
  static Function(Map<String, dynamic>)? onReplyScheduled;

  /// Callback for reply completed (sent or failed)
  static VoidCallback? onReplyCompleted;

  AutoReplyService({
    required RuleRepository ruleRepository,
    required LogRepository logRepository,
    ProviderContainer? providerContainer,
  })  : _ruleRepository = ruleRepository,
        _logRepository = logRepository,
        _providerContainer = providerContainer {
    _instance = this;
  }

  void initialize() {
    _notificationChannel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onNotificationPosted':
        if (_instance != null && call.arguments != null) {
          final notification = NotificationData.fromJson(
            json.decode(call.arguments as String) as Map<String, dynamic>,
          );
          await _instance!._maybeLog(notification);
        }
        break;
      case 'onAiUsageUpdate':
        if (call.arguments != null) {
          final usageData = json.decode(call.arguments as String) as Map<String, dynamic>;
          onAiUsageUpdate?.call(usageData);
        }
        break;
      case 'onReplyFailed':
        print('AutoReplyService: reply failed — ${call.arguments}');
        onReplyCompleted?.call();
        break;
      case 'onReplySuccess':
        if (_instance != null && call.arguments != null) {
          final data = json.decode(call.arguments as String) as Map<String, dynamic>;
          await _instance!._logReply(data);
        }
        onReplyCompleted?.call();
        break;
      case 'onReplyScheduled':
        if (call.arguments != null) {
          final data = json.decode(call.arguments as String) as Map<String, dynamic>;
          onReplyScheduled?.call(data);
        }
        break;
      case 'onNotificationRemoved':
      case 'useAccessibilityService':
        break;
    }
    return null;
  }

  Future<void> _maybeLog(NotificationData notification) async {
    try {
      // Only log if native would have replied (same rule check, no sending)
      final allRules = _ruleRepository.getEnabledRules();
      final lower = notification.message.trim().toLowerCase();

      // Skip self-sent
      if (allRules.any((r) =>
          r.effectiveReplies.any((reply) => reply.trim().toLowerCase() == lower))) {
        return;
      }

      // Track every notification received (only for actual external messages)
      await _logRepository.incrementNotificationsReceived();

      // For rule-based replies, create the log here
      final rule = _ruleRepository.findMatchingRule(notification.message);
      if (rule == null) return;

      final log = _logRepository.createLog(
        sender: notification.sender,
        originalMessage: notification.message,
        autoReplySent: rule.replyText,
        appName: notification.appName,
        ruleId: rule.id,
      );
      await _logRepository.addLog(log);

      if (_providerContainer != null) {
        final notifier = _providerContainer!.read(logsProvider.notifier);
        await notifier.refreshLogs();
      }
    } catch (e) {
      print('AutoReplyService logging error: $e');
    }
  }

  Future<void> _logReply(Map<String, dynamic> data) async {
    try {
      // Only log AI replies here (rule-based replies are logged in _maybeLog)
      if (data['isAiReply'] != true) return;

      final log = _logRepository.createLog(
        sender: data['sender'] ?? '',
        originalMessage: 'AI Generated Reply',
        autoReplySent: data['replyText'] ?? '',
        appName: data['appName'] ?? '',
        ruleId: '',
      );
      await _logRepository.addLog(log);

      if (_providerContainer != null) {
        final notifier = _providerContainer!.read(logsProvider.notifier);
        await notifier.refreshLogs();
      }
    } catch (e) {
      print('AutoReplyService reply logging error: $e');
    }
  }
}
