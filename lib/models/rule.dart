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

  @HiveField(10)
  bool isAiPowered;

  /// Multiple trigger texts — the rule fires if ANY of these match.
  /// Falls back to [triggerText] when this list is empty (migration path).
  @HiveField(9)
  List<String> triggerTexts;

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
    this.isAiPowered = false,
  }) : triggerTexts = triggerTexts ?? [];

  /// All active trigger texts: uses [triggerTexts] when populated,
  /// otherwise falls back to the legacy [triggerText].
  List<String> get effectiveTriggers =>
      triggerTexts.isNotEmpty ? triggerTexts : [triggerText];

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
      'exactMatch': exactMatch,
      'containsMatch': containsMatch,
      'caseSensitive': caseSensitive,
      'isEnabled': isEnabled,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isAiPowered': isAiPowered,
    };
  }

  /// Create from JSON
  factory Rule.fromJson(Map<String, dynamic> json) {
    final rawList = json['triggerTexts'];
    final List<String> triggers = rawList is List
        ? rawList.map((e) => e.toString()).toList()
        : <String>[];
    return Rule(
      id: json['id'],
      triggerText: json['triggerText'] ?? '',
      replyText: json['replyText'],
      exactMatch: json['exactMatch'] ?? false,
      containsMatch: json['containsMatch'] ?? true,
      caseSensitive: json['caseSensitive'] ?? false,
      isEnabled: json['isEnabled'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      triggerTexts: triggers,
      isAiPowered: json['isAiPowered'] ?? false,
    );
  }

  /// Create a copy with updated fields
  Rule copyWith({
    String? id,
    String? triggerText,
    List<String>? triggerTexts,
    String? replyText,
    bool? exactMatch,
    bool? containsMatch,
    bool? caseSensitive,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAiPowered,
  }) {
    return Rule(
      id: id ?? this.id,
      triggerText: triggerText ?? this.triggerText,
      triggerTexts: triggerTexts ?? List.from(this.triggerTexts),
      replyText: replyText ?? this.replyText,
      exactMatch: exactMatch ?? this.exactMatch,
      containsMatch: containsMatch ?? this.containsMatch,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isAiPowered: isAiPowered ?? this.isAiPowered,
    );
  }
}
