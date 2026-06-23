/// App constants
class AppConstants {
  // App info
  static const String appName = 'Auto Reply Assistant';
  static const String appVersion = '1.0.0';

  // Hive box names
  static const String rulesBox = 'rules';
  static const String settingsBox = 'settings';
  static const String logsBox = 'logs';

  // Method channel names
  static const String nativeChannel = 'com.example.auto_reply_assistant/native';
  static const String notificationChannel = 'com.example.auto_reply_assistant/notification';
  static const String accessibilityChannel = 'com.example.auto_reply_assistant/accessibility';

  // Supported apps
  static const String whatsappPackage = 'com.whatsapp';
  static const String instagramPackage = 'com.instagram.android';

  // Default settings
  static const int defaultReplyDelay = 0;
  static const int maxReplyDelay = 60;
  static const bool defaultPreventDuplicateReplies = true;
  static const bool defaultIgnoreGroupChats = false;

  // Storage limits
  static const int maxLogs = 1000;
}
