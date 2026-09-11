package com.example.auto_reply_assistant.service

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.RemoteInput
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

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
        private const val CONFIRM_NOTIFICATION_CHANNEL_ID = "confirm_reply_channel"
        private const val CONFIRM_NOTIFICATION_ID_BASE = 9000
        private const val CONFIRM_TIMEOUT_MS = 15_000L

        const val ACTION_APPROVE = "com.example.auto_reply_assistant.APPROVE_REPLY"
        const val ACTION_DENY = "com.example.auto_reply_assistant.DENY_REPLY"
        const val EXTRA_CONFIRM_ID = "confirm_id"
        const val EXTRA_NOTIFICATION_KEY = "notification_key"
        const val EXTRA_SENDER = "sender"
        const val EXTRA_REPLY_TEXT = "reply_text"
        const val EXTRA_ORIGINAL_MESSAGE = "original_message"
        const val EXTRA_IS_AI_REPLY = "is_ai_reply"
        const val EXTRA_AI_MODEL_TYPE = "ai_model_type"

        // Optional Flutter channel — used only for UI updates, not for core logic
        private var methodChannel: MethodChannel? = null
        private var instance: AppNotificationListenerService? = null

        // Chatbot context from the Flutter chatbot — injected into AI auto-reply system prompt
        private var chatbotContext: String = ""

        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }

        fun getInstance(): AppNotificationListenerService? = instance

        fun setChatbotContext(context: String) {
            chatbotContext = context
            Log.d(TAG, "Chatbot context updated (${context.length} chars)")
        }

        fun getChatbotContext(): String = chatbotContext
    }

    /** Data class for a reply pending user confirmation */
    data class PendingReply(
        val confirmId: String,
        val notificationKey: String,
        val sender: String,
        val replyText: String,
        val originalMessage: String,
        val isAiReply: Boolean,
        val aiModelType: String,
        val createdAt: Long = System.currentTimeMillis(),
    )

    /** In-memory store of pending confirmations, keyed by confirmId */
    private val pendingReplies = ConcurrentHashMap<String, PendingReply>()
    private var confirmReceiver: BroadcastReceiver? = null

    /** Cooldown map: sender -> timestamp to prevent reacting to our own sent messages */
    private val senderCooldown = ConcurrentHashMap<String, Long>()
    private val senderCooldownMs = 3000L

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
        createConfirmNotificationChannel()
        registerConfirmReceiver()
        Log.d(TAG, "AppNotificationListenerService created")
    }

    override fun onDestroy() {
        super.onDestroy()
        messageBatcher.cancelAll()
        unregisterConfirmReceiver()
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

        // Sender cooldown: skip if we just handled this sender (prevents self-message loop)
        val now = System.currentTimeMillis()
        val lastHandled = senderCooldown[title]
        if (lastHandled != null && now - lastHandled < senderCooldownMs) {
            Log.d(TAG, "Skipping: sender '$title' on cooldown (${now - lastHandled}ms ago)")
            return
        }

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

        // Emit "got_message" to Flutter UI
        notifyPipelineStatus("got_message", title)

        // Rule matching
        val rule = ruleEngine.findMatchingRule(message, sender = title)

        if (rule == null) {
            // Busy mode check — if user set a busy status from chatbot, use it
            val busyText = ruleEngine.getBusyReplyText()
            if (ruleEngine.isBusyModeActive() && busyText.isNotBlank()) {
                Log.d(TAG, "Busy mode active, using busy reply: '$busyText'")
                ConversationHistory.addMessage(title, "user", message)
                if (ruleEngine.isConfirmBeforeReplyEnabled()) {
                    showConfirmationNotification(
                        notificationKey = sbn.key,
                        sender = title,
                        replyText = busyText,
                        originalMessage = message,
                        isAiReply = false,
                        aiModelType = "busy_mode",
                    )
                } else {
                    senderCooldown[title] = System.currentTimeMillis()
                    val delayMs = ruleEngine.getReplyDelayMs()
                    notifyReplyScheduled(title, busyText, delayMs)
                    val replyToSend = busyText
                    val senderName = title
                    mainHandler.postDelayed({
                        ConversationHistory.addMessage(senderName, "assistant", replyToSend)
                        sendReply(sbn.key, senderName, replyToSend)
                    }, delayMs)
                }
                return
            }

            // AI fallback if enabled — buffer messages and batch replies
            if (ruleEngine.isAiReplyEnabled()) {
                // Skip notification artifacts (typing indicators, "X new messages", etc.)
                if (isNotificationArtifact(message)) {
                    Log.d(TAG, "Skipping notification artifact: '${message.take(50)}'")
                    return
                }
                val modelType = ruleEngine.getAiModelType()
                val normalizedName = normalizeSenderName(title, packageName)
                // Batch window: wait 2s for more messages before firing
                val batchWindowMs = 2000L
                Log.d(TAG, "No rule matched. Buffering for AI batch reply (model: $modelType, batchWindow: ${batchWindowMs}ms)...")

                // Emit "analysing" immediately so the UI shows the processing state
                notifyPipelineStatus("analysing", title)

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

        // Emit "analysing" then "reply_ready" now that a rule match was found
        notifyPipelineStatus("analysing", title)
        notifyPipelineStatus("reply_ready", title)

        // Confirm before reply: show approval notification instead of sending directly
        if (ruleEngine.isConfirmBeforeReplyEnabled()) {
            senderCooldown[title] = System.currentTimeMillis()
            val delayMs = ruleEngine.getReplyDelayMs()
            notifyReplyScheduled(title, replyText, delayMs)
            showConfirmationNotification(
                notificationKey = sbn.key,
                sender = title,
                replyText = replyText,
                originalMessage = message,
                isAiReply = false,
                aiModelType = "",
            )
            return
        }

        // Delay + send
        senderCooldown[title] = System.currentTimeMillis()
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

    private fun notifyPipelineStatus(state: String, sender: String) {
        val data = JSONObject().apply {
            put("state", state)
            put("sender", sender)
        }
        mainHandler.post {
            methodChannel?.invokeMethod("onPipelineStatus", data.toString())
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
        val chatbotCtx = getChatbotContext()
        val finalSystemPrompt = if (chatbotCtx.isNotEmpty()) {
            "$systemPrompt\n\n---\nCHAT CONTEXT (Abhi told the chatbot this — use it for awareness but do NOT mention the chatbot):\n$chatbotCtx\n---"
        } else {
            systemPrompt
        }

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

                // Emit "reply_ready" before scheduling the send
                notifyPipelineStatus("reply_ready", sender)

                // Confirm before reply: show approval notification instead of sending directly
                if (ruleEngine.isConfirmBeforeReplyEnabled()) {
                    senderCooldown[sender] = System.currentTimeMillis()
                    val delayMs = ruleEngine.getReplyDelayMs()
                    notifyReplyScheduled(sender, aiReply, delayMs)
                    showConfirmationNotification(
                        notificationKey = batch.latestNotificationKey,
                        sender = sender,
                        replyText = aiReply,
                        originalMessage = messages.lastOrNull() ?: "",
                        isAiReply = true,
                        aiModelType = modelType,
                    )
                } else {
                    // Apply the user's configured reply delay on top of the batch window
                    senderCooldown[sender] = System.currentTimeMillis()
                    val delayMs = ruleEngine.getReplyDelayMs()
                    notifyReplyScheduled(sender, aiReply, delayMs)
                    mainHandler.postDelayed({
                        sendReply(batch.latestNotificationKey, sender, aiReply, isAiReply = true, aiModelType = modelType)
                    }, delayMs)
                }
            } else {
                Log.w(TAG, "Batched AI returned empty reply for sender=$sender")
            }
        }

        when (modelType) {
            "phi_local" -> {
                val selectedModel = ruleEngine.getSelectedLocalModel()
                PhiLocalService.getInstance(applicationContext).getAiReplyBatch(
                    modelId = selectedModel,
                    senderName = sender,
                    incomingMessages = messages,
                    systemPrompt = finalSystemPrompt,
                    conversationHistory = history
                ) { aiReply, usage ->
                    onBatchResult.invoke(
                        aiReply,
                        usage?.tokensUsed ?: 0, usage?.tokensRemaining ?: 0,
                        usage?.tokensLimit ?: 0, usage?.resetInSeconds ?: 0, usage?.error
                    )
                }
            }
            "cerebras_api" -> {
                val apiKey = ruleEngine.getCerebrasApiKey()
                val model = ruleEngine.getCerebrasModel()
                PhiLocalService.getInstance(applicationContext).getCerebrasReplyBatch(
                    apiKey = apiKey,
                    model = model,
                    senderName = sender,
                    incomingMessages = messages,
                    systemPrompt = finalSystemPrompt,
                    conversationHistory = history
                ) { aiReply, usage ->
                    onBatchResult.invoke(
                        aiReply,
                        usage?.tokensUsed ?: 0, usage?.tokensRemaining ?: 0,
                        usage?.tokensLimit ?: 0, usage?.resetInSeconds ?: 0, usage?.error
                    )
                }
            }
            "auto_local_first" -> {
                val service = PhiLocalService.getInstance(applicationContext)
                val apiKey = ruleEngine.getCerebrasApiKey()
                val cerebrasModel = ruleEngine.getCerebrasModel()
                val selectedLocalModel = ruleEngine.getSelectedLocalModel()
                val isHard = service.isMessageHardOrConfusing(messages)

                if (isHard && apiKey.isNotBlank()) {
                    Log.d(TAG, "Message is hard/confusing, escalating directly to Cerebras API for $sender")
                    service.getCerebrasReplyBatch(
                        apiKey = apiKey,
                        model = cerebrasModel,
                        senderName = sender,
                        incomingMessages = messages,
                        systemPrompt = finalSystemPrompt,
                        conversationHistory = history
                    ) { aiReply, usage ->
                        onBatchResult.invoke(
                            aiReply,
                            usage?.tokensUsed ?: 0, usage?.tokensRemaining ?: 0,
                            usage?.tokensLimit ?: 0, usage?.resetInSeconds ?: 0, usage?.error
                        )
                    }
                } else if (service.isModelAvailable(selectedLocalModel)) {
                    Log.d(TAG, "Attempting local model first for $sender")
                    service.getAiReplyBatch(
                        modelId = selectedLocalModel,
                        senderName = sender,
                        incomingMessages = messages,
                        systemPrompt = finalSystemPrompt,
                        conversationHistory = history
                    ) { localReply, usage ->
                        val failed = usage?.error != null || localReply.isNullOrBlank()
                        if (failed && apiKey.isNotBlank()) {
                            Log.d(TAG, "Local model failed (${usage?.error}), falling back to Cerebras API for $sender")
                            service.getCerebrasReplyBatch(
                                apiKey = apiKey,
                                model = cerebrasModel,
                                senderName = sender,
                                incomingMessages = messages,
                                systemPrompt = finalSystemPrompt,
                                conversationHistory = history
                            ) { apiReply, apiUsage ->
                                onBatchResult.invoke(
                                    apiReply,
                                    apiUsage?.tokensUsed ?: 0, apiUsage?.tokensRemaining ?: 0,
                                    apiUsage?.tokensLimit ?: 0, apiUsage?.resetInSeconds ?: 0, apiUsage?.error
                                )
                            }
                        } else {
                            onBatchResult.invoke(
                                localReply,
                                usage?.tokensUsed ?: 0, usage?.tokensRemaining ?: 0,
                                usage?.tokensLimit ?: 0, usage?.resetInSeconds ?: 0, usage?.error
                            )
                        }
                    }
                } else if (apiKey.isNotBlank()) {
                    Log.d(TAG, "Local model not downloaded, routing to Cerebras API for $sender")
                    service.getCerebrasReplyBatch(
                        apiKey = apiKey,
                        model = cerebrasModel,
                        senderName = sender,
                        incomingMessages = messages,
                        systemPrompt = finalSystemPrompt,
                        conversationHistory = history
                    ) { aiReply, usage ->
                        onBatchResult.invoke(
                            aiReply,
                            usage?.tokensUsed ?: 0, usage?.tokensRemaining ?: 0,
                            usage?.tokensLimit ?: 0, usage?.resetInSeconds ?: 0, usage?.error
                        )
                    }
                } else {
                    service.getAiReplyBatch(
                        modelId = selectedLocalModel,
                        senderName = sender,
                        incomingMessages = messages,
                        systemPrompt = finalSystemPrompt,
                        conversationHistory = history
                    ) { aiReply, usage ->
                        onBatchResult.invoke(
                            aiReply,
                            usage?.tokensUsed ?: 0, usage?.tokensRemaining ?: 0,
                            usage?.tokensLimit ?: 0, usage?.resetInSeconds ?: 0, usage?.error
                        )
                    }
                }
            }
            else -> {
                Log.w(TAG, "Unknown AI model type: $modelType")
            }
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

    // ── Confirm Before Reply ────────────────────────────────────────────────

    private fun createConfirmNotificationChannel() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                CONFIRM_NOTIFICATION_CHANNEL_ID,
                "Reply Confirmations",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Shows confirmation before sending auto-replies"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 300)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    private fun registerConfirmReceiver() {
        confirmReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val confirmId = intent.getStringExtra(EXTRA_CONFIRM_ID) ?: return
                val action = intent.action ?: return

                val pending = pendingReplies.remove(confirmId) ?: return
                val nm = getSystemService(NotificationManager::class.java)
                nm.cancel(CONFIRM_NOTIFICATION_ID_BASE + confirmId.hashCode())

                when (action) {
                    ACTION_APPROVE -> {
                        Log.d(TAG, "User APPROVED reply to '${pending.sender}': '${pending.replyText}'")
                        mainHandler.postDelayed({
                            sendReply(
                                pending.notificationKey,
                                pending.sender,
                                pending.replyText,
                                pending.isAiReply,
                                pending.aiModelType,
                            )
                        }, ruleEngine.getReplyDelayMs())
                    }
                    ACTION_DENY -> {
                        Log.d(TAG, "User DENIED reply to '${pending.sender}'")
                        mainHandler.post {
                            methodChannel?.invokeMethod("onReplyDenied", pending.sender)
                        }
                    }
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(ACTION_APPROVE)
            addAction(ACTION_DENY)
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(confirmReceiver, filter, RECEIVER_EXPORTED)
        } else {
            registerReceiver(confirmReceiver, filter)
        }
        Log.d(TAG, "Confirm receiver registered")
    }

    private fun unregisterConfirmReceiver() {
        confirmReceiver?.let {
            try { unregisterReceiver(it) } catch (_: Exception) {}
        }
        confirmReceiver = null
    }

    private fun showConfirmationNotification(
        notificationKey: String,
        sender: String,
        replyText: String,
        originalMessage: String,
        isAiReply: Boolean,
        aiModelType: String,
    ) {
        val confirmId = UUID.randomUUID().toString()
        val notifId = CONFIRM_NOTIFICATION_ID_BASE + confirmId.hashCode()

        // Store the pending reply
        pendingReplies[confirmId] = PendingReply(
            confirmId = confirmId,
            notificationKey = notificationKey,
            sender = sender,
            replyText = replyText,
            originalMessage = originalMessage,
            isAiReply = isAiReply,
            aiModelType = aiModelType,
        )

        // Build approve intent
        val approveIntent = Intent(ACTION_APPROVE).apply {
            putExtra(EXTRA_CONFIRM_ID, confirmId)
            putExtra(EXTRA_NOTIFICATION_KEY, notificationKey)
            putExtra(EXTRA_SENDER, sender)
            putExtra(EXTRA_REPLY_TEXT, replyText)
        }
        val approvePending = PendingIntent.getBroadcast(
            this, notifId, approveIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        // Build deny intent
        val denyIntent = Intent(ACTION_DENY).apply {
            putExtra(EXTRA_CONFIRM_ID, confirmId)
            putExtra(EXTRA_SENDER, sender)
        }
        val denyPending = PendingIntent.getBroadcast(
            this, notifId + 1, denyIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        // Truncate original message aggressively so reply text is fully visible
        val displayReply = replyText
        val displayOriginal = if (originalMessage.length > 40) originalMessage.take(40) + "..." else originalMessage
        val aiTag = if (isAiReply) " [AI]" else ""

        val collapsedText = "Reply: $displayReply  |  From: $displayOriginal"
        val expandedText = "Reply:\n\"$displayReply\"\n\nFrom $sender:\n\"$displayOriginal\""

        val notification = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            Notification.Builder(this, CONFIRM_NOTIFICATION_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Reply to $sender?$aiTag")
            .setContentText(collapsedText)
            .setStyle(
                Notification.BigTextStyle()
                    .bigText(expandedText)
                    .setBigContentTitle("Reply to $sender?$aiTag")
                    .setSummaryText("Tap Send or Cancel")
            )
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(
                Notification.Action.Builder(
                    null, "Send", approvePending
                ).build()
            )
            .addAction(
                Notification.Action.Builder(
                    null, "Cancel", denyPending
                ).build()
            )
            .setPriority(Notification.PRIORITY_HIGH)
            .setCategory(Notification.CATEGORY_MESSAGE)
            .build()

        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(notifId, notification)

        // Verify notification was actually posted (check on Android 13+)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            if (!nm.areNotificationsEnabled()) {
                Log.w(TAG, "POST_NOTIFICATIONS permission not granted — notification may not be visible")
            }
        }

        // Auto-send after timeout if not confirmed
        mainHandler.postDelayed({
            val pending = pendingReplies.remove(confirmId)
            if (pending != null) {
                Log.d(TAG, "Confirmation for '$sender' timed out — sending automatically")
                nm.cancel(notifId)
                sendReply(
                    pending.notificationKey,
                    pending.sender,
                    pending.replyText,
                    pending.isAiReply,
                    pending.aiModelType,
                )
            }
        }, CONFIRM_TIMEOUT_MS)

        Log.d(TAG, "Showing confirmation notification for '$sender': \"$displayReply\"")
    }
}
