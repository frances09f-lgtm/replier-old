import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/rule.dart';
import '../models/app_settings.dart';
import '../models/reply_log.dart';
import '../core/constants.dart';

/// Hive configuration and initialization
class HiveConfig {
  /// Initialize Hive and register adapters
  static Future<void> initialize() async {
    // Get application documents directory
    final appDocDir = await getApplicationDocumentsDirectory();
    
    // Initialize Hive
    await Hive.initFlutter(appDocDir.path);
    
    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(RuleAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AppSettingsAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ReplyLogAdapter());
    }
    
    // Open boxes (data persists across app launches)
    await Hive.openBox<Rule>(AppConstants.rulesBox);
    await Hive.openBox<AppSettings>(AppConstants.settingsBox);
    await Hive.openBox<ReplyLog>(AppConstants.logsBox);
    await Hive.openBox(AppConstants.statsBox);
    
    print('Hive boxes initialized');
  }

  /// Get rules box
  static Box<Rule> getRulesBox() {
    return Hive.box<Rule>(AppConstants.rulesBox);
  }

  /// Get settings box
  static Box<AppSettings> getSettingsBox() {
    return Hive.box<AppSettings>(AppConstants.settingsBox);
  }

  /// Get logs box
  static Box<ReplyLog> getLogsBox() {
    return Hive.box<ReplyLog>(AppConstants.logsBox);
  }

  /// Get stats box (for counters like total notifications received)
  static Box getStatsBox() {
    return Hive.box(AppConstants.statsBox);
  }

  /// Close all boxes
  static Future<void> close() async {
    await Hive.close();
  }

  /// Clear all data (for testing purposes)
  static Future<void> clearAll() async {
    await getRulesBox().clear();
    await getSettingsBox().clear();
    await getLogsBox().clear();
  }
}
