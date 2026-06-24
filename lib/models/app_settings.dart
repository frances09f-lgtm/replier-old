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

  AppSettings({
    this.masterEnabled = true,
    this.whatsappEnabled = true,
    this.instagramEnabled = true,
    this.minReplyDelaySeconds = 0,
    this.maxReplyDelaySeconds = 10,
    this.preventDuplicateReplies = true,
    this.ignoreGroupChats = true,
    this.darkMode = false,
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
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
