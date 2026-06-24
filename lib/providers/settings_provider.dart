import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../repositories/settings_repository.dart';
import '../services/native_sync_service.dart';
import '../services/notification_service.dart';

/// Provider for settings repository
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

/// Provider for notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final _nativeSyncProvider = Provider<NativeSyncService>((ref) {
  return NativeSyncService();
});

/// Provider for app settings
final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  final repository = ref.watch(settingsRepositoryProvider);
  final syncService = ref.watch(_nativeSyncProvider);
  return AppSettingsNotifier(repository, syncService);
});

/// Notifier for app settings
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsRepository _repository;
  final NativeSyncService _syncService;

  AppSettingsNotifier(this._repository, this._syncService)
      : super(_repository.getSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    state = _repository.getSettings();
    await _syncService.syncSettings(state);
  }

  Future<void> _updateAndSync(AppSettings settings) async {
    await _repository.updateSettings(settings);
    state = settings;
    await _syncService.syncSettings(settings);
  }

  Future<void> updateSettings(AppSettings settings) => _updateAndSync(settings);

  Future<void> toggleMasterEnabled() async {
    await _repository.toggleMasterEnabled();
    final s = _repository.getSettings();
    state = s;
    await _syncService.syncSettings(s);
  }

  Future<void> toggleWhatsappEnabled() async {
    await _repository.toggleWhatsappEnabled();
    final s = _repository.getSettings();
    state = s;
    await _syncService.syncSettings(s);
  }

  Future<void> toggleInstagramEnabled() async {
    await _repository.toggleInstagramEnabled();
    final s = _repository.getSettings();
    state = s;
    await _syncService.syncSettings(s);
  }

  Future<void> updateReplyDelayRange(int minSeconds, int maxSeconds) async {
    await _repository.updateReplyDelayRange(minSeconds, maxSeconds);
    final s = _repository.getSettings();
    state = s;
    await _syncService.syncSettings(s);
  }

  Future<void> togglePreventDuplicateReplies() async {
    await _repository.togglePreventDuplicateReplies();
    final s = _repository.getSettings();
    state = s;
    await _syncService.syncSettings(s);
  }

  Future<void> toggleIgnoreGroupChats() async {
    await _repository.toggleIgnoreGroupChats();
    final s = _repository.getSettings();
    state = s;
    await _syncService.syncSettings(s);
  }

  Future<void> toggleDarkMode() async {
    await _repository.toggleDarkMode();
    final s = _repository.getSettings();
    state = s;
    // Dark mode is UI-only — no need to sync to native
  }

  Future<void> toggleAiReplyEnabled() async {
    await _repository.toggleAiReplyEnabled();
    final s = _repository.getSettings();
    state = s;
    await _syncService.syncSettings(s);
  }

  Future<void> updateGroqApiKey(String apiKey) async {
    await _repository.updateGroqApiKey(apiKey);
    final s = _repository.getSettings();
    state = s;
    await _syncService.syncSettings(s);
  }

  Future<void> updateAiSystemPrompt(String prompt) async {
    await _repository.updateAiSystemPrompt(prompt);
    final s = _repository.getSettings();
    state = s;
    await _syncService.syncSettings(s);
  }
}

/// Provider for permission status
final permissionStatusProvider =
    StateNotifierProvider<PermissionStatusNotifier, Map<String, bool>>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  return PermissionStatusNotifier(notificationService);
});

/// Notifier for permission status
class PermissionStatusNotifier extends StateNotifier<Map<String, bool>> {
  final NotificationService _notificationService;

  PermissionStatusNotifier(this._notificationService)
      : super({
          'notificationListener': false,
          'accessibilityService': false,
          'batteryOptimization': false,
        }) {
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final notificationListener =
        await _notificationService.isNotificationListenerEnabled();
    final accessibilityService =
        await _notificationService.isAccessibilityServiceEnabled();
    final batteryOptimization =
        await _notificationService.isBatteryOptimizationDisabled();

    state = {
      'notificationListener': notificationListener,
      'accessibilityService': accessibilityService,
      'batteryOptimization': batteryOptimization,
    };
  }

  Future<void> refreshPermissions() async {
    await _checkPermissions();
  }

  Future<void> openNotificationListenerSettings() async {
    await _notificationService.openNotificationListenerSettings();
    await Future.delayed(const Duration(seconds: 2));
    await refreshPermissions();
  }

  Future<void> openAccessibilitySettings() async {
    await _notificationService.openAccessibilitySettings();
    await Future.delayed(const Duration(seconds: 2));
    await refreshPermissions();
  }

  Future<void> openBatteryOptimizationSettings() async {
    await _notificationService.openBatteryOptimizationSettings();
    await Future.delayed(const Duration(seconds: 2));
    await refreshPermissions();
  }
}
