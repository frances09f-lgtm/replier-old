import 'dart:async';
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
            'Use on-device model, Cerebras cloud API, or Smart Hybrid (local first, API when message is hard/confusing)',
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
            // ── AI Mode selector ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  // Smart Hybrid tile
                  _AiModeTile(
                    value: 'auto_local_first',
                    groupValue: settings.aiModelType,
                    title: 'Smart Hybrid (Recommended)',
                    subtitle: 'Local model for simple messages, Cerebras API for hard/confusing ones',
                    icon: Icons.auto_awesome,
                    iconColor: Colors.deepPurple,
                    onTap: () => ref.read(appSettingsProvider.notifier).updateAiModelType('auto_local_first'),
                  ),
                  const SizedBox(height: 8),
                  // Local only tile
                  _AiModeTile(
                    value: 'phi_local',
                    groupValue: settings.aiModelType,
                    title: 'Local Model Only',
                    subtitle: 'Fully offline — no internet needed',
                    icon: Icons.phone_android,
                    iconColor: Colors.green,
                    onTap: () => ref.read(appSettingsProvider.notifier).updateAiModelType('phi_local'),
                  ),
                  const SizedBox(height: 8),
                  // Cerebras API only tile
                  _AiModeTile(
                    value: 'cerebras_api',
                    groupValue: settings.aiModelType,
                    title: 'Cerebras Cloud API Only',
                    subtitle: 'Fast cloud LLM — requires API key & internet',
                    icon: Icons.cloud,
                    iconColor: Colors.blue,
                    onTap: () => ref.read(appSettingsProvider.notifier).updateAiModelType('cerebras_api'),
                  ),
                ],
              ),
            ),

            // ── Local model picker (shown when local or hybrid mode) ───
            if (settings.aiModelType == 'phi_local' || settings.aiModelType == 'auto_local_first') ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Text('Local Model', style: TextStyle(fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(height: 4),
                    _ModelRadioTile(
                      value: 'llama_3_2_1b',
                      groupValue: settings.selectedLocalModel,
                      title: 'Llama 3.2 1B Instruct',
                      subtitle: '~800MB, blazing fast for basic replies',
                      onTap: () {
                        ref.read(appSettingsProvider.notifier).updateSelectedLocalModel('llama_3_2_1b');
                      },
                      modelId: 'llama_3_2_1b',
                      selectedModelId: settings.selectedLocalModel,
                    ),
                    const SizedBox(height: 8),
                    _ModelRadioTile(
                      value: 'llama_3_2_3b',
                      groupValue: settings.selectedLocalModel,
                      title: 'Llama 3.2 3B Instruct',
                      subtitle: '~2GB, highly intelligent, fits comfortably in RAM',
                      onTap: () {
                        ref.read(appSettingsProvider.notifier).updateSelectedLocalModel('llama_3_2_3b');
                      },
                      modelId: 'llama_3_2_3b',
                      selectedModelId: settings.selectedLocalModel,
                    ),
                  ],
                ),
              ),
            ],

            // ── Cerebras API config (shown when cerebras or hybrid mode) ─
            if (settings.aiModelType == 'cerebras_api' || settings.aiModelType == 'auto_local_first') ...[
              _CerebrasApiSection(settings: settings, ref: ref),
            ],

            // ── System Prompt ─────────────────────────────────────────
            ListTile(
              contentPadding: EdgeInsets.zero,
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
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB), // Amber-50
              borderRadius: BorderRadius.circular(16),
              border: const Border(
                left: BorderSide(color: Color(0xFFF59E0B), width: 4),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Important Notice',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Automated replying to WhatsApp or Instagram may violate their Terms of Service. '
                  'This app uses official Android notification APIs where possible. '
                  'Use at your own risk and with caution.',
                  style: TextStyle(color: Color(0xFFB45309), fontSize: 12, height: 1.4),
                ),
              ],
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

