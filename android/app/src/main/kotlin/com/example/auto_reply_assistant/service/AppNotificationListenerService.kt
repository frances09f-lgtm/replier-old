package com.example.auto_reply_assistant.service

import android.app.Notification
import android.app.RemoteInput
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * Notification listener that auto-replies entirely on the native side.
 *
 * Rule matching and settings are read from SharedPreferences via RuleEngine,
 * so this works whether or not the Flutter engine / UI is running.
 *
 * The MethodChannel is used only to notify the Flutter UI about events
 * (e.g. updating the logs screen). It is always optional — if Flutter
 * isn't running, replies still go out.
 */
class AppNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "AppNotificationListener"

        // Optional Flutter channel — used only for UI updates, not for core logic
        private var methodChannel: MethodChannel? = null
        private var instance: AppNotificationListenerService? = null

        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }

        fun getInstance(): AppNotificationListenerService? = instance
    }

    private val supportedPackages = listOf(
        "com.whatsapp",
        "com.instagram.android"
    )

    private lateinit var ruleEngine: RuleEngine
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        instance = this
        ruleEngine = RuleEngine(applicationContext)
        Log.d(TAG, "AppNotificationListenerService created")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "AppNotificationListenerService destroyed")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        super.onNotificationPosted(sbn)

        val packageName = sbn.packageName
        if (!supportedPackages.contains(packageName)) return

        val notification = sbn.notification ?: return
        val extras = notification.extras

        val appName = getAppName(packageName)
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
        val message = if (bigText.isNotEmpty()) bigText else text
        val isGroupChat = isGroupChat(notification)

        Log.d(TAG, "Notification from $appName: $title — $message")

        // Notify Flutter UI (optional, best-effort)
        val notificationData = JSONObject().apply {
            put("packageName", packageName)
            put("appName", appName)
            put("sender", title)
            put("message", message)
            put("timestamp", sbn.postTime)
            put("isGroupChat", isGroupChat)
            put("key", sbn.key)
        }
        mainHandler.post {
            methodChannel?.invokeMethod("onNotificationPosted", notificationData.toString())
        }

        // ── Core auto-reply logic (fully native, no Flutter needed) ──────────

        // Master switch
        if (!ruleEngine.isMasterEnabled()) {
            Log.d(TAG, "Skipping: master switch is OFF")
            return
        }

        // Per-app toggle
        if (!ruleEngine.isAppEnabled(packageName)) {
            Log.d(TAG, "Skipping: $packageName is disabled in settings")
            return
        }

        // Group chat filter
        if (ruleEngine.shouldIgnoreGroupChats() && isGroupChat) {
            Log.d(TAG, "Skipping: group chat ignored")
            return
        }

        // Self-reply guard
        if (ruleEngine.isSelfSentMessage(message)) {
            Log.d(TAG, "Skipping: self-sent message detected")
            return
        }

        // Rule matching
        val rule = ruleEngine.findMatchingRule(message) ?: run {
            Log.d(TAG, "No matching rule for message: '${message.take(50)}'")
            return
        }

        val replyText = rule.replyText

        // Duplicate prevention
        if (ruleEngine.shouldPreventDuplicates() &&
            ruleEngine.wasReplyRecentlySent(title, replyText)
        ) return

        // Delay + send
        val delayMs = ruleEngine.getReplyDelayMs()
        mainHandler.postDelayed({
            sendReply(sbn.key, title, replyText)
        }, delayMs)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        super.onNotificationRemoved(sbn)
        if (!supportedPackages.contains(sbn.packageName)) return
        mainHandler.post {
            methodChannel?.invokeMethod("onNotificationRemoved", sbn.key)
        }
    }

    /**
     * Send a reply using the notification's direct reply RemoteInput action.
     * Called from onNotificationPosted (native) and from Flutter via MethodChannel.
     */
    fun sendReply(key: String, sender: String, replyText: String) {
        try {
            val sbn = activeNotifications?.find { it.key == key }
            if (sbn == null) {
                Log.e(TAG, "Notification not found for key: $key")
                mainHandler.post {
                    methodChannel?.invokeMethod("onReplyFailed", "Notification not found")
                }
                return
            }

            val actions = sbn.notification.actions
            if (!actions.isNullOrEmpty()) {
                for (action in actions) {
                    if (!action.remoteInputs.isNullOrEmpty()) {
                        val remoteInput = action.remoteInputs[0]
                        val replyIntent = Intent()
                        RemoteInput.addResultsToIntent(
                            action.remoteInputs,
                            replyIntent,
                            Bundle().apply {
                                putCharSequence(remoteInput.resultKey, replyText)
                            }
                        )
                        try {
                            action.actionIntent.send(applicationContext, 0, replyIntent)
                            ruleEngine.recordReplySent(sender, replyText)
                            Log.d(TAG, "Reply sent: '$replyText' to '$sender'")
                            mainHandler.post {
                                methodChannel?.invokeMethod("onReplySuccess", null)
                            }
                            return
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to send reply via PendingIntent", e)
                        }
                    }
                }
            }

            Log.w(TAG, "No direct reply action found for key: $key")
            mainHandler.post {
                methodChannel?.invokeMethod("onReplyFailed", "No direct reply action found")
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error sending reply", e)
            mainHandler.post {
                methodChannel?.invokeMethod("onReplyFailed", e.message)
            }
        }
    }

    private fun getAppName(packageName: String) = when (packageName) {
        "com.whatsapp" -> "WhatsApp"
        "com.instagram.android" -> "Instagram"
        else -> packageName
    }

    private fun isGroupChat(notification: Notification) =
        notification.extras.getBoolean(Notification.EXTRA_IS_GROUP_CONVERSATION, false)
}
