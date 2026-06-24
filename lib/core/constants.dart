/// App constants
class AppConstants {
  // App info
  static const String appName = 'Auto Reply Assistant';
  static const String appVersion = '1.0.0';

  // Hive box names
  static const String rulesBox = 'rules';
  static const String settingsBox = 'settings';
  static const String logsBox = 'logs';
  static const String statsBox = 'stats';

  // Method channel names
  static const String nativeChannel = 'com.example.auto_reply_assistant/native';
  static const String notificationChannel = 'com.example.auto_reply_assistant/notification';
  static const String accessibilityChannel = 'com.example.auto_reply_assistant/accessibility';

  // Supported apps
  static const String whatsappPackage = 'com.whatsapp';
  static const String instagramPackage = 'com.instagram.android';

  // Default settings
  static const int defaultMinReplyDelay = 0;
  static const int defaultMaxReplyDelay = 10;
  static const int maxReplyDelay = 60;
  static const bool defaultPreventDuplicateReplies = true;
  static const bool defaultIgnoreGroupChats = true;

  // Storage limits
  static const int maxLogs = 1000;
}
