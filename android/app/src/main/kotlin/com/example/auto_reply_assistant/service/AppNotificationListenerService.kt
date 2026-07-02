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
    private lateinit var messageBatcher: MessageBatcher
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        instance = this
        ruleEngine = RuleEngine(applicationContext)
        messageBatcher = MessageBatcher(mainHandler)
        Log.d(TAG, "AppNotificationListenerService created")
    }

    override fun onDestroy() {
        super.onDestroy()
        messageBatcher.cancelAll()
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

        // Schedule window check
        if (!ruleEngine.isWithinScheduleWindow()) {
            Log.d(TAG, "Skipping: outside schedule window")
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
        val rule = ruleEngine.findMatchingRule(message, sender = title)

        if (rule == null) {
            // AI fallback if enabled — buffer messages and batch replies
            if (ruleEngine.isAiReplyEnabled()) {
                // Skip notification artifacts (typing indicators, "X new messages", etc.)
                if (isNotificationArtifact(message)) {
                    Log.d(TAG, "Skipping notification artifact: '${message.take(50)}'")
                    return
                }
                val modelType = ruleEngine.getAiModelType()
                val normalizedName = normalizeSenderName(title, packageName)
                // Batch window: wait 5s for more messages before firing
                val batchWindowMs = 5000L
                Log.d(TAG, "No rule matched. Buffering for AI batch reply (model: $modelType, batchWindow: ${batchWindowMs}ms)...")

                messageBatcher.addMessage(
                    sender = normalizedName,
                    message = message,
                    notificationKey = sbn.key,
                    packageName = packageName,
                    isGroupChat = isGroupChat,
                    delayMs = batchWindowMs
                ) { batch ->
                    Log.d(TAG, "Batch ready for ${batch.sender}: ${batch.messages.size} messages")
                    sendBatchedAiReply(batch, modelType)
                }
            } else {
                Log.d(TAG, "No matching rule for message: '${message.take(50)}'")
            }
            return
        }

        val replyText = rule.randomReply()

        // Duplicate prevention
        if (ruleEngine.shouldPreventDuplicates() &&
            ruleEngine.wasReplyRecentlySent(title, replyText)
        ) return

        // Delay + send
        val delayMs = ruleEngine.getReplyDelayMs()
        notifyReplyScheduled(title, replyText, delayMs)
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
    private fun notifyReplyScheduled(sender: String, replyText: String, delayMs: Long) {
        val data = JSONObject().apply {
            put("sender", sender)
            put("replyText", replyText)
            put("delayMs", delayMs)
            put("scheduledAt", System.currentTimeMillis())
        }
        mainHandler.post {
            methodChannel?.invokeMethod("onReplyScheduled", data.toString())
        }
    }

    fun sendReply(key: String, sender: String, replyText: String, isAiReply: Boolean = false, aiModelType: String = "") {
        try {
            var sbn = activeNotifications?.find { it.key == key }

            // If the original notification is gone or has no reply action, find one that does
            if (sbn != null && !hasReplyAction(sbn) && isAiReply) {
                Log.d(TAG, "Notification $key has no reply action, searching for one with reply action...")
                sbn = findNotificationWithReplyAction(sender)
            } else if (sbn == null && isAiReply) {
                Log.d(TAG, "Notification not found for key: $key, searching by sender...")
                sbn = findNotificationWithReplyAction(sender)
            }

            if (sbn == null) {
                Log.e(TAG, "No active notification found for key: $key, sender: $sender")
                mainHandler.post {
                    methodChannel?.invokeMethod("onReplyFailed", "Notification not found")
                }
                return
            }

            val extras = sbn.notification.extras
            val appName = getAppName(sbn.packageName)
            val originalMessage = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""

            val actions = sbn.notification.actions
            Log.d(TAG, "Notification ${sbn.key} has ${actions?.size ?: 0} actions")
            if (!actions.isNullOrEmpty()) {
                for ((i, action) in actions.withIndex()) {
                    val hasRemote = !action.remoteInputs.isNullOrEmpty()
                    Log.d(TAG, "  Action[$i]: '${action.title}', hasRemoteInput=$hasRemote")
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
                                val replyData = JSONObject().apply {
                                    put("sender", sender)
                                    put("replyText", replyText)
                                    put("key", key)
                                    put("appName", appName)
                                    put("originalMessage", originalMessage)
                                    put("isAiReply", isAiReply)
                                    put("aiModelType", aiModelType)
                                }
                                methodChannel?.invokeMethod("onReplySuccess", replyData.toString())
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

    /**
     * Send a batched AI reply: collect all buffered messages from the batcher callback,
     * call the appropriate AI service with all messages, then send a single reply.
     */
    private fun sendBatchedAiReply(batch: MessageBatcher.BatchReadyCallback, modelType: String) {
        val sender = batch.sender
        val messages = batch.messages.map { it.message }
        val rawHistory = ConversationHistory.getHistory(sender)
        val systemPrompt = ruleEngine.getAiSystemPrompt()

        // Build a clean transcript: filter artifacts, dedup, merge, cap tokens
        val history = ConversationTranscriptBuilder.build(
            history = rawHistory,
            batchMessages = emptyList(), // batch messages are passed separately to the AI service
            senderName = sender
        )

        Log.d(TAG, "sendBatchedAiReply: sender=$sender, ${messages.size} messages, history=${history.size} entries, model=$modelType")

        val onBatchResult: (String?, Int, Int, Int, Int, String?) -> Unit = { aiReply, tokensUsed, tokensRemaining, tokensLimit, resetInSeconds, error ->
            if (tokensUsed > 0) {
                ruleEngine.saveAiUsage(tokensUsed, tokensRemaining, tokensLimit, resetInSeconds, error)
                notifyAiUsage(tokensUsed, tokensRemaining, tokensLimit, resetInSeconds, error)
            }

            if (aiReply != null && aiReply.isNotBlank()) {
                for (msg in messages) {
                    ConversationHistory.addMessage(sender, "user", msg)
                }
                ConversationHistory.addMessage(sender, "assistant", aiReply)

                // Apply the user's configured reply delay on top of the batch window
                val delayMs = ruleEngine.getReplyDelayMs()
                notifyReplyScheduled(sender, aiReply, delayMs)
                mainHandler.postDelayed({
                    sendReply(batch.latestNotificationKey, sender, aiReply, isAiReply = true, aiModelType = modelType)
                }, delayMs)
            } else {
                Log.w(TAG, "Batched AI returned empty reply for sender=$sender")
            }
        }

        when (modelType) {
            "cerebras" -> {
                val apiKey = ruleEngine.getCerebrasApiKey()
                if (apiKey.isNotEmpty()) {
                    CerebrasAiService().getAiReplyBatch(
                        apiKey = apiKey,
                        senderName = sender,
                        incomingMessages = messages,
                        systemPrompt = systemPrompt,
                        conversationHistory = history
                    ) { aiReply, usage ->
                        onBatchResult(
                            aiReply,
                            usage?.tokensUsed ?: 0, usage?.tokensRemaining ?: 0,
                            usage?.tokensLimit ?: 0, usage?.resetInSeconds ?: 0, usage?.error
                        )
                    }
                } else {
                    Log.d(TAG, "Cerebras API key not set, falling back to Groq")
                    fallBackToGroq(sender, messages, history, systemPrompt, batch.latestNotificationKey, modelType, onBatchResult)
                }
            }
            "gemini" -> {
                val apiKeys = ruleEngine.getGeminiApiKeys()
                if (apiKeys.isNotEmpty()) {
                    GeminiAiService().getAiReplyBatch(
                        apiKeys = apiKeys,
                        model = "gemini-2.5-flash",
                        senderName = sender,
                        incomingMessages = messages,
                        systemPrompt = systemPrompt,
                        conversationHistory = history
                    ) { aiReply, usage ->
                        onBatchResult(
                            aiReply,
                            usage?.tokensUsed ?: 0, usage?.tokensRemaining ?: 0,
                            usage?.tokensLimit ?: 0, usage?.resetInSeconds ?: 0, usage?.error
                        )
                    }
                } else {
                    Log.d(TAG, "Gemini API key not set, falling back to Groq")
                    fallBackToGroq(sender, messages, history, systemPrompt, batch.latestNotificationKey, modelType, onBatchResult)
                }
            }
            else -> {
                fallBackToGroq(sender, messages, history, systemPrompt, batch.latestNotificationKey, modelType, onBatchResult)
            }
        }
    }

    private fun fallBackToGroq(
        sender: String,
        messages: List<String>,
        history: List<ConversationHistory.ChatMessage>,
        systemPrompt: String,
        notificationKey: String,
        modelType: String,
        onBatchResult: (String?, Int, Int, Int, Int, String?) -> Unit
    ) {
        val groqKey = ruleEngine.getGroqApiKey()
        if (groqKey.isNotEmpty()) {
            GroqAiService().getAiReplyBatch(
                apiKey = groqKey,
                senderName = sender,
                incomingMessages = messages,
                systemPrompt = systemPrompt,
                conversationHistory = history
            ) { aiReply, usage ->
                onBatchResult(
                    aiReply,
                    usage?.tokensUsed ?: 0, usage?.tokensRemaining ?: 0,
                    usage?.tokensLimit ?: 0, usage?.resetInSeconds ?: 0, usage?.error
                )
            }
        } else {
            Log.d(TAG, "Groq API key not set, cannot send batched reply")
        }
    }

    private fun notifyAiUsage(tokensUsed: Int, tokensRemaining: Int, tokensLimit: Int, resetInSeconds: Int, error: String?) {
        val usageData = org.json.JSONObject().apply {
            put("tokensUsed", tokensUsed)
            put("tokensRemaining", tokensRemaining)
            put("tokensLimit", tokensLimit)
            put("resetInSeconds", resetInSeconds)
            put("error", error ?: "")
        }
        mainHandler.post {
            methodChannel?.invokeMethod("onAiUsageUpdate", usageData.toString())
        }
    }

    private fun getAppName(packageName: String) = when (packageName) {
        "com.whatsapp" -> "WhatsApp"
        "com.instagram.android" -> "Instagram"
        else -> packageName
    }

    private fun hasReplyAction(sbn: StatusBarNotification): Boolean {
        val actions = sbn.notification?.actions ?: return false
        return actions.any { it.remoteInputs?.isNotEmpty() == true }
    }

    /**
     * Find any active notification from the same sender that has a direct reply action.
     * Returns null if none found.
     */
    private fun findNotificationWithReplyAction(sender: String): StatusBarNotification? {
        return activeNotifications?.filter {
            it.packageName in supportedPackages &&
            it.notification.extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.contains(sender, ignoreCase = true) == true &&
            hasReplyAction(it)
        }?.lastOrNull()
    }

    private fun isGroupChat(notification: Notification) =
        notification.extras.getBoolean(Notification.EXTRA_IS_GROUP_CONVERSATION, false)

    /**
     * Normalize sender name for consistent batching.
     * WhatsApp sometimes prefixes titles with "WhatsApp: " — strip it so
     * "WhatsApp: Rahul" and "Rahul" are treated as the same sender.
     */
    private fun normalizeSenderName(title: String, packageName: String): String {
        return when (packageName) {
            "com.whatsapp" -> {
                title.removePrefix("WhatsApp: ").trim()
            }
            else -> title.trim()
        }
    }

    /**
     * Quick check for obvious notification artifacts before they enter the batcher.
     * More thorough filtering is done by [ConversationTranscriptBuilder] at transcript-build time.
     */
    private fun isNotificationArtifact(message: String): Boolean {
        return ConversationTranscriptBuilder.isArtifact(message)
    }
}
