import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../services/ai_service.dart';

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

          // Reply delay
          ListTile(
            title: const Text('Reply Delay'),
            subtitle: Text('${settings.replyDelaySeconds} seconds'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                _showReplyDelayDialog(context, ref, settings.replyDelaySeconds),
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

          // AI Settings section
          Text(
            'AI Settings',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          SwitchListTile(
            title: Row(
              children: [
                const Text('Enable AI Replies'),
                const SizedBox(width: 8),
                Icon(Icons.auto_awesome, 
                  size: 18, 
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            subtitle: const Text('Use AI to generate dynamic replies'),
            value: settings.aiEnabled,
            onChanged: (_) {
              ref.read(appSettingsProvider.notifier).toggleAiEnabled();
            },
          ),

          ListTile(
            title: const Text('API Key'),
            subtitle: Text(
              settings.groqApiKey?.isNotEmpty == true 
                ? '••••••••••••••••'
                : 'Not configured',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showApiKeyDialog(context, ref, settings.groqApiKey ?? ''),
          ),

          ListTile(
            title: const Text('AI Model'),
            subtitle: Text(settings.aiModel),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showModelDialog(context, ref, settings.aiModel),
          ),

          ListTile(
            title: const Text('AI Personality'),
            subtitle: Text(
              settings.aiSystemPrompt.length > 50
                ? '${settings.aiSystemPrompt.substring(0, 50)}...'
                : settings.aiSystemPrompt,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showSystemPromptDialog(context, ref, settings.aiSystemPrompt),
          ),

          if (settings.aiEnabled && settings.groqApiKey?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: () => _testAiConnection(context, ref),
                icon: const Icon(Icons.sync),
                label: const Text('Test AI Connection'),
              ),
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

  void _showApiKeyDialog(
    BuildContext context,
    WidgetRef ref,
    String currentKey,
  ) {
    final controller = TextEditingController(text: currentKey);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Groq API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your Groq API key:'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'gsk_...',
                border: OutlineInputBorder(),
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 12),
            const Text(
              'Get your free API key from console.groq.com',
              style: TextStyle(fontSize: 12, color: Colors.grey),
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
                  .updateGroqApiKey(controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showModelDialog(
    BuildContext context,
    WidgetRef ref,
    String currentModel,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select AI Model'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AiService.availableModels.map((model) {
            return RadioListTile<String>(
              title: Text(
                model,
                style: const TextStyle(fontSize: 12),
              ),
              value: model,
              groupValue: currentModel,
              onChanged: (value) {
                ref
                    .read(appSettingsProvider.notifier)
                    .updateAiModel(value!);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSystemPromptDialog(
    BuildContext context,
    WidgetRef ref,
    String currentPrompt,
  ) {
    final controller = TextEditingController(text: currentPrompt);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI Personality'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Define how the AI should respond:'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'You are a helpful assistant...',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
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
                  .updateAiSystemPrompt(controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _testAiConnection(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final settings = ref.read(appSettingsProvider);
    
    if (settings.groqApiKey == null || settings.groqApiKey!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure API key first')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Testing connection...'),
          ],
        ),
      ),
    );

    final aiService = AiService();
    aiService.setApiKey(settings.groqApiKey!);
    aiService.setModel(settings.aiModel);
    aiService.setSystemPrompt(settings.aiSystemPrompt);

    final success = await aiService.testConnection();

    if (context.mounted) {
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'AI connection successful!' : 'AI connection failed. Check your API key.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showReplyDelayDialog(
    BuildContext context,
    WidgetRef ref,
    int currentDelay,
  ) {
    int tempDelay = currentDelay;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reply Delay'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Delay: $tempDelay seconds'),
              const SizedBox(height: 16),
              Slider(
                value: tempDelay.toDouble(),
                min: 0,
                max: 60,
                divisions: 60,
                label: '$tempDelay seconds',
                onChanged: (value) {
                  setDialogState(() {
                    tempDelay = value.toInt();
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
                    .updateReplyDelay(tempDelay);
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
