import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/reply_log.dart';
import '../providers/log_provider.dart';

/// Screen for viewing reply logs
class LogsScreen extends ConsumerWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(filteredLogsProvider);
    final appFilter = ref.watch(appFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reply Logs'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              ref.read(appFilterProvider.notifier).state = value == 'all' ? null : value;
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('All Apps'),
              ),
              const PopupMenuItem(
                value: 'WhatsApp',
                child: Text('WhatsApp'),
              ),
              const PopupMenuItem(
                value: 'Instagram',
                child: Text('Instagram'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _clearLogs(context, ref, appFilter),
          ),
        ],
      ),
      body: logs.isEmpty
          ? _EmptyLogsView()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                return _LogCard(log: log);
              },
            ),
    );
  }

  void _clearLogs(BuildContext context, WidgetRef ref, String? appFilter) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: Text(appFilter == null
            ? 'Are you sure you want to clear all logs?'
            : 'Are you sure you want to clear logs for $appFilter?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (appFilter == null) {
                ref.read(logsProvider.notifier).clearLogs();
              } else {
                ref.read(logsProvider.notifier).clearLogsByApp(appFilter);
              }
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _EmptyLogsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No logs yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Auto-reply history will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final ReplyLog log;

  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getAppIcon(log.appName),
                  size: 20,
                  color: _getAppColor(log.appName),
                ),
                const SizedBox(width: 8),
                Text(
                  log.appName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM dd, HH:mm').format(log.dateTime),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    log.sender,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.message, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    log.originalMessage,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      log.autoReplySent,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.green[900],
                      ),
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

  IconData _getAppIcon(String appName) {
    switch (appName) {
      case 'WhatsApp':
        return Icons.chat;
      case 'Instagram':
        return Icons.camera_alt;
      default:
        return Icons.apps;
    }
  }

  Color _getAppColor(String appName) {
    switch (appName) {
      case 'WhatsApp':
        return Colors.green;
      case 'Instagram':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }
}
