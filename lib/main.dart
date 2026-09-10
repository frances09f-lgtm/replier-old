import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/hive_config.dart';
import 'core/injection_container.dart';
import 'core/provider_container.dart';
import 'providers/settings_provider.dart';
import 'providers/pipeline_status_provider.dart';
import 'repositories/log_repository.dart';
import 'repositories/rule_repository.dart';
import 'services/auto_reply_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HiveConfig.initialize();
  await configureDependencies();

  // Logging-only listener — native side handles actual replies.
  // DO NOT call sendReply from here — that would cause double-replies.
  // NOTE: Sample rules are added and synced to native SharedPreferences
  // inside SplashScreen via the provider (which also calls syncRules).
  AutoReplyService(
    ruleRepository: RuleRepository(),
    logRepository: LogRepository(),
    providerContainer: globalProviderContainer,
  ).initialize();

  // Eagerly initialise pipeline status provider so it registers
  // MethodChannel callbacks before the first notification arrives.
  globalProviderContainer.read(pipelineStatusProvider);

  runApp(
    UncontrolledProviderScope(
      container: globalProviderContainer,
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp(
      title: 'Auto Reply Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: settings.darkMode ? Brightness.dark : Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
