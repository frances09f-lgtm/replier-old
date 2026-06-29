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

  @HiveField(14)
  String localModelPath;

  @HiveField(15)
  bool localModelDownloaded;

  @HiveField(16)
  String hfToken;

  @HiveField(17)
  String geminiApiKey;

  @HiveField(18)
  String geminiModel;

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
    this.localModelPath = '',
    this.localModelDownloaded = false,
    this.hfToken = '',
    this.geminiApiKey = '',
    this.geminiModel = 'gemini-2.0-flash',
    required this.lastUpdated,
  });

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
      'localModelPath': localModelPath,
      'localModelDownloaded': localModelDownloaded,
      'hfToken': hfToken,
      'geminiApiKey': geminiApiKey,
      'geminiModel': geminiModel,
      'aiSystemPrompt': aiSystemPrompt,
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
      localModelPath: json['localModelPath'] ?? '',
      localModelDownloaded: json['localModelDownloaded'] ?? false,
      hfToken: (json['hfToken'] as String?) ?? '',
      geminiApiKey: (json['geminiApiKey'] as String?) ?? '',
      geminiModel: (json['geminiModel'] as String?) ?? 'gemini-2.0-flash',
      aiSystemPrompt: json['aiSystemPrompt'] ?? 'You are a friendly assistant. Reply naturally and helpfully to the message. Keep replies short and conversational.',
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
    String? localModelPath,
    bool? localModelDownloaded,
    String? hfToken,
    String? geminiApiKey,
    String? geminiModel,
    String? aiSystemPrompt,
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
      localModelPath: localModelPath ?? this.localModelPath,
      localModelDownloaded: localModelDownloaded ?? this.localModelDownloaded,
      hfToken: hfToken ?? this.hfToken,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      geminiModel: geminiModel ?? this.geminiModel,
      aiSystemPrompt: aiSystemPrompt ?? this.aiSystemPrompt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
