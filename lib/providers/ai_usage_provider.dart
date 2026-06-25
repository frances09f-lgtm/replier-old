import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auto_reply_service.dart';
import '../services/notification_service.dart';
import 'settings_provider.dart';

/// Model for AI usage data
class AiUsageData {
  final int tokensUsed;
  final int tokensRemaining;
  final int tokensLimit;
  final int resetInSeconds;
  final String error;
  final DateTime timestamp;

  AiUsageData({
    this.tokensUsed = 0,
    this.tokensRemaining = 0,
    this.tokensLimit = 0,
    this.resetInSeconds = 0,
    this.error = '',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  double get usagePercent =>
      tokensLimit > 0 ? (tokensUsed / tokensLimit * 100) : 0;

  bool get isRateLimited => error.isNotEmpty || (tokensLimit > 0 && tokensRemaining <= 0);

  String get resetTimeFormatted {
    if (resetInSeconds <= 0) return '';
    final minutes = resetInSeconds ~/ 60;
    final seconds = resetInSeconds % 60;
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  String get tokensUsedFormatted {
    if (tokensLimit > 0) {
      return '$tokensUsed / $tokensLimit';
    }
    return tokensUsed.toString();
  }

  AiUsageData copyWith({
    int? tokensUsed,
    int? tokensRemaining,
    int? tokensLimit,
    int? resetInSeconds,
    String? error,
    DateTime? timestamp,
  }) {
    return AiUsageData(
      tokensUsed: tokensUsed ?? this.tokensUsed,
      tokensRemaining: tokensRemaining ?? this.tokensRemaining,
      tokensLimit: tokensLimit ?? this.tokensLimit,
      resetInSeconds: resetInSeconds ?? this.resetInSeconds,
      error: error ?? this.error,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// Notifier for AI usage state
class AiUsageNotifier extends StateNotifier<AiUsageData> {
  final NotificationService _notificationService;
  Timer? _refreshTimer;
  Timer? _countdownTimer;

  AiUsageNotifier(this._notificationService) : super(AiUsageData()) {
    // Listen for real-time updates from native
    AutoReplyService.onAiUsageUpdate = (data) {
      updateFromNative(data);
    };

    // Delay initial load to ensure native side is ready
    Future.delayed(const Duration(seconds: 2), () {
      loadUsage();
    });
    // Refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      loadUsage();
    });
    // Countdown every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick();
    });
  }

  void _tick() {
    if (state.resetInSeconds > 0) {
      state = state.copyWith(resetInSeconds: state.resetInSeconds - 1);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    AutoReplyService.onAiUsageUpdate = null;
    super.dispose();
  }

  Future<void> loadUsage() async {
    try {
      final usage = await _notificationService.getAiUsage();
      if (usage != null && usage.isNotEmpty) {
        state = AiUsageData(
          tokensUsed: usage['tokensUsed'] ?? 0,
          tokensRemaining: usage['tokensRemaining'] ?? 0,
          tokensLimit: usage['tokensLimit'] ?? 0,
          resetInSeconds: usage['resetInSeconds'] ?? 0,
          error: usage['error'] ?? '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(usage['timestamp'] ?? 0),
        );
      }
    } catch (e) {
      // Silently fail - will retry on next timer tick
    }
  }

  void updateFromNative(Map<String, dynamic> data) {
    state = AiUsageData(
      tokensUsed: data['tokensUsed'] ?? state.tokensUsed,
      tokensRemaining: data['tokensRemaining'] ?? state.tokensRemaining,
      tokensLimit: data['tokensLimit'] ?? state.tokensLimit,
      resetInSeconds: data['resetInSeconds'] ?? state.resetInSeconds,
      error: data['error'] ?? state.error,
    );
  }
}

/// Provider for AI usage data
final aiUsageProvider =
    StateNotifierProvider<AiUsageNotifier, AiUsageData>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  return AiUsageNotifier(notificationService);
});
