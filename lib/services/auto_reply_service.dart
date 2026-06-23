import 'dart:convert';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../models/notification_data.dart';
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

  static const MethodChannel _notificationChannel =
      MethodChannel(AppConstants.notificationChannel);

  AutoReplyService({
    required RuleRepository ruleRepository,
    required LogRepository logRepository,
  })  : _ruleRepository = ruleRepository,
        _logRepository = logRepository;

  void initialize() {
    _notificationChannel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onNotificationPosted':
        // Native already handled the reply — just log it.
        final notification = NotificationData.fromJson(
          json.decode(call.arguments as String) as Map<String, dynamic>,
        );
        await _maybeLog(notification);
        break;
      case 'onReplyFailed':
        print('AutoReplyService: reply failed — ${call.arguments}');
        break;
      case 'onReplySuccess':
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
      if (allRules.any((r) => r.replyText.trim().toLowerCase() == lower)) {
        return;
      }

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
    } catch (e) {
      print('AutoReplyService logging error: $e');
    }
  }
}
