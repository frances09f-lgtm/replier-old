import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../services/model_download_service.dart';

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

          // AI Reply section
          Text(
            'AI Auto-Reply',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            settings.aiModelType == 'local'
                ? 'Runs on-device — no API key, no limits, fully offline'
                : settings.aiModelType == 'gemini'
                    ? 'Uses Google Gemini to generate replies when no rule matches'
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
                      value: 'local',
                      groupValue: settings.aiModelType,
                      onChanged: (v) {
                        ref.read(appSettingsProvider.notifier).updateAiModelType(v!);
                      },
                    ),
                    title: const Text('Local Model (On-Device)'),
                    subtitle: const Text('No API key, no limits, fully offline'),
                    onTap: () => ref.read(appSettingsProvider.notifier).updateAiModelType('local'),
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
                    title: const Text('Google Gemini (Cloud)'),
                    subtitle: const Text('Requires API key, free tier available'),
                    onTap: () => ref.read(appSettingsProvider.notifier).updateAiModelType('gemini'),
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
              ListTile(
                title: const Text('Gemini API Key'),
                subtitle: Text(
                  settings.geminiApiKey.isEmpty
                      ? 'Not set (get free key at aistudio.google.com)'
                      : '${settings.geminiApiKey.substring(0, 8)}...',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showGeminiApiKeyDialog(context, ref, settings.geminiApiKey),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: DropdownButtonFormField<String>(
                  value: settings.geminiModel,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Gemini Model',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'gemini-2.0-flash', child: Text('Gemini 2.0 Flash (Recommended)')),
                    DropdownMenuItem(value: 'gemini-2.0-flash-lite', child: Text('Gemini 2.0 Flash Lite (Faster)')),
                    DropdownMenuItem(value: 'gemini-1.5-flash', child: Text('Gemini 1.5 Flash')),
                    DropdownMenuItem(value: 'gemini-1.5-pro', child: Text('Gemini 1.5 Pro (Higher quality)')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(appSettingsProvider.notifier).updateGeminiModel(v);
                    }
                  },
                ),
              ),
            ],

            if (settings.aiModelType == 'local') ...[
              _LocalModelSection(settings: settings, ref: ref),
            ],

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
                max: 300,
                divisions: 300,
                label: '${tempMin}s',
                onChanged: (value) {
                  setDialogState(() {
                    tempMin = value.toInt();
                  });
                },
              ),
              const SizedBox(height: 8),
              const Text('Maximum delay:'),
              Slider(
                value: tempMax.toDouble(),
                min: 0,
                max: 300,
                divisions: 300,
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

  void _showGeminiApiKeyDialog(BuildContext context, WidgetRef ref, String currentKey) {
    final controller = TextEditingController(text: currentKey);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gemini API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'AIza...',
                labelText: 'API Key',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Get free key at aistudio.google.com'),
              onPressed: () {
                // URL is shown, user can open manually
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Go to https://aistudio.google.com/apikey to create a free key')),
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
              await _testGeminiApiKey(context, key);
            },
            child: const Text('Test'),
          ),
          TextButton(
            onPressed: () {
              ref.read(appSettingsProvider.notifier).updateGeminiApiKey(controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _testGeminiApiKey(BuildContext context, String apiKey) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash:generateContent?key=$apiKey'),
      );
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': 'Say "API test successful" in exactly 3 words.'}
            ]
          }
        ],
        'generationConfig': {
          'maxOutputTokens': 20,
          'temperature': 0.7,
        },
      }));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      if (context.mounted) Navigator.pop(context); // dismiss loading

      if (response.statusCode == 200) {
        final json = jsonDecode(body);
        final reply = json['candidates'][0]['content']['parts'][0]['text'].trim();
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
            content: Text('Could not reach Gemini API:\n$e'),
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

class _LocalModelSection extends ConsumerStatefulWidget {
  final AppSettings settings;
  final WidgetRef ref;

  const _LocalModelSection({
    required this.settings,
    required this.ref,
  });

  @override
  ConsumerState<_LocalModelSection> createState() => _LocalModelSectionState();
}

class _LocalModelSectionState extends ConsumerState<_LocalModelSection> {
  double _downloadProgress = 0;
  bool _isDownloading = false;
  String? _downloadedModelPath;
  final _hfTokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _hfTokenController.text = widget.settings.hfToken;
    _checkDownloadedModel();
  }

  @override
  void dispose() {
    _hfTokenController.dispose();
    super.dispose();
  }

  Future<void> _checkDownloadedModel() async {
    final path = await ModelDownloadService.getLatestModelPath();
    if (!mounted) return;
    setState(() {
      _downloadedModelPath = path;
    });
    // Auto-fix settings if model file exists but path not saved
    if (path != null && widget.settings.localModelPath != path) {
      widget.ref.read(appSettingsProvider.notifier).updateLocalModelPath(path);
      widget.ref.read(appSettingsProvider.notifier).setLocalModelDownloaded(true);
    }
  }

  Future<void> _startDownload() async {
    final modelKey = await _showModelPicker();
    if (modelKey == null || !mounted) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    String? downloadError;
    final path = await ModelDownloadService.downloadModel(
      modelKey,
      hfToken: widget.settings.hfToken.isNotEmpty ? widget.settings.hfToken : null,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
          });
        }
      },
      onComplete: (error) {
        downloadError = error;
      },
    );

    if (!mounted) return;

    if (downloadError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $downloadError')),
      );
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0;
      });
    } else {
      setState(() {
        _isDownloading = false;
        _downloadProgress = 1.0;
      });
      _checkDownloadedModel();
      widget.ref.read(appSettingsProvider.notifier).updateLocalModelPath(path ?? '');
      widget.ref.read(appSettingsProvider.notifier).setLocalModelDownloaded(path != null);
    }
  }

  Future<String?> _showModelPicker() {
    final models = ModelDownloadService.availableModels;
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choose Model'),
        children: models.entries.map((e) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, e.key),
            child: ListTile(
              title: Text(e.key),
              subtitle: Text('${e.value['size']} — ${e.value['description']}'),
              contentPadding: EdgeInsets.zero,
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hugging Face token (optional, for download)
        TextField(
          decoration: const InputDecoration(
            labelText: 'Hugging Face Token (optional)',
            hintText: 'hf_...',
            helperText: 'Some models require auth to download',
            helperMaxLines: 2,
          ),
          obscureText: true,
          controller: _hfTokenController,
          onChanged: (v) {
            widget.ref.read(appSettingsProvider.notifier).updateHfToken(v);
          },
        ),
        const SizedBox(height: 8),
        if (_isDownloading) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: _downloadProgress),
                const SizedBox(height: 4),
                Text(
                  'Downloading model... ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
        if (_downloadedModelPath != null && !_isDownloading)
          ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: const Text('Model Downloaded'),
            subtitle: Text(_downloadedModelPath!.split('\\').last.split('/').last),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                await ModelDownloadService.deleteModel(_downloadedModelPath!);
                setState(() => _downloadedModelPath = null);
                widget.ref.read(appSettingsProvider.notifier).updateLocalModelPath('');
              },
            ),
          )
        else if (!_isDownloading)
          Card(
            child: ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download Local Model'),
              subtitle: const Text('~250-700 MB, downloaded once'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _startDownload,
            ),
          ),
      ],
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
