import 'package:hive/hive.dart';

import '../utils/cloud_ai_model.dart';

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

  @HiveField(12)
  String aiSystemPrompt;

  @HiveField(13)
  String aiModelType;

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

  @HiveField(25)
  bool contactWhitelistEnabled;

  @HiveField(26)
  List<String> contactWhitelist;

  @HiveField(27)
  List<String> contactBlacklist;

  @HiveField(28)
  bool busyModeEnabled;

  @HiveField(29)
  String busyReplyText;

  @HiveField(30)
  int busyUntilTimestamp;

  @HiveField(31)
  String gemmaLocalServerUrl;

  @HiveField(32)
  String gemmaLocalModel;

  @HiveField(33)
  String selectedLocalModel;

  @HiveField(34)
  String cerebrasApiKey;

  @HiveField(35)
  String cerebrasModel;

  @HiveField(37)
  String groqApiKey;

  @HiveField(38)
  String groqModel;

  @HiveField(39)
  String geminiApiKey;

  @HiveField(40)
  String geminiModel;

  @HiveField(36)
  List<String> trainingExamplesRaw;

  /// Daily reply limits per AI engine (0 = unlimited)
  @HiveField(41)
  int cerebrasReplyLimit;

  @HiveField(42)
  int groqReplyLimit;

  @HiveField(43)
  int geminiReplyLimit;

  @HiveField(44)
  int localReplyLimit;

  @HiveField(45)
  bool fallbackToLocalModel;

  AppSettings({
    this.masterEnabled = true,
    this.whatsappEnabled = true,
    this.instagramEnabled = true,
    this.minReplyDelaySeconds = 1,
    this.maxReplyDelaySeconds = 10,
    this.preventDuplicateReplies = true,
    this.ignoreGroupChats = true,
    this.darkMode = false,
    this.aiReplyEnabled = false,
    this.aiSystemPrompt = 'You are a friendly assistant. Reply naturally and helpfully to the message. Keep replies short and conversational.',
    this.aiModelType = 'cerebras_api',
    this.scheduleEnabled = false,
    this.scheduleStartHour = 8,
    this.scheduleStartMinute = 0,
    this.scheduleEndHour = 22,
    this.scheduleEndMinute = 0,
    this.confirmBeforeReply = false,
    this.contactWhitelistEnabled = false,
    this.contactWhitelist = const [],
    this.contactBlacklist = const [],
    this.busyModeEnabled = false,
    this.busyReplyText = '',
    this.busyUntilTimestamp = 0,
    this.gemmaLocalServerUrl = '',
    this.gemmaLocalModel = 'llama_3_2_1b',
    this.selectedLocalModel = 'llama_3_2_1b',
    this.cerebrasApiKey = '',
    this.cerebrasModel = 'llama-3.3-70b',
    this.groqApiKey = '',
    this.groqModel = 'openai/gpt-oss-20b',
    this.geminiApiKey = '',
    this.geminiModel = 'gemini-3.6-flash',
    this.trainingExamplesRaw = const [],
    this.cerebrasReplyLimit = 0,
    this.groqReplyLimit = 0,
    this.geminiReplyLimit = 0,
    this.localReplyLimit = 0,
    this.fallbackToLocalModel = true,
    required this.lastUpdated,
  });

  /// Get parsed training examples as List of maps
  List<Map<String, String>> get trainingExamples {
    return trainingExamplesRaw.map((e) {
      final parts = e.split(':::');
      return {
        'id': parts.isNotEmpty ? parts[0] : '',
        'userMessage': parts.length > 1 ? parts[1] : '',
        'correctedReply': parts.length > 2 ? parts[2] : '',
      };
    }).toList();
  }

  /// Format training examples into few-shot prompt for AI system instructions
  String formatTrainingPrompt() {
    final examples = trainingExamples;
    if (examples.isEmpty) return '';

    final sb = StringBuffer('\n\n--- LEARNED RESPONSE PATTERNS (CRITICAL) ---\n');
    sb.writeln('When replying, follow these exact examples of how the user expects replies to look:');
    for (final ex in examples) {
      sb.writeln('Incoming: "${ex['userMessage']}" -> Reply: "${ex['correctedReply']}"');
    }
    sb.writeln('Adopt this tone and concise style strictly.');
    return sb.toString();
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
      'aiSystemPrompt': aiSystemPrompt,
      'scheduleEnabled': scheduleEnabled,
      'scheduleStartHour': scheduleStartHour,
      'scheduleStartMinute': scheduleStartMinute,
      'scheduleEndHour': scheduleEndHour,
      'scheduleEndMinute': scheduleEndMinute,
      'confirmBeforeReply': confirmBeforeReply,
      'contactWhitelistEnabled': contactWhitelistEnabled,
      'contactWhitelist': contactWhitelist,
      'contactBlacklist': contactBlacklist,
      'busyModeEnabled': busyModeEnabled,
      'busyReplyText': busyReplyText,
      'busyUntilTimestamp': busyUntilTimestamp,
      'gemmaLocalServerUrl': gemmaLocalServerUrl,
      'gemmaLocalModel': gemmaLocalModel,
      'selectedLocalModel': selectedLocalModel,
      'cerebrasApiKey': cerebrasApiKey,
      'cerebrasModel': cerebrasModel,
      'groqApiKey': groqApiKey,
      'groqModel': groqModel,
      'geminiApiKey': geminiApiKey,
      'geminiModel': geminiModel,
      'trainingExamplesRaw': trainingExamplesRaw,
      'cerebrasReplyLimit': cerebrasReplyLimit,
      'groqReplyLimit': groqReplyLimit,
      'geminiReplyLimit': geminiReplyLimit,
      'localReplyLimit': localReplyLimit,
      'fallbackToLocalModel': fallbackToLocalModel,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// Create from JSON
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      masterEnabled: json['masterEnabled'] ?? true,
      whatsappEnabled: json['whatsappEnabled'] ?? true,
      instagramEnabled: json['instagramEnabled'] ?? true,
      minReplyDelaySeconds: json['minReplyDelaySeconds'] ?? json['replyDelaySeconds'] ?? 1,
      maxReplyDelaySeconds: json['maxReplyDelaySeconds'] ?? json['replyDelaySeconds'] ?? 10,
      preventDuplicateReplies: json['preventDuplicateReplies'] ?? true,
      ignoreGroupChats: json['ignoreGroupChats'] ?? true,
      darkMode: json['darkMode'] ?? false,
      aiReplyEnabled: json['aiReplyEnabled'] ?? false,
      aiModelType: (json['aiModelType'] as String?) ?? 'cerebras_api',
      aiSystemPrompt: json['aiSystemPrompt'] ?? 'You are a friendly assistant. Reply naturally and helpfully to the message. Keep replies short and conversational.',
      scheduleEnabled: json['scheduleEnabled'] ?? false,
      scheduleStartHour: json['scheduleStartHour'] ?? 8,
      scheduleStartMinute: json['scheduleStartMinute'] ?? 0,
      scheduleEndHour: json['scheduleEndHour'] ?? 22,
      scheduleEndMinute: json['scheduleEndMinute'] ?? 0,
      confirmBeforeReply: json['confirmBeforeReply'] ?? false,
      contactWhitelistEnabled: json['contactWhitelistEnabled'] ?? false,
      contactWhitelist: (json['contactWhitelist'] as List?)?.cast<String>() ?? [],
      contactBlacklist: (json['contactBlacklist'] as List?)?.cast<String>() ?? [],
      busyModeEnabled: json['busyModeEnabled'] ?? false,
      busyReplyText: json['busyReplyText'] ?? '',
      busyUntilTimestamp: json['busyUntilTimestamp'] ?? 0,
      gemmaLocalServerUrl: (json['gemmaLocalServerUrl'] as String?) ?? '',
      gemmaLocalModel: (json['gemmaLocalModel'] as String?) ?? 'llama_3_2_1b',
      selectedLocalModel: (json['selectedLocalModel'] as String?) ?? 'llama_3_2_1b',
      cerebrasApiKey: (json['cerebrasApiKey'] as String?) ?? '',
      cerebrasModel: (json['cerebrasModel'] as String?) ?? 'llama-3.3-70b',
      groqApiKey: (json['groqApiKey'] as String?) ?? '',
      groqModel: CloudAiModel.normalizeGroqModel(json['groqModel'] as String?),
      geminiApiKey: (json['geminiApiKey'] as String?) ?? '',
      geminiModel: CloudAiModel.normalizeGeminiModel(json['geminiModel'] as String?),
      trainingExamplesRaw: (json['trainingExamplesRaw'] as List?)?.cast<String>() ?? [],
      cerebrasReplyLimit: (json['cerebrasReplyLimit'] as num?)?.toInt() ?? 0,
      groqReplyLimit: (json['groqReplyLimit'] as num?)?.toInt() ?? 0,
      geminiReplyLimit: (json['geminiReplyLimit'] as num?)?.toInt() ?? 0,
      localReplyLimit: (json['localReplyLimit'] as num?)?.toInt() ?? 0,
      fallbackToLocalModel: json['fallbackToLocalModel'] ?? true,
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
    String? aiSystemPrompt,
    bool? scheduleEnabled,
    int? scheduleStartHour,
    int? scheduleStartMinute,
    int? scheduleEndHour,
    int? scheduleEndMinute,
    bool? confirmBeforeReply,
    bool? contactWhitelistEnabled,
    List<String>? contactWhitelist,
    List<String>? contactBlacklist,
    bool? busyModeEnabled,
    String? busyReplyText,
    int? busyUntilTimestamp,
    String? gemmaLocalServerUrl,
    String? gemmaLocalModel,
    String? selectedLocalModel,
    String? cerebrasApiKey,
    String? cerebrasModel,
    String? groqApiKey,
    String? groqModel,
    String? geminiApiKey,
    String? geminiModel,
    List<String>? trainingExamplesRaw,
    int? cerebrasReplyLimit,
    int? groqReplyLimit,
    int? geminiReplyLimit,
    int? localReplyLimit,
    bool? fallbackToLocalModel,
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
      aiSystemPrompt: aiSystemPrompt ?? this.aiSystemPrompt,
      scheduleEnabled: scheduleEnabled ?? this.scheduleEnabled,
      scheduleStartHour: scheduleStartHour ?? this.scheduleStartHour,
      scheduleStartMinute: scheduleStartMinute ?? this.scheduleStartMinute,
      scheduleEndHour: scheduleEndHour ?? this.scheduleEndHour,
      scheduleEndMinute: scheduleEndMinute ?? this.scheduleEndMinute,
      confirmBeforeReply: confirmBeforeReply ?? this.confirmBeforeReply,
      contactWhitelistEnabled: contactWhitelistEnabled ?? this.contactWhitelistEnabled,
      contactWhitelist: contactWhitelist ?? this.contactWhitelist,
      contactBlacklist: contactBlacklist ?? this.contactBlacklist,
      busyModeEnabled: busyModeEnabled ?? this.busyModeEnabled,
      busyReplyText: busyReplyText ?? this.busyReplyText,
      busyUntilTimestamp: busyUntilTimestamp ?? this.busyUntilTimestamp,
      gemmaLocalServerUrl: gemmaLocalServerUrl ?? this.gemmaLocalServerUrl,
      gemmaLocalModel: gemmaLocalModel ?? this.gemmaLocalModel,
      selectedLocalModel: selectedLocalModel ?? this.selectedLocalModel,
      cerebrasApiKey: cerebrasApiKey ?? this.cerebrasApiKey,
      cerebrasModel: cerebrasModel ?? this.cerebrasModel,
      groqApiKey: groqApiKey ?? this.groqApiKey,
      groqModel: groqModel ?? this.groqModel,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      geminiModel: geminiModel ?? this.geminiModel,
      trainingExamplesRaw: trainingExamplesRaw ?? this.trainingExamplesRaw,
      cerebrasReplyLimit: cerebrasReplyLimit ?? this.cerebrasReplyLimit,
      groqReplyLimit: groqReplyLimit ?? this.groqReplyLimit,
      geminiReplyLimit: geminiReplyLimit ?? this.geminiReplyLimit,
      localReplyLimit: localReplyLimit ?? this.localReplyLimit,
      fallbackToLocalModel: fallbackToLocalModel ?? this.fallbackToLocalModel,
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
