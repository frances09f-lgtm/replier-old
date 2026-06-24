import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

/// Screen for app settings
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final permissions = ref.watch(permissionStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Permissions section
          Text(
            'Permissions',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _PermissionTile(
            title: 'Notification Access',
            subtitle: 'Required to read notifications',
            isGranted: permissions['notificationListener'] ?? false,
            onGrant: () => ref
                .read(permissionStatusProvider.notifier)
                .openNotificationListenerSettings(),
          ),

          _PermissionTile(
            title: 'Accessibility Service',
            subtitle: 'Required for auto-reply fallback',
            isGranted: permissions['accessibilityService'] ?? false,
            onGrant: () => ref
                .read(permissionStatusProvider.notifier)
                .openAccessibilitySettings(),
          ),

          _PermissionTile(
            title: 'Battery Optimization',
            subtitle: 'Disable for reliable background operation',
            isGranted: permissions['batteryOptimization'] ?? false,
            onGrant: () => ref
                .read(permissionStatusProvider.notifier)
                .openBatteryOptimizationSettings(),
          ),

          const SizedBox(height: 24),

          // App settings section
          Text(
            'App Settings',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          SwitchListTile(
            title: const Text('WhatsApp'),
            subtitle: const Text('Enable auto-reply for WhatsApp'),
            value: settings.whatsappEnabled,
            onChanged: (_) {
              ref.read(appSettingsProvider.notifier).toggleWhatsappEnabled();
            },
          ),

          SwitchListTile(
            title: const Text('Instagram'),
            subtitle: const Text('Enable auto-reply for Instagram'),
            value: settings.instagramEnabled,
            onChanged: (_) {
              ref.read(appSettingsProvider.notifier).toggleInstagramEnabled();
            },
          ),

          const SizedBox(height: 16),

          // Reply delay range
          ListTile(
            title: const Text('Reply Delay Range'),
            subtitle: Text('${settings.minReplyDelaySeconds}s - ${settings.maxReplyDelaySeconds}s (random)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showReplyDelayDialog(
              context, ref, settings.minReplyDelaySeconds, settings.maxReplyDelaySeconds),
          ),

          SwitchListTile(
            title: const Text('Prevent Duplicate Replies'),
            subtitle: const Text('Avoid sending same reply repeatedly'),
            value: settings.preventDuplicateReplies,
            onChanged: (_) {
              ref
                  .read(appSettingsProvider.notifier)
                  .togglePreventDuplicateReplies();
            },
          ),

          SwitchListTile(
            title: const Text('Ignore Group Chats'),
            subtitle: const Text('Don\'t reply to group messages'),
            value: settings.ignoreGroupChats,
            onChanged: (_) {
              ref.read(appSettingsProvider.notifier).toggleIgnoreGroupChats();
            },
          ),

          const SizedBox(height: 24),

          // Appearance section
          Text(
            'Appearance',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Use dark theme'),
            value: settings.darkMode,
            onChanged: (_) {
              ref.read(appSettingsProvider.notifier).toggleDarkMode();
            },
          ),

          const SizedBox(height: 24),

          // Warning section
          Card(
            color: Colors.orange[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange[900]),
                      const SizedBox(width: 8),
                      Text(
                        'Important Notice',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Automated replying to WhatsApp or Instagram may violate their Terms of Service. '
                    'This app uses official Android notification APIs where possible. '
                    'Use at your own risk and with caution.',
                    style: TextStyle(color: Colors.orange[900], fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReplyDelayDialog(
    BuildContext context,
    WidgetRef ref,
    int currentMin,
    int currentMax,
  ) {
    int tempMin = currentMin;
    int tempMax = currentMax;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reply Delay Range'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Min: $tempMin s  |  Max: $tempMax s'),
              const SizedBox(height: 16),
              const Text('Minimum delay:'),
              Slider(
                value: tempMin.toDouble(),
                min: 0,
                max: 60,
                divisions: 60,
                label: '${tempMin}s',
                onChanged: (value) {
                  setDialogState(() {
                    tempMin = value.toInt();
                    if (tempMin > tempMax) tempMax = tempMin;
                  });
                },
              ),
              const SizedBox(height: 8),
              const Text('Maximum delay:'),
              Slider(
                value: tempMax.toDouble(),
                min: tempMin.toDouble(),
                max: 60,
                divisions: (60 - tempMin),
                label: '${tempMax}s',
                onChanged: (value) {
                  setDialogState(() {
                    tempMax = value.toInt();
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                ref
                    .read(appSettingsProvider.notifier)
                    .updateReplyDelayRange(tempMin, tempMax);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isGranted;
  final VoidCallback onGrant;

  const _PermissionTile({
    required this.title,
    required this.subtitle,
    required this.isGranted,
    required this.onGrant,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          isGranted ? Icons.check_circle : Icons.error,
          color: isGranted ? Colors.green : Colors.orange,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: isGranted
            ? const Text('Granted', style: TextStyle(color: Colors.green))
            : ElevatedButton(onPressed: onGrant, child: const Text('Grant')),
      ),
    );
  }
}
