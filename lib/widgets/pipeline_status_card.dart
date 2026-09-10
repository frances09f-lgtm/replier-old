import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pipeline_status_provider.dart';

/// Single persistent card that animates between pipeline stages.
/// Uses AnimatedSwitcher for content cross-fade and AnimatedContainer
/// for the smooth background colour transition.
class PipelineStatusCard extends ConsumerWidget {
  const PipelineStatusCard({super.key});

  // ── Per-stage styling ────────────────────────────────────────────────────

  static const _bg = {
    PipelineStage.gotMessage: Color(0xFFE3F2FD),  // blue 50
    PipelineStage.analysing:  Color(0xFFFFF8E1),  // amber 50
    PipelineStage.replyReady: Color(0xFFE8F5E9),  // green 50
    PipelineStage.sending:    Color(0xFFF3E5F5),  // purple 50
  };

  static const _accent = {
    PipelineStage.gotMessage: Color(0xFF1565C0),  // blue 800
    PipelineStage.analysing:  Color(0xFFE65100),  // deep orange 900
    PipelineStage.replyReady: Color(0xFF2E7D32),  // green 800
    PipelineStage.sending:    Color(0xFF6A1B9A),  // purple 800
  };

  static const _icon = {
    PipelineStage.gotMessage: Icons.move_to_inbox_rounded,
    PipelineStage.analysing:  Icons.hourglass_top_rounded,
    PipelineStage.replyReady: Icons.check_circle_rounded,
    PipelineStage.sending:    Icons.send_rounded,
  };

  static const _label = {
    PipelineStage.gotMessage: 'Got new message',
    PipelineStage.analysing:  'Analysing',
    PipelineStage.replyReady: 'Reply ready',
    PipelineStage.sending:    'Sending',
  };

  static const _stageOrder = [
    PipelineStage.gotMessage,
    PipelineStage.analysing,
    PipelineStage.replyReady,
    PipelineStage.sending,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(pipelineStatusProvider);

    // Hidden when idle — zero height so it doesn't occupy space
    if (status.isIdle) return const SizedBox.shrink();

    final stage  = status.stage!;
    final bg     = _bg[stage]!;
    final accent = _accent[stage]!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            // ── Left: icon / spinner ─────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: stage == PipelineStage.analysing
                  ? SizedBox(
                      key: const ValueKey('spinner'),
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    )
                  : Icon(
                      _icon[stage],
                      key: ValueKey(stage),
                      color: accent,
                      size: 26,
                    ),
            ),

            const SizedBox(width: 12),

            // ── Centre: label + sender ───────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Column(
                  key: ValueKey(stage),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      stage == PipelineStage.sending
                          ? 'Sending in ${status.countdownSeconds}s'
                          : _label[stage]!,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: accent,
                        fontSize: 14,
                      ),
                    ),
                    if (status.sender.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        status.sender,
                        style: TextStyle(
                          color: accent.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),

            // ── Right: progress dots ─────────────────────────────────────
            Row(
              mainAxisSize: MainAxisSize.min,
              children: _stageOrder.map((s) {
                final idx     = _stageOrder.indexOf(s);
                final current = _stageOrder.indexOf(stage);
                final isActive = idx == current;
                final isDone   = idx < current;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(left: 5),
                  width:  isActive ? 9 : 6,
                  height: isActive ? 9 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(
                      alpha: isActive ? 1.0 : isDone ? 0.4 : 0.15,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
