import 'package:injectable/injectable.dart';
import '../core/hive_config.dart';
import '../core/constants.dart';
import '../models/app_settings.dart';

/// Repository for managing app settings
@injectable
class SettingsRepository {
  /// Get app settings
  AppSettings getSettings() {
    final box = HiveConfig.getSettingsBox();
    if (box.isEmpty) {
      // Create default settings
      final defaultSettings = AppSettings(
        masterEnabled: true,
        whatsappEnabled: true,
        instagramEnabled: true,
        minReplyDelaySeconds: AppConstants.defaultMinReplyDelay,
        maxReplyDelaySeconds: AppConstants.defaultMaxReplyDelay,
        preventDuplicateReplies: AppConstants.defaultPreventDuplicateReplies,
        ignoreGroupChats: AppConstants.defaultIgnoreGroupChats,
        darkMode: false,
        lastUpdated: DateTime.now(),
      );
      box.put('settings', defaultSettings);
      return defaultSettings;
    }
    return box.get('settings')!;
  }

  /// Update app settings
  Future<void> updateSettings(AppSettings settings) async {
    final box = HiveConfig.getSettingsBox();
    final updatedSettings = settings.copyWith(
      lastUpdated: DateTime.now(),
    );
    await box.put('settings', updatedSettings);
  }

