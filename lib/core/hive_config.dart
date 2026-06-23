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
    
    // Force clear all boxes to handle schema migration
    // This is necessary because we added new fields to the models
    try {
      await Hive.deleteBoxFromDisk(AppConstants.rulesBox);
    } catch (e) {
      print('Rules box may not exist yet: $e');
    }
    
    try {
      await Hive.deleteBoxFromDisk(AppConstants.settingsBox);
    } catch (e) {
      print('Settings box may not exist yet: $e');
    }
    
    try {
      await Hive.deleteBoxFromDisk(AppConstants.logsBox);
    } catch (e) {
      print('Logs box may not exist yet: $e');
    }
    
    // Open fresh boxes
    await Hive.openBox<Rule>(AppConstants.rulesBox);
    await Hive.openBox<AppSettings>(AppConstants.settingsBox);
    await Hive.openBox<ReplyLog>(AppConstants.logsBox);
    
    print('Hive boxes initialized with fresh schema');
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
