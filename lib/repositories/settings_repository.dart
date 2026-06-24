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

  /// Toggle dark mode
  Future<void> toggleDarkMode() async {
    final settings = getSettings();
    final updatedSettings = settings.copyWith(
      darkMode: !settings.darkMode,
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