  /// Toggle master enabled
  Future<void> toggleMasterEnabled() async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(
      masterEnabled: !settings.masterEnabled,
    );
    await updateSettings(updatedSettings);
  }

  /// Toggle WhatsApp enabled
  Future<void> toggleWhatsappEnabled() async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(
      whatsappEnabled: !settings.whatsappEnabled,
    );
    await updateSettings(updatedSettings);
  }

  /// Toggle Instagram enabled
  Future<void> toggleInstagramEnabled() async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(
      instagramEnabled: !settings.instagramEnabled,
    );
    await updateSettings(updatedSettings);
  }

  /// Update reply delay range
  Future<void> updateReplyDelayRange(int minSeconds, int maxSeconds) async {
    final settings = getSettings();
    final clampedMin = minSeconds.clamp(0, AppConstants.maxReplyDelay);
    final clampedMax = maxSeconds.clamp(clampedMin, AppConstants.maxReplyDelay);
    final updatedSettings = settings.copyWith(
      minReplyDelaySeconds: clampedMin,
      maxReplyDelaySeconds: clampedMax,
    );
    await updateSettings(updatedSettings);
  }

  /// Toggle prevent duplicate replies
  Future<void> togglePreventDuplicateReplies() async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(
      preventDuplicateReplies: !settings.preventDuplicateReplies,
    );
    await updateSettings(updatedSettings);
  }

  /// Toggle ignore group chats
  Future<void> toggleIgnoreGroupChats() async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(
      ignoreGroupChats: !settings.ignoreGroupChats,
    );
    await updateSettings(updatedSettings);
  }

  /// Toggle confirm before reply
  Future<void> toggleConfirmBeforeReply() async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(
      confirmBeforeReply: !settings.confirmBeforeReply,
    );
    await updateSettings(updatedSettings);
  }

  /// Toggle dark mode
  Future<void> toggleDarkMode() async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(
      darkMode: !settings.darkMode,
    );
    await updateSettings(updatedSettings);
  }

  /// Toggle AI reply enabled
  Future<void> toggleAiReplyEnabled() async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(
      aiReplyEnabled: !settings.aiReplyEnabled,
    );
    await updateSettings(updatedSettings);
  }

  /// Update AI model type (deepseek_local)
  Future<void> updateAiModelType(String modelType) async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(aiModelType: modelType);
    await updateSettings(updatedSettings);
  }

  /// Update AI system prompt
  Future<void> updateAiSystemPrompt(String prompt) async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(aiSystemPrompt: prompt);
    await updateSettings(updatedSettings);
  }

  /// Update DeepSeek server config
  Future<void> updateDeepSeekConfig(String serverUrl, String model) async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(
      gemmaLocalServerUrl: serverUrl,
      gemmaLocalModel: model,
    );
    await updateSettings(updatedSettings);
  }

  /// Update selected local model ID
  Future<void> updateSelectedLocalModel(String modelId) async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(selectedLocalModel: modelId);
    await updateSettings(updatedSettings);
  }

  /// Update Cerebras API configuration
  Future<void> updateCerebrasConfig(String apiKey, String model) async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(
      cerebrasApiKey: apiKey,
      cerebrasModel: model,
    );
    await updateSettings(updatedSettings);
  }

  /// Update schedule settings
  Future<void> updateSchedule({
    required bool enabled,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
  }) async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(
      scheduleEnabled: enabled,
      scheduleStartHour: startHour,
      scheduleStartMinute: startMinute,
      scheduleEndHour: endHour,
      scheduleEndMinute: endMinute,
    );
    await updateSettings(updatedSettings);
  }

  /// Toggle contact whitelist enabled
  Future<void> toggleContactWhitelist() async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(
      contactWhitelistEnabled: !settings.contactWhitelistEnabled,
    );
    await updateSettings(updatedSettings);
  }

  /// Update the entire contact whitelist
  Future<void> updateContactWhitelist(List<String> contacts) async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(contactWhitelist: contacts);
    await updateSettings(updatedSettings);
  }

  /// Add a contact to the whitelist
  Future<void> addToWhitelist(String contact) async {
    final settings = getSettings();
    final list = List<String>.from(settings.contactWhitelist);
    if (!list.any((c) => c.toLowerCase() == contact.toLowerCase())) {
      list.add(contact);
      final updatedSettings = settings.copyWith(contactWhitelist: list);
      await updateSettings(updatedSettings);
    }
  }

  /// Remove a contact from the whitelist
  Future<void> removeFromWhitelist(String contact) async {
    final settings = getSettings();
    final list = List<String>.from(settings.contactWhitelist);
    list.removeWhere((c) => c.toLowerCase() == contact.toLowerCase());
    final updatedSettings = settings.copyWith(contactWhitelist: list);
    await updateSettings(updatedSettings);
  }

  /// Update the entire contact blacklist
  Future<void> updateContactBlacklist(List<String> contacts) async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(contactBlacklist: contacts);
    await updateSettings(updatedSettings);
  }

  /// Add a contact to the blacklist
  Future<void> addToBlacklist(String contact) async {
    final settings = getSettings();
    final list = List<String>.from(settings.contactBlacklist);
    if (!list.any((c) => c.toLowerCase() == contact.toLowerCase())) {
      list.add(contact);
      final updatedSettings = settings.copyWith(contactBlacklist: list);
      await updateSettings(updatedSettings);
    }
  }

  /// Remove a contact from the blacklist
  Future<void> removeFromBlacklist(String contact) async {
    final settings = getSettings();
    final list = List<String>.from(settings.contactBlacklist);
    list.removeWhere((c) => c.toLowerCase() == contact.toLowerCase());
    final updatedSettings = settings.copyWith(contactBlacklist: list);
    await updateSettings(updatedSettings);
  }

  /// Check if a contact is blacklisted
  bool isContactBlacklisted(String contact) {
    final settings = getSettings();
    return settings.contactBlacklist
        .any((c) => c.toLowerCase() == contact.toLowerCase());
  }

  /// Check if a contact is whitelisted
  bool isContactWhitelisted(String contact) {
    final settings = getSettings();
    return settings.contactWhitelist
        .any((c) => c.toLowerCase() == contact.toLowerCase());
  }

  /// Update busy mode settings
  Future<void> updateBusyMode(String replyText, int untilTimestamp) async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(
      busyModeEnabled: true,
      busyReplyText: replyText,
      busyUntilTimestamp: untilTimestamp,
    );
    await updateSettings(updatedSettings);
  }

  /// Clear busy mode
  Future<void> clearBusyMode() async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(
      busyModeEnabled: false,
      busyReplyText: '',
      busyUntilTimestamp: 0,
    );
    await updateSettings(updatedSettings);
  }

  /// Check if busy mode is active (enabled and not expired)
  bool isBusyModeActive() {
    final settings = getSettings();
    if (!settings.busyModeEnabled) return false;
    if (settings.busyUntilTimestamp <= 0) return true;
    return DateTime.now().millisecondsSinceEpoch < settings.busyUntilTimestamp;
  }

  /// Check if app is enabled for a specific package
  bool isAppEnabled(String packageName) {
    final settings = getSettings();
    if (!settings.masterEnabled) return false;

    switch (packageName) {
      case AppConstants.whatsappPackage:
        return settings.whatsappEnabled;
      case AppConstants.instagramPackage:
        return settings.instagramEnabled;
      default:
        return false;
    }
  }
}
