import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../providers/statistics_provider.dart';
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
      body: SingleChildScrollView(
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
