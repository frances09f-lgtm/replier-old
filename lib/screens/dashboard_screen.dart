import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../providers/statistics_provider.dart';
import '../providers/log_provider.dart';
import '../providers/rule_provider.dart';
import '../providers/ai_usage_provider.dart';
import 'rules_screen.dart';
import 'logs_screen.dart';
import 'settings_screen.dart';

/// Dashboard screen with master switch and quick-action navigation
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final stats = ref.watch(dashboardStatsProvider);
    final aiUsage = ref.watch(aiUsageProvider);

    return Scaffold(
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
              const SizedBox(height: 24),

              // Statistics section
              Text(
                'Statistics',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              _buildStatsGrid(context, stats),
              const SizedBox(height: 24),

              // AI Usage section (only show if AI is enabled)
              if (settings.aiReplyEnabled) ...[
                Text(
                  'AI Usage',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _buildAiUsageCard(context, aiUsage, settings),
                const SizedBox(height: 24),
              ],

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

  Widget _buildStatsGrid(BuildContext context, Map<String, dynamic> stats) {
    final totalNotifications = stats['totalNotificationsReceived'] as int? ?? 0;
    final totalReplies = stats['totalRepliesSent'] as int? ?? 0;
    final activeRules = stats['activeRulesCount'] as int? ?? 0;
    final lastReply = stats['lastReplySent'] as DateTime?;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.notifications,
                label: 'Notifications',
                value: totalNotifications.toString(),
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.reply,
                label: 'Replies Sent',
                value: totalReplies.toString(),
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.rule,
                label: 'Active Rules',
                value: activeRules.toString(),
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.access_time,
                label: 'Last Reply',
                value: _formatLastReply(lastReply),
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatLastReply(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildAiUsageCard(BuildContext context, AiUsageData aiUsage, AppSettings settings) {
    final color = aiUsage.isRateLimited ? Colors.red : Colors.teal;
    final usagePercent = aiUsage.usagePercent.clamp(0, 100);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  aiUsage.isRateLimited ? Icons.warning : Icons.smart_toy,
                  color: color,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Groq AI (Llama 3.3)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                if (aiUsage.isRateLimited)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Rate Limited',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Usage progress bar
            if (aiUsage.tokensLimit > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Token Usage',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '${usagePercent.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: usagePercent / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    usagePercent > 90 ? Colors.red : color,
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 12),

              // Token counts
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _UsageStat(
                    label: 'Used',
                    value: aiUsage.tokensUsed.toString(),
                    color: Colors.orange,
                  ),
                  _UsageStat(
                    label: 'Remaining',
                    value: aiUsage.tokensRemaining.toString(),
                    color: Colors.green,
                  ),
                  _UsageStat(
                    label: 'Limit',
                    value: aiUsage.tokensLimit.toString(),
                    color: Colors.blue,
                  ),
                ],
              ),

              // Reset time
              if (aiUsage.resetInSeconds > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Resets in ${aiUsage.resetTimeFormatted}',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              // No usage data yet
              Center(
                child: Column(
                  children: [
                    Icon(Icons.cloud_off, size: 32, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      'No usage data yet',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Usage will appear after first AI reply',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Error message
            if (aiUsage.error.isNotEmpty && !aiUsage.error.contains('try again')) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  aiUsage.error,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
          ],
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

class _UsageStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _UsageStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
      ],
    );
  }
}
