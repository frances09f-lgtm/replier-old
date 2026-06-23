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
  int replyDelaySeconds;

  @HiveField(4)
  bool preventDuplicateReplies;

  @HiveField(5)
  bool ignoreGroupChats;

  @HiveField(6)
  bool darkMode;

  @HiveField(7)
  DateTime lastUpdated;

  @HiveField(8)
  bool aiEnabled;

  @HiveField(9)
  String? groqApiKey;

  @HiveField(10)
  String aiModel;

  @HiveField(11)
  String aiSystemPrompt;

  AppSettings({
    this.masterEnabled = true,
    this.whatsappEnabled = true,
    this.instagramEnabled = true,
    this.replyDelaySeconds = 0,
    this.preventDuplicateReplies = true,
    this.ignoreGroupChats = false,
    this.darkMode = false,
    required this.lastUpdated,
    this.aiEnabled = false,
    this.groqApiKey,
    this.aiModel = 'llama-3.1-8b-instant',
    this.aiSystemPrompt = 'You are a helpful auto-reply assistant. Keep responses brief, friendly, and conversational. Respond as if you are the person receiving the message.',
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'masterEnabled': masterEnabled,
      'whatsappEnabled': whatsappEnabled,
      'instagramEnabled': instagramEnabled,
      'replyDelaySeconds': replyDelaySeconds,
      'preventDuplicateReplies': preventDuplicateReplies,
      'ignoreGroupChats': ignoreGroupChats,
      'darkMode': darkMode,
      'lastUpdated': lastUpdated.toIso8601String(),
      'aiEnabled': aiEnabled,
      'groqApiKey': groqApiKey,
      'aiModel': aiModel,
      'aiSystemPrompt': aiSystemPrompt,
    };
  }

  /// Create from JSON
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      masterEnabled: json['masterEnabled'] ?? true,
      whatsappEnabled: json['whatsappEnabled'] ?? true,
      instagramEnabled: json['instagramEnabled'] ?? true,
      replyDelaySeconds: json['replyDelaySeconds'] ?? 0,
      preventDuplicateReplies: json['preventDuplicateReplies'] ?? true,
      ignoreGroupChats: json['ignoreGroupChats'] ?? false,
      darkMode: json['darkMode'] ?? false,
      lastUpdated: DateTime.parse(json['lastUpdated']),
      aiEnabled: json['aiEnabled'] ?? false,
      groqApiKey: json['groqApiKey'],
      aiModel: json['aiModel'] ?? 'llama-3.1-8b-instant',
      aiSystemPrompt: json['aiSystemPrompt'] ?? 'You are a helpful auto-reply assistant. Keep responses brief, friendly, and conversational. Respond as if you are the person receiving the message.',
    );
  }

  /// Create a copy with updated fields
  AppSettings copyWith({
    bool? masterEnabled,
    bool? whatsappEnabled,
    bool? instagramEnabled,
    int? replyDelaySeconds,
    bool? preventDuplicateReplies,
    bool? ignoreGroupChats,
    bool? darkMode,
    DateTime? lastUpdated,
    bool? aiEnabled,
    String? groqApiKey,
    String? aiModel,
    String? aiSystemPrompt,
  }) {
    return AppSettings(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      whatsappEnabled: whatsappEnabled ?? this.whatsappEnabled,
      instagramEnabled: instagramEnabled ?? this.instagramEnabled,
      replyDelaySeconds: replyDelaySeconds ?? this.replyDelaySeconds,
      preventDuplicateReplies: preventDuplicateReplies ?? this.preventDuplicateReplies,
      ignoreGroupChats: ignoreGroupChats ?? this.ignoreGroupChats,
      darkMode: darkMode ?? this.darkMode,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      groqApiKey: groqApiKey ?? this.groqApiKey,
      aiModel: aiModel ?? this.aiModel,
      aiSystemPrompt: aiSystemPrompt ?? this.aiSystemPrompt,
    );
  }
}
