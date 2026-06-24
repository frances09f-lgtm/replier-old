import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/rule.dart';
import '../providers/rule_provider.dart';

/// Screen for adding or editing a rule.
/// Supports multiple trigger texts that all map to one reply text.
class AddEditRuleScreen extends ConsumerStatefulWidget {
  final Rule? rule;

  const AddEditRuleScreen({super.key, this.rule});

  @override
  ConsumerState<AddEditRuleScreen> createState() => _AddEditRuleScreenState();
}

class _AddEditRuleScreenState extends ConsumerState<AddEditRuleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _replyController = TextEditingController();

  /// Each trigger has its own controller.
  final List<TextEditingController> _triggerControllers = [];

  bool _exactMatch = false;
  bool _containsMatch = true;
  bool _caseSensitive = false;
  bool _isEnabled = true;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _replyController.text = rule?.replyText ?? '';
    _exactMatch = rule?.exactMatch ?? false;
    _containsMatch = rule?.containsMatch ?? true;
    _caseSensitive = rule?.caseSensitive ?? false;
    _isEnabled = rule?.isEnabled ?? true;

    // Populate trigger controllers from existing rule
    final triggers = rule?.effectiveTriggers ?? [];
    if (triggers.isEmpty) {
      _triggerControllers.add(TextEditingController());
    } else {
      for (final t in triggers) {
        _triggerControllers.add(TextEditingController(text: t));
      }
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    for (final c in _triggerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addTrigger() {
    setState(() {
      _triggerControllers.add(TextEditingController());
    });
  }

  void _removeTrigger(int index) {
    if (_triggerControllers.length == 1) return; // keep at least one
    setState(() {
      _triggerControllers[index].dispose();
      _triggerControllers.removeAt(index);
    });
  }

  void _saveRule() {
    if (_formKey.currentState!.validate()) {
      _saveRuleAsync();
    }
  }

  Future<void> _saveRuleAsync() async {
    final ruleNotifier = ref.read(rulesProvider.notifier);
    final triggers = _triggerControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    // Use first trigger as legacy triggerText, full list in triggerTexts
    final primaryTrigger = triggers.isNotEmpty ? triggers.first : '';

    if (widget.rule != null) {
      final updatedRule = widget.rule!.copyWith(
        triggerText: primaryTrigger,
        triggerTexts: triggers,
        replyText: _replyController.text.trim(),
        exactMatch: _exactMatch,
        containsMatch: _containsMatch,
        caseSensitive: _caseSensitive,
        isEnabled: _isEnabled,
      );
      await ruleNotifier.updateRule(updatedRule);
    } else {
      final newRule = ruleNotifier.createRule(
        triggerText: primaryTrigger,
        triggerTexts: triggers,
        replyText: _replyController.text.trim(),
        exactMatch: _exactMatch,
        containsMatch: _containsMatch,
        caseSensitive: _caseSensitive,
        isEnabled: _isEnabled,
      );
      await ruleNotifier.addRule(newRule);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.rule != null;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Rule' : 'Add Rule'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Trigger texts section ─────────────────────────────────────
            Row(
              children: [
                Text(
                  'Trigger Texts',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addTrigger,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'The rule fires when any of these match the incoming message.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 12),

            ...List.generate(_triggerControllers.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _triggerControllers[i],
                        decoration: InputDecoration(
                          labelText: 'Trigger ${i + 1}',
                          hintText: 'e.g., hi',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.text_fields, size: 18),
                        ),
                        validator: (value) {
                          // Only the first trigger is required
                          if (i == 0 &&
                              (value == null || value.trim().isEmpty)) {
                            return 'Enter at least one trigger text';
                          }
                          return null;
                        },
                      ),
                    ),
                    if (_triggerControllers.length > 1) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _removeTrigger(i),
                        icon: Icon(Icons.remove_circle_outline,
                            color: colorScheme.error),
                        tooltip: 'Remove trigger',
                      ),
                    ],
                  ],
                ),
              );
            }),

            const Divider(height: 32),

            // ── Reply text ────────────────────────────────────────────────
            Text(
              'Reply Text',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _replyController,
              decoration: const InputDecoration(
                labelText: 'Reply Text',
                hintText: 'e.g., Hey! I\'ll get back to you soon.',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.reply, size: 18),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter reply text';
                }
                return null;
              },
            ),

            const Divider(height: 32),

            // ── Match options ─────────────────────────────────────────────
            Text(
              'Match Options',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),

            SwitchListTile(
              title: const Text('Exact Match'),
              subtitle: const Text('Message must exactly match a trigger'),
              value: _exactMatch,
              onChanged: (value) {
                setState(() {
                  _exactMatch = value;
                  if (value) _containsMatch = false;
                });
              },
            ),

            SwitchListTile(
              title: const Text('Contains Match'),
              subtitle: const Text('Message must contain a trigger'),
              value: _containsMatch,
              onChanged: (value) {
                setState(() {
                  _containsMatch = value;
                  if (value) _exactMatch = false;
                });
              },
            ),

            SwitchListTile(
              title: const Text('Case Sensitive'),
              subtitle: const Text('Match case exactly'),
              value: _caseSensitive,
              onChanged: (value) {
                setState(() {
                  _caseSensitive = value;
                });
              },
            ),

            const Divider(height: 32),

            SwitchListTile(
              title: const Text('Enable Rule'),
              subtitle: const Text('Rule will be active when enabled'),
              value: _isEnabled,
              onChanged: (value) {
                setState(() {
                  _isEnabled = value;
                });
              },
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _saveRule,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(isEditing ? 'Update Rule' : 'Add Rule'),
            ),
          ],
        ),
      ),
    );
  }
}
