package com.example.auto_reply_assistant

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.annotation.NonNull
import com.example.auto_reply_assistant.service.AppNotificationListenerService
import com.example.auto_reply_assistant.service.AutoReplyForegroundService
import com.example.auto_reply_assistant.service.RuleEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val NATIVE_CHANNEL = "com.example.auto_reply_assistant/native"
    private val NOTIFICATION_CHANNEL = "com.example.auto_reply_assistant/notification"

    private lateinit var nativeMethodChannel: MethodChannel
    private lateinit var notificationMethodChannel: MethodChannel
    private lateinit var ruleEngine: RuleEngine

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        ruleEngine = RuleEngine(applicationContext)

        // ── Native channel (settings / permissions) ──────────────────────────
        nativeMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, NATIVE_CHANNEL
        )
        nativeMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationListenerSettings" -> {
                    startActivity(Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"))
                    result.success(null)
                }
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                "openBatteryOptimizationSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        startActivity(
                            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                        )
                    }
                    result.success(null)
                }
                "isNotificationListenerEnabled" ->
                    result.success(isNotificationListenerEnabled())
                "isAccessibilityServiceEnabled" ->
                    result.success(isAccessibilityServiceEnabled())
                "isBatteryOptimizationDisabled" ->
                    result.success(isBatteryOptimizationDisabled())

                // Flutter calls this to sync rules into SharedPreferences
                "syncRules" -> {
                    val rulesJson = call.argument<String>("rulesJson")
                    if (rulesJson != null) {
                        ruleEngine.saveRules(rulesJson)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENTS", "rulesJson is null", null)
                    }
                }

                // Flutter calls this to sync settings into SharedPreferences
                "syncSettings" -> {
                    val settingsJson = call.argument<String>("settingsJson")
                    if (settingsJson != null) {
                        ruleEngine.saveSettings(settingsJson)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENTS", "settingsJson is null", null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        // ── Notification channel (send reply + UI callbacks) ─────────────────
        notificationMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL
        )
        notificationMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "sendReply" -> {
                    val key = call.argument<String>("key")
                    val replyText = call.argument<String>("replyText")
                    if (key != null && replyText != null) {
                        AppNotificationListenerService.getInstance()
                            ?.sendReply(key, "", replyText)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing key or replyText", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Wire up the method channel so the service can notify Flutter UI
        AppNotificationListenerService.setMethodChannel(notificationMethodChannel)

        // Start the foreground service to keep the process alive
        AutoReplyForegroundService.start(applicationContext)
    }

    // ── Permission helpers ────────────────────────────────────────────────────

    private fun isNotificationListenerEnabled(): Boolean {
        val enabled = Settings.Secure.getString(
            contentResolver, "enabled_notification_listeners"
        )
        return enabled?.contains(packageName) ?: false
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val enabled = Settings.Secure.getString(
            contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        )
        return enabled?.contains(packageName) ?: false
    }

    private fun isBatteryOptimizationDisabled(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(POWER_SERVICE) as android.os.PowerManager
            return pm.isIgnoringBatteryOptimizations(packageName)
        }
        return true
    }
}
