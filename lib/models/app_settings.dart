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
    this.aiModelType = 'phi_local',
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
      aiModelType: (json['aiModelType'] as String?) ?? 'phi_local',
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
