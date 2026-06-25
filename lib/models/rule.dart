import 'package:hive/hive.dart';

part 'rule.g.dart';

/// Model for auto-reply rules
/// Each rule defines when and how to automatically reply to messages
@HiveType(typeId: 0)
class Rule extends HiveObject {
  @HiveField(0)
  String id;

  /// Legacy single trigger — kept for Hive backward compatibility.
  /// Use [triggerTexts] for all new logic.
  @HiveField(1)
  String triggerText;

  @HiveField(2)
  String replyText;

  @HiveField(3)
  bool exactMatch;

  @HiveField(4)
  bool containsMatch;

  @HiveField(5)
  bool caseSensitive;

  @HiveField(6)
  bool isEnabled;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  DateTime updatedAt;

  /// Multiple trigger texts — the rule fires if ANY of these match.
  /// Falls back to [triggerText] when this list is empty (migration path).
  @HiveField(9)
  List<String> triggerTexts;

  /// Multiple reply texts — one is randomly selected when the rule fires.
  /// Falls back to [replyText] when this list is empty (migration path).
  @HiveField(10)
  List<String> replies;

  Rule({
    required this.id,
    required this.triggerText,
    required this.replyText,
    this.exactMatch = false,
    this.containsMatch = true,
    this.caseSensitive = false,
    this.isEnabled = true,
    required this.createdAt,
    required this.updatedAt,
    List<String>? triggerTexts,
    List<String>? replies,
  })  : triggerTexts = triggerTexts ?? [],
        replies = replies ?? [];

  /// All active trigger texts: uses [triggerTexts] when populated,
  /// otherwise falls back to the legacy [triggerText].
  List<String> get effectiveTriggers =>
      triggerTexts.isNotEmpty ? triggerTexts : [triggerText];

  /// All active reply texts: uses [replies] when populated,
  /// otherwise falls back to the legacy [replyText].
  List<String> get effectiveReplies =>
      replies.isNotEmpty ? replies : [replyText];

  /// Check if a message matches this rule
  bool matches(String message) {
    if (!isEnabled) return false;
    final msg = caseSensitive ? message : message.toLowerCase();
    return effectiveTriggers.any((t) {
      final trigger = caseSensitive ? t : t.toLowerCase();
      if (exactMatch) return msg.trim() == trigger.trim();
      if (containsMatch) return msg.contains(trigger);
      return false;
    });
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'triggerText': triggerText,
      'triggerTexts': triggerTexts,
      'replyText': replyText,
      'replies': replies,
      'exactMatch': exactMatch,
      'containsMatch': containsMatch,
      'caseSensitive': caseSensitive,
      'isEnabled': isEnabled,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory Rule.fromJson(Map<String, dynamic> json) {
    final rawTriggers = json['triggerTexts'];
    final List<String> triggers = rawTriggers is List
        ? rawTriggers.map((e) => e.toString()).toList()
        : <String>[];
    final rawReplies = json['replies'];
    final List<String> replyList = rawReplies is List
        ? rawReplies.map((e) => e.toString()).toList()
        : <String>[];
    return Rule(
      id: json['id'],
      triggerText: json['triggerText'] ?? '',
      replyText: json['replyText'] ?? '',
      replies: replyList,
      exactMatch: json['exactMatch'] ?? false,
      containsMatch: json['containsMatch'] ?? true,
      caseSensitive: json['caseSensitive'] ?? false,
      isEnabled: json['isEnabled'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      triggerTexts: triggers,
    );
  }

  /// Create a copy with updated fields
  Rule copyWith({
    String? id,
    String? triggerText,
    List<String>? triggerTexts,
    String? replyText,
    List<String>? replies,
    bool? exactMatch,
    bool? containsMatch,
    bool? caseSensitive,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Rule(
      id: id ?? this.id,
      triggerText: triggerText ?? this.triggerText,
      triggerTexts: triggerTexts ?? List.from(this.triggerTexts),
      replyText: replyText ?? this.replyText,
      replies: replies ?? List.from(this.replies),
      exactMatch: exactMatch ?? this.exactMatch,
      containsMatch: containsMatch ?? this.containsMatch,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
