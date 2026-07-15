import 'dart:convert';
import 'package:hive/hive.dart';

part 'app_settings.g.dart';

/// Model for app settings
/// Controls the behavior of the auto-reply assistant
@HiveType(typeId: 1)
class AppSettings extends HiveObject {
  @HiveField(0)
  bool masterEnabled;

  @HiveField(1)
  bool whatsappEnabled;

  @HiveField(2)
  bool instagramEnabled;

  @HiveField(3)
  int minReplyDelaySeconds;

  @HiveField(9)
  int maxReplyDelaySeconds;

  @HiveField(4)
  bool preventDuplicateReplies;

  @HiveField(5)
  bool ignoreGroupChats;

  @HiveField(6)
  bool darkMode;

  @HiveField(7)
  DateTime lastUpdated;

  @HiveField(10)
  bool aiReplyEnabled;

  @HiveField(11)
  String groqApiKey;

  @HiveField(12)
  String aiSystemPrompt;

  @HiveField(13)
  String aiModelType;

  @HiveField(16)
  String cerebrasApiKey;

  @HiveField(17)
  String geminiApiKey;

  @HiveField(23)
  String geminiApiKeysJson;

  @HiveField(18)
  bool scheduleEnabled;

  @HiveField(19)
  int scheduleStartHour;

  @HiveField(20)
  int scheduleStartMinute;

  @HiveField(21)
  int scheduleEndHour;

  @HiveField(22)
  int scheduleEndMinute;

  @HiveField(24)
  bool confirmBeforeReply;

  AppSettings({
    this.masterEnabled = true,
    this.whatsappEnabled = true,
    this.instagramEnabled = true,
    this.minReplyDelaySeconds = 0,
    this.maxReplyDelaySeconds = 10,
    this.preventDuplicateReplies = true,
    this.ignoreGroupChats = true,
    this.darkMode = false,
    this.aiReplyEnabled = false,
    this.groqApiKey = '',
    this.aiSystemPrompt = 'You are a friendly assistant. Reply naturally and helpfully to the message. Keep replies short and conversational.',
    this.aiModelType = 'groq',
    this.cerebrasApiKey = '',
    this.geminiApiKey = '',
    this.geminiApiKeysJson = '[]',
    this.scheduleEnabled = false,
    this.scheduleStartHour = 8,
    this.scheduleStartMinute = 0,
    this.scheduleEndHour = 22,
    this.scheduleEndMinute = 0,
    this.confirmBeforeReply = false,
    required this.lastUpdated,
  });

  /// Returns the list of Gemini API keys.
  /// Falls back to [geminiApiKey] if the list is empty (backward compat).
  List<String> get geminiApiKeys {
    try {
      final list = (jsonDecode(geminiApiKeysJson) as List).cast<String>();
      if (list.isNotEmpty) return list;
    } catch (_) {}
    if (geminiApiKey.isNotEmpty) return [geminiApiKey];
    return [];
  }

  /// Set the list of Gemini API keys (persists as JSON string).
  set geminiApiKeys(List<String> keys) {
    geminiApiKeysJson = jsonEncode(keys);
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'masterEnabled': masterEnabled,
      'whatsappEnabled': whatsappEnabled,
      'instagramEnabled': instagramEnabled,
      'minReplyDelaySeconds': minReplyDelaySeconds,
      'maxReplyDelaySeconds': maxReplyDelaySeconds,
      'preventDuplicateReplies': preventDuplicateReplies,
      'ignoreGroupChats': ignoreGroupChats,
      'darkMode': darkMode,
      'aiReplyEnabled': aiReplyEnabled,
      'aiModelType': aiModelType,
      'groqApiKey': groqApiKey,
      'cerebrasApiKey': cerebrasApiKey,
      'geminiApiKey': geminiApiKey,
      'geminiApiKeysJson': geminiApiKeysJson,
      'aiSystemPrompt': aiSystemPrompt,
      'scheduleEnabled': scheduleEnabled,
      'scheduleStartHour': scheduleStartHour,
      'scheduleStartMinute': scheduleStartMinute,
      'scheduleEndHour': scheduleEndHour,
      'scheduleEndMinute': scheduleEndMinute,
      'confirmBeforeReply': confirmBeforeReply,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// Create from JSON
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      masterEnabled: json['masterEnabled'] ?? true,
      whatsappEnabled: json['whatsappEnabled'] ?? true,
      instagramEnabled: json['instagramEnabled'] ?? true,
      minReplyDelaySeconds: json['minReplyDelaySeconds'] ?? json['replyDelaySeconds'] ?? 0,
      maxReplyDelaySeconds: json['maxReplyDelaySeconds'] ?? json['replyDelaySeconds'] ?? 10,
      preventDuplicateReplies: json['preventDuplicateReplies'] ?? true,
      ignoreGroupChats: json['ignoreGroupChats'] ?? true,
      darkMode: json['darkMode'] ?? false,
      aiReplyEnabled: json['aiReplyEnabled'] ?? false,
      aiModelType: (json['aiModelType'] as String?) ?? 'groq',
      groqApiKey: json['groqApiKey'] ?? '',
      cerebrasApiKey: (json['cerebrasApiKey'] as String?) ?? '',
      geminiApiKey: (json['geminiApiKey'] as String?) ?? '',
      geminiApiKeysJson: (json['geminiApiKeysJson'] as String?) ?? '[]',
      aiSystemPrompt: json['aiSystemPrompt'] ?? 'You are a friendly assistant. Reply naturally and helpfully to the message. Keep replies short and conversational.',
      scheduleEnabled: json['scheduleEnabled'] ?? false,
      scheduleStartHour: json['scheduleStartHour'] ?? 8,
      scheduleStartMinute: json['scheduleStartMinute'] ?? 0,
      scheduleEndHour: json['scheduleEndHour'] ?? 22,
      scheduleEndMinute: json['scheduleEndMinute'] ?? 0,
      confirmBeforeReply: json['confirmBeforeReply'] ?? false,
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }

