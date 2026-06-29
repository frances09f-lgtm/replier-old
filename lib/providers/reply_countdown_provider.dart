import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auto_reply_service.dart';

/// Model for reply countdown state
class ReplyCountdownData {
  final bool isActive;
  final String sender;
  final String replyText;
  final int totalMs;
  final int remainingMs;
  final DateTime scheduledAt;

  ReplyCountdownData({
    this.isActive = false,
    this.sender = '',
    this.replyText = '',
    this.totalMs = 0,
    this.remainingMs = 0,
    DateTime? scheduledAt,
  }) : scheduledAt = scheduledAt ?? DateTime.now();

  double get progress =>
      totalMs > 0 ? (1 - remainingMs / totalMs).clamp(0.0, 1.0) : 0.0;

  String get remainingFormatted {
    final seconds = (remainingMs / 1000).ceil();
    if (seconds <= 0) return 'Sending...';
    return '${seconds}s';
  }

  ReplyCountdownData copyWith({
    bool? isActive,
    String? sender,
    String? replyText,
    int? totalMs,
    int? remainingMs,
    DateTime? scheduledAt,
  }) {
    return ReplyCountdownData(
      isActive: isActive ?? this.isActive,
      sender: sender ?? this.sender,
      replyText: replyText ?? this.replyText,
      totalMs: totalMs ?? this.totalMs,
      remainingMs: remainingMs ?? this.remainingMs,
      scheduledAt: scheduledAt ?? this.scheduledAt,
    );
  }
}

/// Notifier for reply countdown state
class ReplyCountdownNotifier extends StateNotifier<ReplyCountdownData> {
  Timer? _countdownTimer;

  ReplyCountdownNotifier() : super(ReplyCountdownData()) {
    AutoReplyService.onReplyScheduled = _onReplyScheduled;
    AutoReplyService.onReplyCompleted = _onReplyCompleted;
  }

  void _onReplyScheduled(Map<String, dynamic> data) {
    final delayMs = data['delayMs'] as int? ?? 0;
    final sender = data['sender'] as String? ?? '';
    final replyText = data['replyText'] as String? ?? '';

    _countdownTimer?.cancel();

    state = ReplyCountdownData(
      isActive: true,
      sender: sender,
      replyText: replyText,
      totalMs: delayMs,
      remainingMs: delayMs,
      scheduledAt: DateTime.now(),
    );

    if (delayMs > 0) {
      _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        _tick();
      });
    }
  }

  void _onReplyCompleted() {
    _countdownTimer?.cancel();
    state = ReplyCountdownData();
  }

  void _tick() {
    if (state.remainingMs <= 0) {
      _countdownTimer?.cancel();
      return;
    }
    final newRemaining = state.remainingMs - 100;
    state = state.copyWith(
      remainingMs: newRemaining > 0 ? newRemaining : 0,
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    AutoReplyService.onReplyScheduled = null;
    AutoReplyService.onReplyCompleted = null;
    super.dispose();
  }
}

/// Provider for reply countdown data
final replyCountdownProvider =
    StateNotifierProvider<ReplyCountdownNotifier, ReplyCountdownData>((ref) {
  return ReplyCountdownNotifier();
});
