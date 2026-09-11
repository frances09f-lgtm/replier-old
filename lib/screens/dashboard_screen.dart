import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../providers/statistics_provider.dart';
import '../providers/log_provider.dart';
import '../providers/rule_provider.dart';
import '../providers/reply_countdown_provider.dart';
import '../widgets/pipeline_status_card.dart';
import 'rules_screen.dart';
import 'logs_screen.dart';
import 'settings_screen.dart';
import 'chat_screen.dart';

/// Dashboard screen with master switch and quick-action navigation
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final stats = ref.watch(dashboardStatsProvider);
    final replyCountdown = ref.watch(replyCountdownProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatScreen()),
          );
        },
        child: const Icon(Icons.chat_bubble),
      ),
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(logsProvider.notifier).refreshLogs();
          ref.read(rulesProvider.notifier).refreshRules();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Master switch
              Card(
                child: SwitchListTile(
                  title: const Text('Master Enable'),
                  subtitle: const Text('Enable or disable auto-reply'),
                  value: settings.masterEnabled,
                  onChanged: (value) {
                    ref.read(appSettingsProvider.notifier).toggleMasterEnabled();
                  },
                ),
              ),

              // Reply delay badge
              if (settings.masterEnabled) ...[
                const SizedBox(height: 12),
                _buildReplyDelayBadge(context, settings, replyCountdown),
              ],

              // Pipeline status box — live real-time processing status
              const PipelineStatusCard(),

              // Schedule status badge
              if (settings.scheduleEnabled) ...[
                const SizedBox(height: 12),
                _buildScheduleBadge(context, settings),
              ],

              // Confirm before reply badge
              if (settings.confirmBeforeReply) ...[
                const SizedBox(height: 12),
                Card(
                  color: Colors.amber.shade50,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.shield, color: Colors.amber.shade700, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Safety Mode: Confirm Before Reply',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'You will be asked to approve each reply',
                                style: TextStyle(
                                  color: Colors.amber.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Statistics section
              Text(
                'Statistics',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              _buildStatsGrid(context, ref, stats),
              const SizedBox(height: 24),



              // Quick actions
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              _NavigationCard(
                title: 'Manage Rules',
                subtitle: 'Create and edit auto-reply rules',
                icon: Icons.rule,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RulesScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),

              _NavigationCard(
                title: 'View Logs',
                subtitle: 'See all auto-reply history',
                icon: Icons.history,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LogsScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),

              _NavigationCard(
                title: 'Settings',
                subtitle: 'Configure app preferences',
                icon: Icons.settings,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, WidgetRef ref, Map<String, dynamic> stats) {
    final dailyReplies = stats['dailyRepliesSent'] as int? ?? 0;
    final activeRules = stats['activeRulesCount'] as int? ?? 0;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.reply,
            label: 'Today\'s Replies',
            value: dailyReplies.toString(),
            color: Colors.green,
            onTap: () => _showAiReplyBreakdown(context, ref),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.rule,
            label: 'Active Rules',
            value: activeRules.toString(),
            color: Colors.orange,
          ),
        ),
      ],
    );
  }



  Widget _buildReplyDelayBadge(BuildContext context, AppSettings settings, ReplyCountdownData countdown) {
    final min = settings.minReplyDelaySeconds;
    final max = settings.maxReplyDelaySeconds;

    if (countdown.isActive) {
      return Card(
        color: Colors.teal.shade50,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  value: countdown.progress,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                  backgroundColor: Colors.teal.shade100,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Replying to ${countdown.sender}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (countdown.replyText.isNotEmpty)
                      Text(
                        '"${countdown.replyText}"',
                        style: TextStyle(
                          color: Colors.teal.shade600,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Text(
                        countdown.remainingFormatted,
                        style: TextStyle(
                          color: Colors.teal.shade600,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                countdown.remainingFormatted,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.timer, color: Colors.blue.shade700, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reply Delay',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    min == max
                        ? 'Fixed ${min}s delay before reply'
                        : 'Random delay ${min}s – ${max}s before reply',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleBadge(BuildContext context, AppSettings settings) {
    final isWithin = settings.isWithinSchedule();
    final startHour = settings.scheduleStartHour;
    final startMin = settings.scheduleStartMinute;
    final endHour = settings.scheduleEndHour;
    final endMin = settings.scheduleEndMinute;

    final startStr = _formatTime(startHour, startMin);
    final endStr = _formatTime(endHour, endMin);

    final color = isWithin ? Colors.green : Colors.orange;
    final bgColor = isWithin ? Colors.green.shade50 : Colors.orange.shade50;
    final icon = isWithin ? Icons.check_circle : Icons.pause_circle;
    final statusText = isWithin ? 'Active' : 'Paused';
    final detailText = isWithin
        ? 'Auto-reply is active ($startStr - $endStr)'
        : 'Auto-reply paused (outside $startStr - $endStr)';

    return Card(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Schedule: $statusText',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detailText,
                    style: TextStyle(
                      color: color.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  void _showAiReplyBreakdown(BuildContext context, WidgetRef ref) {
    final repository = ref.read(logRepositoryProvider);
    final counts = repository.getAiReplyCounts();
    final totalAi = counts.values.fold(0, (a, b) => a + b);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'AI Replies Breakdown',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                "Today's AI replies: $totalAi",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 16),
              if (counts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No AI replies recorded yet',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                )
              else
                ...counts.entries.map((entry) => _buildAiModelRow(context, entry.key, entry.value)),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAiModelRow(BuildContext context, String modelKey, int count) {
    final (label, icon, color) = switch (modelKey) {
      'deepseek_local' => ('DeepSeek-R1 1.5B (On-Device)', Icons.memory, Colors.purple),
      _ => (modelKey, Icons.smart_toy, Colors.grey),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Text(
            count.toString(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}


class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              if (onTap != null) ...[
                const SizedBox(height: 4),
                Icon(Icons.info_outline, size: 14, color: color.withValues(alpha: 0.5)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _NavigationCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}