  /// Create a copy with updated fields
  AppSettings copyWith({
    bool? masterEnabled,
    bool? whatsappEnabled,
    bool? instagramEnabled,
    int? minReplyDelaySeconds,
    int? maxReplyDelaySeconds,
    bool? preventDuplicateReplies,
    bool? ignoreGroupChats,
    bool? darkMode,
    bool? aiReplyEnabled,
    String? aiModelType,
    String? groqApiKey,
    String? cerebrasApiKey,
    String? geminiApiKey,
    String? geminiApiKeysJson,
    String? aiSystemPrompt,
    bool? scheduleEnabled,
    int? scheduleStartHour,
    int? scheduleStartMinute,
    int? scheduleEndHour,
    int? scheduleEndMinute,
    bool? confirmBeforeReply,
    DateTime? lastUpdated,
  }) {
    return AppSettings(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      whatsappEnabled: whatsappEnabled ?? this.whatsappEnabled,
      instagramEnabled: instagramEnabled ?? this.instagramEnabled,
      minReplyDelaySeconds: minReplyDelaySeconds ?? this.minReplyDelaySeconds,
      maxReplyDelaySeconds: maxReplyDelaySeconds ?? this.maxReplyDelaySeconds,
      preventDuplicateReplies: preventDuplicateReplies ?? this.preventDuplicateReplies,
      ignoreGroupChats: ignoreGroupChats ?? this.ignoreGroupChats,
      darkMode: darkMode ?? this.darkMode,
      aiReplyEnabled: aiReplyEnabled ?? this.aiReplyEnabled,
      aiModelType: aiModelType ?? this.aiModelType,
      groqApiKey: groqApiKey ?? this.groqApiKey,
      cerebrasApiKey: cerebrasApiKey ?? this.cerebrasApiKey,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      geminiApiKeysJson: geminiApiKeysJson ?? this.geminiApiKeysJson,
      aiSystemPrompt: aiSystemPrompt ?? this.aiSystemPrompt,
      scheduleEnabled: scheduleEnabled ?? this.scheduleEnabled,
      scheduleStartHour: scheduleStartHour ?? this.scheduleStartHour,
      scheduleStartMinute: scheduleStartMinute ?? this.scheduleStartMinute,
      scheduleEndHour: scheduleEndHour ?? this.scheduleEndHour,
      scheduleEndMinute: scheduleEndMinute ?? this.scheduleEndMinute,
      confirmBeforeReply: confirmBeforeReply ?? this.confirmBeforeReply,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Check if the current time is within the schedule window.
  /// Supports overnight windows (e.g., 10 PM to 6 AM).
  bool isWithinSchedule() {
    if (!scheduleEnabled) return true;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = scheduleStartHour * 60 + scheduleStartMinute;
    final endMinutes = scheduleEndHour * 60 + scheduleEndMinute;

    if (startMinutes <= endMinutes) {
      // Same-day window (e.g., 8:00 - 22:00)
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // Overnight window (e.g., 22:00 - 6:00)
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }
}
