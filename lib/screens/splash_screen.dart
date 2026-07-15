import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/default_rules.dart';
import '../providers/rule_provider.dart';
import 'dashboard_screen.dart';

/// Splash screen that initializes the app and navigates to dashboard
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Request POST_NOTIFICATIONS permission (required on Android 13+)
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // Navigate to dashboard after a short delay
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    }

    // Refresh rules to sync with native side on startup
    try {
      final notifier = ref.read(rulesProvider.notifier);

      // Load default rules on first launch
      if (!notifier.hasDefaultRules()) {
        for (final rule in defaultRules) {
          await notifier.addRule(rule);
        }
      } else {
        await notifier.refreshRules();
      }
    } catch (e) {
      print('Error refreshing rules on startup: $e');
    }


  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.reply_rounded,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Auto Reply Assistant',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
