import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
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
            title: 'Post Notifications',
            subtitle: 'Required to show confirmation alerts',
            isGranted: permissions['postNotification'] ?? false,
            onGrant: () => ref
                .read(permissionStatusProvider.notifier)
                .requestPostNotificationPermission(),
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

          SwitchListTile(
            title: const Text('Confirm Before Reply'),
            subtitle: const Text('Ask before sending each reply'),
            value: settings.confirmBeforeReply,
            onChanged: (_) {
              ref.read(appSettingsProvider.notifier).toggleConfirmBeforeReply();
            },
          ),

          const SizedBox(height: 24),

          // Schedule section
          Text(
            'Schedule',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Set time windows when auto-reply is active',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),

          SwitchListTile(
            title: const Text('Enable Schedule'),
            subtitle: const Text('Auto-reply only during set hours'),
            value: settings.scheduleEnabled,
            onChanged: (_) {
              ref.read(appSettingsProvider.notifier).updateSchedule(
                enabled: !settings.scheduleEnabled,
                startHour: settings.scheduleStartHour,
                startMinute: settings.scheduleStartMinute,
                endHour: settings.scheduleEndHour,
                endMinute: settings.scheduleEndMinute,
              );
            },
          ),

          if (settings.scheduleEnabled) ...[
            ListTile(
              title: const Text('Start Time'),
              subtitle: Text(_formatTime(settings.scheduleStartHour, settings.scheduleStartMinute)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showTimePickerDialog(
                context, ref, settings, isStart: true,
              ),
            ),
            ListTile(
              title: const Text('End Time'),
              subtitle: Text(_formatTime(settings.scheduleEndHour, settings.scheduleEndMinute)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showTimePickerDialog(
                context, ref, settings, isStart: false,
              ),
            ),
          ],

          // Busy mode indicator
          if (settings.busyModeEnabled && settings.busyUntilTimestamp > DateTime.now().millisecondsSinceEpoch) ...[
            Card(
              color: Colors.blue[50],
              child: ListTile(
                leading: Icon(Icons.timer, color: Colors.blue[700]),
                title: const Text('Busy Mode Active', style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text('"${settings.busyReplyText}" until ${_formatBusyUntil(settings.busyUntilTimestamp)}'),
                trailing: IconButton(
                  icon: Icon(Icons.cancel, color: Colors.red[400]),
                  onPressed: () => ref.read(appSettingsProvider.notifier).clearBusyMode(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 24),
          Text(
            'AI Auto-Reply',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            settings.aiModelType == 'smart_reply'
                ? 'Uses on-device ML Kit Smart Reply (no API key, no internet needed)'
                : settings.aiModelType == 'gemma_local'
                    ? 'Uses on-device Gemma 3 270M LLM (fully offline, download model on first use)'
                    : settings.aiModelType == 'gemini'
                        ? 'Uses Google Gemini (1,500 req/day free) to generate replies when no rule matches'
                        : settings.aiModelType == 'cerebras'
                            ? 'Uses Cerebras (ultra-fast inference) to generate replies when no rule matches'
                            : 'Uses Groq (free) to generate replies when no rule matches',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),

          SwitchListTile(
            title: const Text('AI Auto-Reply'),
            subtitle: const Text('Reply with AI when no rule matches'),
            value: settings.aiReplyEnabled,
            onChanged: (_) {
              ref.read(appSettingsProvider.notifier).toggleAiReplyEnabled();
            },
          ),

            if (settings.aiReplyEnabled) ...[
              // Model type selector
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AI Model', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Radio<String>(
                        value: 'smart_reply',
                        groupValue: settings.aiModelType,
                        onChanged: (v) {
                          ref.read(appSettingsProvider.notifier).updateAiModelType(v!);
                        },
                      ),
                      title: const Text('Smart Reply (On-Device)'),
                      subtitle: const Text('No API key, works offline, on-device AI'),
                      onTap: () => ref.read(appSettingsProvider.notifier).updateAiModelType('smart_reply'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Radio<String>(
                        value: 'gemma_local',
                        groupValue: settings.aiModelType,
                        onChanged: (v) {
                          ref.read(appSettingsProvider.notifier).updateAiModelType(v!);
                        },
                      ),
                      title: const Text('Gemma 3 270M (On-Device)'),
                      subtitle: const Text('No API key, fully offline, runs on device'),
                      onTap: () => ref.read(appSettingsProvider.notifier).updateAiModelType('gemma_local'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Radio<String>(
                        value: 'groq',
                        groupValue: settings.aiModelType,
                        onChanged: (v) {
                          ref.read(appSettingsProvider.notifier).updateAiModelType(v!);
                        },
                      ),
                      title: const Text('Groq API (Cloud)'),
                      subtitle: const Text('Requires API key, rate limits apply'),
                      onTap: () => ref.read(appSettingsProvider.notifier).updateAiModelType('groq'),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Radio<String>(
                      value: 'gemini',
                      groupValue: settings.aiModelType,
                      onChanged: (v) {
                        ref.read(appSettingsProvider.notifier).updateAiModelType(v!);
                      },
                    ),
                    title: const Text('Google Gemini'),
                    subtitle: const Text('1,500 req/day free, 1M context'),
                    onTap: () => ref.read(appSettingsProvider.notifier).updateAiModelType('gemini'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Radio<String>(
                      value: 'cerebras',
                      groupValue: settings.aiModelType,
                      onChanged: (v) {
                        ref.read(appSettingsProvider.notifier).updateAiModelType(v!);
                      },
                    ),
                    title: const Text('Cerebras API (Cloud)'),
                    subtitle: const Text('Ultra-fast inference, free tier'),
                    onTap: () => ref.read(appSettingsProvider.notifier).updateAiModelType('cerebras'),
                  ),
                ],
              ),
            ),

            if (settings.aiModelType == 'groq') ...[
              ListTile(
                title: const Text('Groq API Key'),
                subtitle: Text(
                  settings.groqApiKey.isEmpty
                      ? 'Not set (get free key at console.groq.com)'
                      : '${settings.groqApiKey.substring(0, 8)}...',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showApiKeyDialog(context, ref, settings.groqApiKey),
              ),
            ],

            if (settings.aiModelType == 'gemini') ...[
              _buildGeminiKeysSection(context, ref, settings),
            ],

            if (settings.aiModelType == 'cerebras') ...[
              ListTile(
                title: const Text('Cerebras API Key'),
                subtitle: Text(
                  settings.cerebrasApiKey.isEmpty
                      ? 'Not set (get free key at cloud.cerebras.ai)'
                      : '${settings.cerebrasApiKey.substring(0, 8)}...',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showCerebrasApiKeyDialog(context, ref, settings.cerebrasApiKey),
              ),
            ],

            if (settings.aiModelType == 'gemma_local') ...[
              const _GemmaLocalModelTile(),
            ],

            if (settings.aiModelType != 'smart_reply')
              ListTile(
                title: const Text('System Prompt'),
                subtitle: Text(
                  settings.aiSystemPrompt.length > 50
                      ? '${settings.aiSystemPrompt.substring(0, 50)}...'
                      : settings.aiSystemPrompt,
                ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showSystemPromptDialog(context, ref, settings.aiSystemPrompt),
            ),
          ],

          const SizedBox(height: 24),

          // Contact Filtering section
          Text(
            'Contact Filtering',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _buildContactWhitelistSection(context, ref, settings),
          const SizedBox(height: 8),
          _buildContactBlacklistSection(context, ref, settings),

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

  String _formatBusyUntil(int timestampMillis) {
    final remaining = Duration(milliseconds: timestampMillis - DateTime.now().millisecondsSinceEpoch);
    if (remaining.isNegative) return 'expired';
    if (remaining.inDays > 0) return '${remaining.inDays}d ${remaining.inHours % 24}h remaining';
    if (remaining.inHours > 0) return '${remaining.inHours}h ${remaining.inMinutes % 60}m remaining';
    return '${remaining.inMinutes}m remaining';
  }

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  void _showTimePickerDialog(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings, {
    required bool isStart,
  }) async {
    final initialHour = isStart ? settings.scheduleStartHour : settings.scheduleEndHour;
    final initialMinute = isStart ? settings.scheduleStartMinute : settings.scheduleEndMinute;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );

    if (picked != null) {
      ref.read(appSettingsProvider.notifier).updateSchedule(
        enabled: settings.scheduleEnabled,
        startHour: isStart ? picked.hour : settings.scheduleStartHour,
        startMinute: isStart ? picked.minute : settings.scheduleStartMinute,
        endHour: isStart ? settings.scheduleEndHour : picked.hour,
        endMinute: isStart ? settings.scheduleEndMinute : picked.minute,
      );
    }
  }

  void _showReplyDelayDialog(
    BuildContext context,
    WidgetRef ref,
    int currentMin,
    int currentMax,
  ) {
    final minController = TextEditingController(text: currentMin.toString());
    final maxController = TextEditingController(text: currentMax.toString());
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
              TextField(
                controller: minController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimum delay (seconds)',
                  border: OutlineInputBorder(),
                  suffixText: 's',
                ),
                onChanged: (value) {
                  final parsed = int.tryParse(value) ?? 0;
                  setDialogState(() {
                    tempMin = parsed.clamp(0, 300);
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: maxController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Maximum delay (seconds)',
                  border: OutlineInputBorder(),
                  suffixText: 's',
                ),
                onChanged: (value) {
                  final parsed = int.tryParse(value) ?? 0;
                  setDialogState(() {
                    tempMax = parsed.clamp(0, 300);
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
                final min = tempMin <= tempMax ? tempMin : tempMax;
                final max = tempMin <= tempMax ? tempMax : tempMin;
                ref
                    .read(appSettingsProvider.notifier)
                    .updateReplyDelayRange(min, max);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  void _showApiKeyDialog(BuildContext context, WidgetRef ref, String currentKey) {
    final controller = TextEditingController(text: currentKey);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Groq API Key'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'gsk_...',
            labelText: 'API Key',
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final key = controller.text.trim();
              if (key.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter an API key first')),
                );
                return;
              }
              Navigator.pop(context);
              await _testApiKey(context, key);
            },
            child: const Text('Test'),
          ),
          TextButton(
            onPressed: () {
              ref.read(appSettingsProvider.notifier).updateGroqApiKey(controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _testApiKey(BuildContext context, String apiKey) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      );
      request.headers.set('Authorization', 'Bearer $apiKey');
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {'role': 'user', 'content': 'Say "API test successful" in exactly 3 words.'}
        ],
        'max_tokens': 20,
      }));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      if (context.mounted) Navigator.pop(context); // dismiss loading

      if (response.statusCode == 200) {
        final json = jsonDecode(body);
        final reply = json['choices'][0]['message']['content'].trim();
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
              title: const Text('API Working!'),
              content: Text('AI replied: "$reply"'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        final error = jsonDecode(body);
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              icon: const Icon(Icons.error, color: Colors.red, size: 48),
              title: const Text('API Error'),
              content: Text('Status ${response.statusCode}: ${error['error']['message'] ?? 'Unknown error'}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // dismiss loading
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            icon: const Icon(Icons.error, color: Colors.red, size: 48),
            title: const Text('Connection Failed'),
            content: Text('Could not reach Groq API:\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildContactWhitelistSection(BuildContext context, WidgetRef ref, AppSettings settings) {
    final contacts = settings.contactWhitelist;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('Contact Whitelist'),
          subtitle: const Text('Only reply to these contacts when enabled'),
          value: settings.contactWhitelistEnabled,
          onChanged: (_) {
            ref.read(appSettingsProvider.notifier).toggleContactWhitelist();
          },
        ),
        if (settings.contactWhitelistEnabled) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    contacts.isEmpty
                        ? 'No contacts added — all messages will be blocked'
                        : '${contacts.length} contact${contacts.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  onPressed: () => _showContactListDialog(
                    context, ref, contacts, 'Whitelist',
                    (list) => ref.read(appSettingsProvider.notifier).updateContactWhitelist(list),
                    (c) => ref.read(appSettingsProvider.notifier).addToWhitelist(c),
                    (c) => ref.read(appSettingsProvider.notifier).removeFromWhitelist(c),
                  ),
                ),
              ],
            ),
          ),
          if (contacts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: contacts.map((name) {
                  return Chip(
                    label: Text(name, style: const TextStyle(fontSize: 12)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      ref.read(appSettingsProvider.notifier).removeFromWhitelist(name);
                    },
                  );
                }).toList(),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildContactBlacklistSection(BuildContext context, WidgetRef ref, AppSettings settings) {
    final contacts = settings.contactBlacklist;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Blacklisted Contacts',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                onPressed: () => _showContactListDialog(
                  context, ref, contacts, 'Blacklist',
                  (list) => ref.read(appSettingsProvider.notifier).updateContactBlacklist(list),
                  (c) => ref.read(appSettingsProvider.notifier).addToBlacklist(c),
                  (c) => ref.read(appSettingsProvider.notifier).removeFromBlacklist(c),
                ),
              ),
            ],
          ),
        ),
        if (contacts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: contacts.map((name) {
                return Chip(
                  label: Text(name, style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    ref.read(appSettingsProvider.notifier).removeFromBlacklist(name);
                  },
                );
              }).toList(),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'No blacklisted contacts',
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Blacklisted contacts will never receive auto-replies. '
            'Whitelist takes priority when enabled.',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  void _showContactListDialog(
    BuildContext context,
    WidgetRef ref,
    List<String> initialList,
    String label,
    void Function(List<String>) onSave,
    void Function(String) onAdd,
    void Function(String) onRemove,
  ) {
    final contacts = List<String>.from(initialList);
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('$label Contacts'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (contacts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Add contact names exactly as they appear in notifications.',
                      style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person, size: 20),
                        title: Text(contact, style: const TextStyle(fontSize: 13)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () {
                            contacts.removeAt(index);
                            setDialogState(() {});
                          },
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: 'Contact name',
                          labelText: 'Add contact',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () {
                        final name = controller.text.trim();
                        if (name.isNotEmpty && !contacts.any((c) => c.toLowerCase() == name.toLowerCase())) {
                          contacts.add(name);
                          controller.clear();
                          setDialogState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                onSave(contacts);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeminiKeysSection(BuildContext context, WidgetRef ref, AppSettings settings) {
    final keys = settings.geminiApiKeys;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: const Text('Gemini API Keys'),
          subtitle: Text(
            keys.isEmpty
                ? 'No keys set (get free key at aistudio.google.com)'
                : '${keys.length} key${keys.length == 1 ? '' : 's'} configured',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showGeminiKeysDialog(context, ref, settings),
        ),
        if (keys.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: keys.map((key) {
                final display = key.length > 12 ? '${key.substring(0, 8)}...${key.substring(key.length - 4)}' : key;
                return Chip(
                  label: Text(display, style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    ref.read(appSettingsProvider.notifier).removeGeminiApiKey(key);
                  },
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  void _showGeminiKeysDialog(BuildContext context, WidgetRef ref, AppSettings settings) {
    final keys = List<String>.from(settings.geminiApiKeys);
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Gemini API Keys'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (keys.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Add multiple keys to increase your rate limit.\nEach key gives 15 requests/min free.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: keys.length,
                    itemBuilder: (context, index) {
                      final key = keys[index];
                      final display = key.length > 20
                          ? '${key.substring(0, 12)}...${key.substring(key.length - 6)}'
                          : key;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.key, size: 20),
                        title: Text(display, style: const TextStyle(fontSize: 13)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () {
                            keys.removeAt(index);
                            setDialogState(() {});
                          },
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: 'AIza...',
                          labelText: 'New API Key',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () {
                        final key = controller.text.trim();
                        if (key.isNotEmpty && !keys.contains(key)) {
                          keys.add(key);
                          controller.clear();
                          setDialogState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Get free keys'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Go to https://aistudio.google.com/apikey')),
                );
              },
            ),
            TextButton(
              onPressed: () {
                ref.read(appSettingsProvider.notifier).updateGeminiApiKeys(keys);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCerebrasApiKeyDialog(BuildContext context, WidgetRef ref, String currentKey) {
    final controller = TextEditingController(text: currentKey);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerebras API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'csk-...',
                labelText: 'API Key',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Get free key at cloud.cerebras.ai'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Go to https://cloud.cerebras.ai to create a free key')),
                );
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
            onPressed: () async {
              final key = controller.text.trim();
              if (key.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter an API key first')),
                );
                return;
              }
              Navigator.pop(context);
              await _testCerebrasApiKey(context, key);
            },
            child: const Text('Test'),
          ),
          TextButton(
            onPressed: () {
              ref.read(appSettingsProvider.notifier).updateCerebrasApiKey(controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _testCerebrasApiKey(BuildContext context, String apiKey) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('https://api.cerebras.ai/v1/chat/completions'),
      );
      request.headers.set('Authorization', 'Bearer $apiKey');
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode({
        'model': 'gpt-oss-120b',
        'messages': [
          {'role': 'user', 'content': 'Say "API test successful" in exactly 3 words.'}
        ],
        'max_tokens': 20,
      }));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      if (context.mounted) Navigator.pop(context); // dismiss loading

      if (response.statusCode == 200) {
        final json = jsonDecode(body);
        final reply = json['choices'][0]['message']['content'].trim();
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
              title: const Text('API Working!'),
              content: Text('AI replied: "$reply"'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        final error = jsonDecode(body);
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              icon: const Icon(Icons.error, color: Colors.red, size: 48),
              title: const Text('API Error'),
              content: Text('Status ${response.statusCode}: ${error['error']['message'] ?? 'Unknown error'}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // dismiss loading
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            icon: const Icon(Icons.error, color: Colors.red, size: 48),
            title: const Text('Connection Failed'),
            content: Text('Could not reach Cerebras API:\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showSystemPromptDialog(BuildContext context, WidgetRef ref, String currentPrompt) {
    final controller = TextEditingController(text: currentPrompt);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI System Prompt'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Instructions for how the AI should reply...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(appSettingsProvider.notifier).updateAiSystemPrompt(controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _GemmaLocalModelTile extends StatefulWidget {
  const _GemmaLocalModelTile();

  @override
  State<_GemmaLocalModelTile> createState() => _GemmaLocalModelTileState();
}

class _GemmaLocalModelTileState extends State<_GemmaLocalModelTile> {
  bool _modelAvailable = false;
  bool _downloading = false;
  int _downloadProgress = 0;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      const channel = MethodChannel('com.example.auto_reply_assistant/native');
      final result = await channel.invokeMethod<Map>('getGemmaLocalStatus');
      if (result != null && mounted) {
        setState(() {
          _modelAvailable = result['available'] == true;
          _checking = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _downloadModel() async {
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
    });

    try {
      const channel = MethodChannel('com.example.auto_reply_assistant/native');

      // Listen for progress updates
      channel.setMethodCallHandler((call) async {
        if (call.method == 'onDownloadProgress') {
          final progress = call.arguments as int;
          if (mounted) setState(() => _downloadProgress = progress);
        }
      });

      await channel.invokeMethod('downloadGemmaLocalModel');
      await _checkStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }

    if (mounted) setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              _checking ? Icons.hourglass_empty :
              _modelAvailable ? Icons.check_circle : Icons.download,
              color: _checking ? Colors.grey :
                     _modelAvailable ? Colors.green : Colors.orange,
            ),
            title: Text(
              _checking ? 'Checking model...' :
              _modelAvailable ? 'Gemma 3 Model Ready' : 'Gemma 3 Model Not Installed',
            ),
            subtitle: Text(
              _downloading
                  ? 'Downloading... $_downloadProgress%'
                  : _modelAvailable
                      ? '~165MB GGUF — runs fully offline on device'
                      : 'Tap download to get the model (~165MB)',
            ),
          ),
          if (_downloading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: _downloadProgress / 100.0,
                    backgroundColor: Colors.grey[300],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Downloading model... $_downloadProgress% — Do not close the app',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          if (!_downloading && !_modelAvailable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Runs Gemma 3 270M directly on your phone. No server, no API key, no internet needed after download.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _downloadModel,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Download Model (~165MB)'),
                    ),
                  ),
                ],
              ),
            ),
          if (!_downloading && _modelAvailable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Fully offline — no internet or server required.',
                      style: TextStyle(fontSize: 12, color: Colors.green[700]),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Model?'),
                          content: const Text('This will free ~165MB. You can re-download later.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        try {
                          const channel = MethodChannel('com.example.auto_reply_assistant/native');
                          await channel.invokeMethod('deleteGemmaLocalModel');
                          await _checkStatus();
                        } catch (_) {}
                      }
                    },
                    child: const Text('Delete', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],
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
