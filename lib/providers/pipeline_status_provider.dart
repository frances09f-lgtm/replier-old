import 'dart:async';
import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auto_reply_service.dart';

/// The four stages of the auto-reply pipeline
enum PipelineStage { gotMessage, analysing, replyReady, sending }

/// State held by the pipeline status provider
class PipelineStatusData {
  final PipelineStage? stage;
  final String sender;
  final int countdownSeconds;

  const PipelineStatusData({
    this.stage,
    this.sender = '',
    this.countdownSeconds = 0,
  });

  bool get isIdle => stage == null;

  PipelineStatusData copyWith({
    PipelineStage? stage,
    String? sender,
    int? countdownSeconds,
  }) {
    return PipelineStatusData(
      stage: stage ?? this.stage,
      sender: sender ?? this.sender,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
    );
  }
}

// Internal event types
enum _EventType { gotMessage, analysing, replyReady, replyScheduled, replyCompleted }

class _PipelineEvent {
  final _EventType type;
  final String sender;
  final int delayMs; // only for replyScheduled
  const _PipelineEvent(this.type, {this.sender = '', this.delayMs = 0});
}

class PipelineStatusNotifier extends StateNotifier<PipelineStatusData> {
  // Minimum time each stage stays visible before the next one shows
  static const _minDisplayMs = {
    PipelineStage.gotMessage: 700,
    PipelineStage.analysing:  800,
    PipelineStage.replyReady: 700,
    PipelineStage.sending:    0,    // sending runs its real countdown
  };

  final Queue<_PipelineEvent> _queue = Queue();
  bool _processing = false;
  Timer? _stageTimer;
  Timer? _countdownTimer;
  Timer? _stalenessTimer;

  PipelineStatusNotifier() : super(const PipelineStatusData()) {
    AutoReplyService.onPipelineStatus = _onPipelineStatus;
    AutoReplyService.onReplyScheduled = _onReplyScheduled;
    AutoReplyService.onReplyCompleted = _onReplyCompleted;
  }

  // ── Incoming native events ────────────────────────────────────────────────

  void _onPipelineStatus(Map<String, dynamic> data) {
    final stageStr = data['state'] as String? ?? '';
    final sender   = data['sender'] as String? ?? '';

    final type = switch (stageStr) {
      'got_message' => _EventType.gotMessage,
      'analysing'   => _EventType.analysing,
      'reply_ready' => _EventType.replyReady,
      _             => null,
    };
    if (type == null) return;

    _enqueue(_PipelineEvent(type, sender: sender));
  }

  void _onReplyScheduled(Map<String, dynamic> data) {
    final delayMs = (data['delayMs'] as num?)?.toInt() ?? 0;
    final sender  = data['sender'] as String? ?? '';
    _enqueue(_PipelineEvent(_EventType.replyScheduled, sender: sender, delayMs: delayMs));
  }

  void _onReplyCompleted() {
    // Terminal event — skip the queue, go idle immediately
    _queue.clear();
    _cancelTimers();
    state = const PipelineStatusData();
    _processing = false;
  }

  // ── Queue processor ───────────────────────────────────────────────────────

  void _enqueue(_PipelineEvent event) {
    _queue.addLast(event);
    if (!_processing) _processNext();
  }

  void _processNext() {
    if (_queue.isEmpty) {
      _processing = false;
      return;
    }

    _processing = true;
    final event = _queue.removeFirst();

    switch (event.type) {
      case _EventType.gotMessage:
        _showStage(PipelineStage.gotMessage, event.sender);
        break;

      case _EventType.analysing:
        _showStage(PipelineStage.analysing, event.sender);
        break;

      case _EventType.replyReady:
        _showStage(PipelineStage.replyReady, event.sender);
        break;

      case _EventType.replyScheduled:
        _startSending(event.sender, event.delayMs);
        break;

      case _EventType.replyCompleted:
        _cancelTimers();
        state = const PipelineStatusData();
        _processing = false;
        break;
    }
  }

  /// Display a stage for at least its minimum duration, then process next event.
  void _showStage(PipelineStage stage, String sender) {
    _cancelStageTimer();
    state = PipelineStatusData(stage: stage, sender: sender);

    final minMs = _minDisplayMs[stage] ?? 600;
    _stageTimer = Timer(Duration(milliseconds: minMs), () {
      _stageTimer = null;
      _processNext();
    });
  }

  /// Start the sending stage with a live countdown.
  void _startSending(String sender, int delayMs) {
    _cancelStageTimer();
    _cancelCountdownTimer();

    final countdownSecs = delayMs <= 0 ? 0 : (delayMs / 1000).ceil();

    state = PipelineStatusData(
      stage: PipelineStage.sending,
      sender: sender,
      countdownSeconds: countdownSecs,
    );

    if (countdownSecs > 0) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        final remaining = state.countdownSeconds - 1;
        if (remaining <= 0) {
          _cancelCountdownTimer();
          state = state.copyWith(countdownSeconds: 0);
          // Staleness guard: auto-clear if terminal event never arrives
          _stalenessTimer = Timer(const Duration(seconds: 30), () {
            if (!state.isIdle) {
              state = const PipelineStatusData();
              _processing = false;
            }
          });
        } else {
          state = state.copyWith(countdownSeconds: remaining);
        }
      });
    }

    // Sending holds until onReplyCompleted — don't call _processNext here
    _processing = true;
  }

  // ── Timer helpers ─────────────────────────────────────────────────────────

  void _cancelStageTimer() {
    _stageTimer?.cancel();
    _stageTimer = null;
  }

  void _cancelCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _cancelTimers() {
    _cancelStageTimer();
    _cancelCountdownTimer();
    _stalenessTimer?.cancel();
    _stalenessTimer = null;
  }

  @override
  void dispose() {
    _cancelTimers();
    AutoReplyService.onPipelineStatus = null;
    super.dispose();
  }
}

final pipelineStatusProvider =
    StateNotifierProvider<PipelineStatusNotifier, PipelineStatusData>((ref) {
  return PipelineStatusNotifier();
});