/// Simple card tile for AI mode selection (local / cerebras / hybrid)
class _AiModeTile extends StatelessWidget {
  final String value;
  final String groupValue;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _AiModeTile({
    required this.value,
    required this.groupValue,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return Card(
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? iconColor : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: isSelected ? iconColor.withOpacity(0.15) : Colors.grey.shade100,
          child: Icon(icon, color: isSelected ? iconColor : Colors.grey, size: 20),
        ),
        title: Text(title,
            style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Radio<String>(
          value: value,
          groupValue: groupValue,
          onChanged: (_) => onTap(),
          activeColor: iconColor,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Cerebras API key configuration section shown in settings
class _CerebrasApiSection extends StatefulWidget {
  final AppSettings settings;
  final WidgetRef ref;

  const _CerebrasApiSection({required this.settings, required this.ref});

  @override
  State<_CerebrasApiSection> createState() => _CerebrasApiSectionState();
}

class _CerebrasApiSectionState extends State<_CerebrasApiSection> {
  late TextEditingController _keyController;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.settings.cerebrasApiKey);
  }

  @override
  void didUpdateWidget(_CerebrasApiSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.cerebrasApiKey != widget.settings.cerebrasApiKey) {
      _keyController.text = widget.settings.cerebrasApiKey;
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  void _saveKey() {
    widget.ref.read(appSettingsProvider.notifier).updateCerebrasConfig(
      _keyController.text.trim(),
      widget.settings.cerebrasModel,
    );
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cerebras API key saved'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = widget.settings.cerebrasApiKey.isNotEmpty;
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('Cerebras API Key',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                if (hasKey)
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
              ],
            ),
            const SizedBox(height: 4),
            // API key link
            InkWell(
              onTap: () async {
                const url = 'https://cloud.cerebras.ai/';
                try {
                  await const MethodChannel('com.example.auto_reply_assistant/native')
                      .invokeMethod('openUrl', {'url': url});
                } catch (_) {
                  await Clipboard.setData(const ClipboardData(text: url));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied: https://cloud.cerebras.ai/'),
                        duration: Duration(seconds: 4),
                      ),
                    );
                  }
                }
              },
              child: const Text(
                '🔗 Get free API key → cloud.cerebras.ai',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // API key text field
            TextField(
              controller: _keyController,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'csk-...',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    IconButton(
                      icon: const Icon(Icons.save, size: 20, color: Colors.blue),
                      onPressed: _saveKey,
                      tooltip: 'Save',
                    ),
                  ],
                ),
              ),
              onSubmitted: (_) => _saveKey(),
            ),
            const SizedBox(height: 8),
            // Model selector
            DropdownButtonFormField<String>(
              value: widget.settings.cerebrasModel,
              decoration: const InputDecoration(
                labelText: 'Cerebras Model',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'llama-3.3-70b', child: Text('Llama 3.3 70B (Smart)')),
                DropdownMenuItem(value: 'llama3.1-8b', child: Text('Llama 3.1 8B (Fast)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  widget.ref.read(appSettingsProvider.notifier).updateCerebrasConfig(
                    widget.settings.cerebrasApiKey,
                    val,
                  );
                }
              },
            ),
            if (!hasKey) ...[
              const SizedBox(height: 8),
              Text(
                '⚠ API key required for Cerebras Cloud replies',
                style: TextStyle(fontSize: 11, color: Colors.orange[700]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModelRadioTile extends StatefulWidget {

  final String value;
  final String groupValue;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? modelId;
  final String? selectedModelId;

  const _ModelRadioTile({
    required this.value,
    required this.groupValue,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.modelId,
    this.selectedModelId,
  });

  @override
  State<_ModelRadioTile> createState() => _ModelRadioTileState();
}

class _ModelRadioTileState extends State<_ModelRadioTile> {
  bool? _available;
  bool _downloading = false;
  int _progress = 0;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    if (widget.modelId != null) _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _checking = true);
    try {
      const channel = MethodChannel('com.example.auto_reply_assistant/native');
      final result = await channel.invokeMethod<Map>('getPhiStatus', {'modelId': widget.modelId});
      if (result != null && mounted) {
        setState(() => _available = result['available'] == true);
      }
    } catch (_) {}
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _download() async {
    setState(() { _downloading = true; _progress = 0; });
    try {
      const channel = MethodChannel('com.example.auto_reply_assistant/native');
      channel.setMethodCallHandler((call) async {
        if (call.method == 'onDownloadProgress') {
          final args = call.arguments as Map;
          if (args['modelId'] == widget.modelId && mounted) {
            setState(() => _progress = args['progress'] as int? ?? 0);
          }
        }
      });
      await channel.invokeMethod('downloadPhiModel', {'modelId': widget.modelId});
      await _checkStatus();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
    if (mounted) setState(() => _downloading = false);
  }

  Future<void> _delete() async {
    try {
      const channel = MethodChannel('com.example.auto_reply_assistant/native');
      await channel.invokeMethod('deletePhiModel', {'modelId': widget.modelId});
      await _checkStatus();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isLocalModel = widget.modelId != null;
    final isAvailable = _available ?? false;
    final isThisSelected = isLocalModel && widget.value == widget.groupValue && widget.modelId == widget.selectedModelId;

    return Card(
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: Radio<String>(
              value: widget.value,
              groupValue: widget.groupValue,
              onChanged: isLocalModel && !isAvailable ? null : (_) => widget.onTap(),
            ),
            title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(_downloading
                ? 'Downloading... $_progress%'
                : isLocalModel && !isAvailable
                    ? '${widget.subtitle} (tap download)'
                    : widget.subtitle),
            trailing: isLocalModel
                ? (_checking
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : isAvailable
                        ? Icon(Icons.check_circle, color: isThisSelected ? Colors.green : Colors.grey)
                        : const Icon(Icons.download, color: Colors.orange))
                : Icon(Icons.phone_android, color: Colors.green[700]),
            onTap: isLocalModel && !isAvailable ? null : () => widget.onTap(),
          ),
          if (_downloading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: _progress / 100.0, backgroundColor: Colors.grey[300]),
                  const SizedBox(height: 4),
                  Text('Downloading... $_progress% — Do not close the app', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
          if (!_downloading && isLocalModel && !isAvailable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _download,
                  icon: const Icon(Icons.download, size: 18),
                  label: Text('Download ${widget.title}'),
                ),
              ),
            ),
          if (!_downloading && isLocalModel && isAvailable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isThisSelected ? 'Currently active' : 'Downloaded',
                      style: TextStyle(fontSize: 12, color: isThisSelected ? Colors.green[700] : Colors.grey[600]),
                    ),
                  ),
                  if (!isThisSelected)
                    TextButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text('Delete ${widget.title}?'),
                            content: const Text('You can re-download later.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) _delete();
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
