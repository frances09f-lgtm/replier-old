import 'dart:convert';
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

  /// Update Groq API key
  Future<void> updateGroqApiKey(String apiKey) async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(groqApiKey: apiKey);
    await updateSettings(updatedSettings);
  }

  /// Update AI model type (groq / gemini / cerebras)
  Future<void> updateAiModelType(String modelType) async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(aiModelType: modelType);
    await updateSettings(updatedSettings);
  }

  /// Update Gemini API key (single key, backward compat)
  Future<void> updateGeminiApiKey(String apiKey) async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(geminiApiKey: apiKey);
    await updateSettings(updatedSettings);
  }

  /// Replace all Gemini API keys
  Future<void> updateGeminiApiKeys(List<String> keys) async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(
      geminiApiKeysJson: jsonEncode(keys),
    );
    await updateSettings(updatedSettings);
  }

  /// Add a Gemini API key to the list
  Future<void> addGeminiApiKey(String apiKey) async {
    final settings = getSettings();
    final keys = List<String>.from(settings.geminiApiKeys);
    if (!keys.contains(apiKey)) {
      keys.add(apiKey);
      final updatedSettings = settings.copyWith(
        geminiApiKeysJson: jsonEncode(keys),
      );
      await updateSettings(updatedSettings);
    }
  }

  /// Remove a Gemini API key from the list
  Future<void> removeGeminiApiKey(String apiKey) async {
    final settings = getSettings();
    final keys = List<String>.from(settings.geminiApiKeys);
    keys.remove(apiKey);
    final updatedSettings = settings.copyWith(
      geminiApiKeysJson: jsonEncode(keys),
    );
    await updateSettings(updatedSettings);
  }

  /// Update Cerebras API key
  Future<void> updateCerebrasApiKey(String apiKey) async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(cerebrasApiKey: apiKey);
    await updateSettings(updatedSettings);
  }

  /// Update AI system prompt
  Future<void> updateAiSystemPrompt(String prompt) async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(aiSystemPrompt: prompt);
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
