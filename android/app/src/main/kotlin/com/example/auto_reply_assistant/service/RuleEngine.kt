package com.example.auto_reply_assistant.service

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlin.random.Random

/**
 * Pure Kotlin rule engine.
 *
 * Rules are stored in TWO places (both written by Flutter's NativeSyncService):
 *   1. auto_reply_rules.json  — app's files directory (primary source)
 *   2. SharedPreferences       — secondary / legacy fallback
 *
 * Reading from the file is preferred because Flutter can write it without
 * requiring MainActivity to be alive (no MethodChannel needed for the write).
 * The file is in the app's internal storage, so it is private to this app.
 */
class RuleEngine(private val context: Context) {

    companion object {
        private const val TAG = "RuleEngine"
        const val PREFS_NAME = "auto_reply_prefs"
        const val KEY_RULES = "rules_json"
        const val KEY_MASTER_ENABLED = "master_enabled"
        const val KEY_WHATSAPP_ENABLED = "whatsapp_enabled"
        const val KEY_INSTAGRAM_ENABLED = "instagram_enabled"
        const val KEY_IGNORE_GROUP_CHATS = "ignore_group_chats"
        const val KEY_MIN_REPLY_DELAY_SECONDS = "min_reply_delay_seconds"
        const val KEY_MAX_REPLY_DELAY_SECONDS = "max_reply_delay_seconds"
        const val KEY_PREVENT_DUPLICATES = "prevent_duplicate_replies"

        private const val KEY_CONTACT_WHITELIST_ENABLED = "contact_whitelist_enabled"
        private const val KEY_CONTACT_WHITELIST = "contact_whitelist"
        private const val KEY_CONTACT_BLACKLIST = "contact_blacklist"

        private const val RULES_FILE = "auto_reply_rules.json"
        private const val SETTINGS_FILE = "auto_reply_settings.json"
        private const val KEY_AI_PROVIDER_STATS = "ai_provider_stats_json"
    }

    private val prefs get() = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    // ── File helpers ─────────────────────────────────────────────────────────

    /**
     * Returns the app's getFilesDir() path — same as Flutter's
     * getApplicationDocumentsDirectory() on Android.
     */
    private fun filesDir(): File = context.filesDir

    private fun readRulesJson(): String {
        // Primary: read from file written by Flutter
        val file = File(filesDir(), RULES_FILE)
        if (file.exists()) {
            try {
                val content = file.readText()
                if (content.isNotBlank()) {
                    Log.d(TAG, "readRulesJson: read ${content.length} bytes from file")
                    return content
                }
            } catch (e: Exception) {
                Log.e(TAG, "readRulesJson: failed to read file, falling back to prefs", e)
            }
        }
        // Fallback: SharedPreferences (written via MethodChannel)
        val fromPrefs = prefs.getString(KEY_RULES, "[]") ?: "[]"
        Log.d(TAG, "readRulesJson: using SharedPreferences (file not found), length=${fromPrefs.length}")
        return fromPrefs
    }

    private fun readSettingsJson(): String {
        val file = File(filesDir(), SETTINGS_FILE)
        if (file.exists()) {
            try {
                val content = file.readText()
                if (content.isNotBlank()) return content
            } catch (e: Exception) {
                Log.e(TAG, "readSettingsJson: failed to read file", e)
            }
        }
        return "{}"
    }

    data class Rule(
        val id: String,
        val triggerText: String,
        val triggerTexts: List<String>,   // multi-trigger support
        val replyText: String,
        val replies: List<String>,         // multi-reply support
        val senderNames: List<String>,    // specific contacts (empty = all)
        val exactMatch: Boolean,
        val containsMatch: Boolean,
        val caseSensitive: Boolean,
        val isEnabled: Boolean,
        val isDefault: Boolean = false,
    ) {
        /** All active trigger texts: uses triggerTexts when populated, else falls back to triggerText */
        val effectiveTriggers: List<String>
            get() = if (triggerTexts.isNotEmpty()) triggerTexts else listOf(triggerText)

        /** All active reply texts: uses replies when populated, else falls back to replyText */
        val effectiveReplies: List<String>
            get() = if (replies.isNotEmpty()) replies else listOf(replyText)

        /** Return a random reply from the effective replies list */
        fun randomReply(): String = effectiveReplies.random()
    }

    /** Normalize a message: trim, remove trailing punctuation, lowercase. */
    private fun normalizeMessage(text: String): String {
        var result = text.trim()
        // Remove trailing punctuation: ? ! . , ; : ) ] }
        result = result.replace(Regex("[?!,;:\\)\\]\\}]+$"), "")
        return result.trim().lowercase()
    }

    /** Load all enabled rules */
    fun getEnabledRules(): List<Rule> {
        val json = readRulesJson()
        return try {
            val array = JSONArray(json)
            val all = (0 until array.length()).map { array.getJSONObject(it) }
            val enabled = all.filter { it.optBoolean("isEnabled", true) }
            Log.d(TAG, "getEnabledRules: total=${all.size}, enabled=${enabled.size}")
            enabled.map {
                val rawTriggers = it.optJSONArray("triggerTexts")
                val triggerList = if (rawTriggers != null) {
                    (0 until rawTriggers.length()).map { i -> rawTriggers.getString(i) }
                } else emptyList()
                val rawReplies = it.optJSONArray("replies")
                val replyList = if (rawReplies != null) {
                    (0 until rawReplies.length()).map { i -> rawReplies.getString(i) }
                } else emptyList()
                val rawSenders = it.optJSONArray("senderNames")
                val senderList = if (rawSenders != null) {
                    (0 until rawSenders.length()).map { i -> rawSenders.getString(i) }
                } else emptyList()
                Rule(
                    id = it.optString("id", ""),
                    triggerText = it.optString("triggerText", ""),
                    triggerTexts = triggerList,
                    replyText = it.optString("replyText", ""),
                    replies = replyList,
                    senderNames = senderList,
                    exactMatch = it.optBoolean("exactMatch", true),
                    containsMatch = it.optBoolean("containsMatch", false),
                    caseSensitive = it.optBoolean("caseSensitive", false),
                    isEnabled = it.optBoolean("isEnabled", true),
                    isDefault = it.optBoolean("isDefault", false),
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse rules: $e")
            emptyList()
        }
    }

    /** Whether rules or AI auto-reply may run for this sender (contact filter). */
    fun isSenderAllowedForAutoReply(sender: String?): Boolean {
        if (sender.isNullOrBlank()) return true
        val allowed = ContactIdentifier.isSenderAllowedForAutoReply(
            sender = sender,
            whitelistEnabled = isContactWhitelistEnabled(),
            whitelist = getContactWhitelist(),
            blacklist = getContactBlacklist(),
        )
        if (!allowed) {
            Log.d(TAG, "isSenderAllowedForAutoReply: blocked sender '$sender'")
        }
        return allowed
    }

    /** Find the first matching rule for a given message and sender */
    fun findMatchingRule(message: String, sender: String? = null): Rule? {
        if (sender != null && !isSenderAllowedForAutoReply(sender)) {
            return null
        }

        val rules = getEnabledRules()
        Log.d(TAG, "findMatchingRule: '${message.take(60)}' from '$sender' vs ${rules.size} rules")
        val match = rules.firstOrNull { it.matches(message, sender) }
        if (match != null) Log.d(TAG, "findMatchingRule: MATCHED '${match.triggerText}'")
        else Log.d(TAG, "findMatchingRule: no match")
        return match
    }

    /** Check if a message matches a rule (any trigger matches), optionally filtering by sender */
    private fun Rule.matches(message: String, sender: String? = null): Boolean {
        // Sender filter: if senderNames is set, sender must be in the list
        if (senderNames.isNotEmpty()) {
            if (sender == null) return false
            val matched = senderNames.any { it.equals(sender, ignoreCase = true) }
            if (!matched) return false
        }

        val msg = if (caseSensitive) message else normalizeMessage(message)
        return effectiveTriggers.any { t ->
            val trigger = if (caseSensitive) t else normalizeMessage(t)
            when {
                exactMatch    -> msg == trigger
                containsMatch -> msg.contains(trigger)
                else          -> false
            }
        }
    }

    /** Check if a message was sent by this app (self-reply guard) */
    fun isSelfSentMessage(message: String, sender: String = ""): Boolean {
        val isSelf = SelfSentReplyGuard.isSelfSentMessage(message, sender, sentReplyTexts)
        if (isSelf) {
            Log.d(TAG, "isSelfSentMessage: sender='$sender' message='$message'")
        }
        return isSelf
    }

    // ── Settings ─────────────────────────────────────────────────────────────

    fun isMasterEnabled(): Boolean {
        // Try file first
        try {
            val json = readSettingsJson()
            if (json != "{}") {
                return JSONObject(json).optBoolean("masterEnabled", true)
            }
        } catch (_: Exception) {}
        return prefs.getBoolean(KEY_MASTER_ENABLED, true)
    }

    fun isAppEnabled(packageName: String): Boolean {
        if (!isMasterEnabled()) return false
        try {
            val json = readSettingsJson()
            if (json != "{}") {
                val obj = JSONObject(json)
                return when (packageName) {
                    "com.whatsapp" -> obj.optBoolean("whatsappEnabled", true)
                    "com.instagram.android" -> obj.optBoolean("instagramEnabled", true)
                    else -> false
                }
            }
        } catch (_: Exception) {}
        return when (packageName) {
            "com.whatsapp" -> prefs.getBoolean(KEY_WHATSAPP_ENABLED, true)
            "com.instagram.android" -> prefs.getBoolean(KEY_INSTAGRAM_ENABLED, true)
            else -> false
        }
    }

    fun shouldIgnoreGroupChats(): Boolean {
        try {
            val json = readSettingsJson()
            if (json != "{}") return JSONObject(json).optBoolean("ignoreGroupChats", true)
        } catch (_: Exception) {}
        return prefs.getBoolean(KEY_IGNORE_GROUP_CHATS, false)
    }

    fun getReplyDelayMs(): Long {
        val minSec: Int
        val maxSec: Int
        try {
            val json = readSettingsJson()
            if (json != "{}") {
                val obj = JSONObject(json)
                minSec = maxOf(obj.optInt("minReplyDelaySeconds", 0), 0)
                maxSec = maxOf(obj.optInt("maxReplyDelaySeconds", 10), minSec)
                val delay = if (minSec >= maxSec) minSec else Random.nextInt(minSec, maxSec + 1)
                return delay * 1000L
            }
        } catch (_: Exception) {}
        val fallbackMin = maxOf(prefs.getInt(KEY_MIN_REPLY_DELAY_SECONDS, 0), 0)
        val fallbackMax = maxOf(prefs.getInt(KEY_MAX_REPLY_DELAY_SECONDS, 10), fallbackMin)
        val delay = if (fallbackMin >= fallbackMax) fallbackMin else Random.nextInt(fallbackMin, fallbackMax + 1)
        return delay * 1000L
    }

    fun shouldPreventDuplicates(): Boolean {
        try {
            val json = readSettingsJson()
            if (json != "{}") return JSONObject(json).optBoolean("preventDuplicateReplies", true)
        } catch (_: Exception) {}
        return prefs.getBoolean(KEY_PREVENT_DUPLICATES, true)
    }

    fun isConfirmBeforeReplyEnabled(): Boolean {
        try {
            val json = readSettingsJson()
            if (json != "{}") return JSONObject(json).optBoolean("confirmBeforeReply", false)
        } catch (_: Exception) {}
        return prefs.getBoolean("confirm_before_reply", false)
    }

    fun isContactWhitelistEnabled(): Boolean {
        try {
            val json = readSettingsJson()
            if (json != "{}") return JSONObject(json).optBoolean("contactWhitelistEnabled", false)
        } catch (_: Exception) {}
        return prefs.getBoolean(KEY_CONTACT_WHITELIST_ENABLED, false)
    }

    fun getContactWhitelist(): List<String> {
        try {
            val json = readSettingsJson()
            if (json != "{}") {
                val arr = JSONObject(json).optJSONArray("contactWhitelist")
                if (arr != null) return (0 until arr.length()).map { arr.getString(it) }
            }
        } catch (_: Exception) {}
        return try {
            val raw = prefs.getString(KEY_CONTACT_WHITELIST, "[]") ?: "[]"
            val arr = JSONArray(raw)
            (0 until arr.length()).map { arr.getString(it) }
        } catch (_: Exception) { emptyList() }
    }

    fun getContactBlacklist(): List<String> {
        try {
            val json = readSettingsJson()
            if (json != "{}") {
                val arr = JSONObject(json).optJSONArray("contactBlacklist")
                if (arr != null) return (0 until arr.length()).map { arr.getString(it) }
            }
        } catch (_: Exception) {}
        return try {
            val raw = prefs.getString(KEY_CONTACT_BLACKLIST, "[]") ?: "[]"
            val arr = JSONArray(raw)
            (0 until arr.length()).map { arr.getString(it) }
        } catch (_: Exception) { emptyList() }
    }

    fun isWithinScheduleWindow(): Boolean {
        try {
            val json = readSettingsJson()
            if (json != "{}") {
                val obj = JSONObject(json)
                val scheduleEnabled = obj.optBoolean("scheduleEnabled", false)
                if (!scheduleEnabled) return true

                val startHour = obj.optInt("scheduleStartHour", 8)
                val startMinute = obj.optInt("scheduleStartMinute", 0)
                val endHour = obj.optInt("scheduleEndHour", 22)
                val endMinute = obj.optInt("scheduleEndMinute", 0)

                val cal = Calendar.getInstance()
                val currentMinutes = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
                val startMinutes = startHour * 60 + startMinute
                val endMinutes = endHour * 60 + endMinute

                return if (startMinutes <= endMinutes) {
                    // Same-day window (e.g., 8:00 - 22:00)
                    currentMinutes in startMinutes..endMinutes
                } else {
                    // Overnight window (e.g., 22:00 - 6:00)
                    currentMinutes >= startMinutes || currentMinutes <= endMinutes
                }
            }
        } catch (_: Exception) {}
        return true
    }

    // ── AI Settings ───────────────────────────────────────────────────────

    fun isAiReplyEnabled(): Boolean {
        try {
            val json = readSettingsJson()
            if (json != "{}") return JSONObject(json).optBoolean("aiReplyEnabled", false)
        } catch (_: Exception) {}
        return prefs.getBoolean("ai_reply_enabled", false)
    }

    fun isFallbackToLocalEnabled(): Boolean {
        try {
            val json = readSettingsJson()
            if (json != "{}") return JSONObject(json).optBoolean("fallbackToLocalModel", true)
        } catch (_: Exception) {}
        return prefs.getBoolean("fallback_to_local_model", true)
    }

    fun getAiModelType(): String {
        try {
            val json = readSettingsJson()
            if (json != "{}") return JSONObject(json).optString("aiModelType", "cerebras_api")
        } catch (_: Exception) {}
        return prefs.getString("ai_model_type", "cerebras_api") ?: "cerebras_api"
    }

    fun getCerebrasApiKey(): String {
        try {
            val json = readSettingsJson()
            if (json != "{}") return JSONObject(json).optString("cerebrasApiKey", "")
        } catch (_: Exception) {}
        return prefs.getString("cerebras_api_key", "") ?: ""
    }

    fun getCerebrasModel(): String {
        try {
            val json = readSettingsJson()
            if (json != "{}") return JSONObject(json).optString("cerebrasModel", "llama-3.3-70b")
        } catch (_: Exception) {}
        return prefs.getString("cerebras_model", "llama-3.3-70b") ?: "llama-3.3-70b"
    }

    fun getGroqApiKey(): String {
        try {
            val json = readSettingsJson()
            if (json != "{}") return JSONObject(json).optString("groqApiKey", "")
        } catch (_: Exception) {}
        return prefs.getString("groq_api_key", "") ?: ""
    }

    fun getGroqModel(): String {
        try {
            val json = readSettingsJson()
            if (json != "{}") {
                return CloudAiModel.normalizeGroqModel(
                    JSONObject(json).optString("groqModel", CloudAiModel.DEFAULT_GROQ_MODEL)
                )
            }
        } catch (_: Exception) {}
        return CloudAiModel.normalizeGroqModel(
            prefs.getString("groq_model", CloudAiModel.DEFAULT_GROQ_MODEL)
        )
    }

    fun getGeminiApiKey(): String {
        try {
            val json = readSettingsJson()
            if (json != "{}") return JSONObject(json).optString("geminiApiKey", "")
        } catch (_: Exception) {}
        return prefs.getString("gemini_api_key", "") ?: ""
    }

    fun getGeminiModel(): String {
        try {
            val json = readSettingsJson()
            if (json != "{}") {
                return CloudAiModel.normalizeGeminiModel(
                    JSONObject(json).optString("geminiModel", CloudAiModel.DEFAULT_GEMINI_MODEL)
                )
            }
        } catch (_: Exception) {}
        return CloudAiModel.normalizeGeminiModel(
            prefs.getString("gemini_model", CloudAiModel.DEFAULT_GEMINI_MODEL)
        )
    }

    fun getDeepSeekServerUrl(): String {
        try {
            val json = readSettingsJson()
            if (json != "{}") return JSONObject(json).optString("gemmaLocalServerUrl", "")
        } catch (_: Exception) {}
        return prefs.getString("gemma_local_server_url", "") ?: ""
    }

    fun getDeepSeekModel(): String {
        try {
            val json = readSettingsJson()
            if (json != "{}") return JSONObject(json).optString("gemmaLocalModel", "llama_3_2_1b")
        } catch (_: Exception) {}
        return prefs.getString("gemma_local_model", "llama_3_2_1b") ?: "llama_3_2_1b"
    }

    fun getSelectedLocalModel(): String {
        try {
            val json = readSettingsJson()
            if (json != "{}") return JSONObject(json).optString("selectedLocalModel", "llama_3_2_1b")
        } catch (_: Exception) {}
        return prefs.getString("selected_local_model", "llama_3_2_1b") ?: "llama_3_2_1b"
    }

    // ── Busy Mode ─────────────────────────────────────────────────────────

    fun isBusyModeActive(): Boolean {
        try {
            val json = readSettingsJson()
            if (json != "{}") {
                val obj = JSONObject(json)
                val enabled = obj.optBoolean("busyModeEnabled", false)
                if (!enabled) return false
                val until = obj.optLong("busyUntilTimestamp", 0)
                return if (until > 0) System.currentTimeMillis() < until else true
            }
        } catch (_: Exception) {}
        return false
    }

    fun getBusyReplyText(): String {
        try {
            val json = readSettingsJson()
            if (json != "{}") {
                return JSONObject(json).optString("busyReplyText", "")
            }
        } catch (_: Exception) {}
        return ""
    }

    fun getAiSystemPrompt(): String {
        try {
            val json = readSettingsJson()
            if (json != "{}") return JSONObject(json).optString("aiSystemPrompt",
                "You are a friendly assistant. Reply naturally and helpfully to the message. Keep replies short and conversational.")
        } catch (_: Exception) {}
        return prefs.getString("ai_system_prompt",
            "You are a friendly assistant. Reply naturally and helpfully to the message. Keep replies short and conversational.") ?: ""
    }

    // ── AI Usage tracking ────────────────────────────────────────────────────

    fun saveAiUsage(
        provider: String,
        tokensUsed: Int,
        tokensRemaining: Int,
        tokensLimit: Int,
        resetInSeconds: Int,
        error: String?,
        requestsRemaining: Int? = null,
        requestsLimit: Int? = null,
        isLimitReached: Boolean = false,
    ) {
        prefs.edit()
            .putInt("ai_tokens_used", tokensUsed)
            .putInt("ai_tokens_remaining", tokensRemaining)
            .putInt("ai_tokens_limit", tokensLimit)
            .putInt("ai_reset_seconds", resetInSeconds)
            .putString("ai_usage_error", error ?: "")
            .putLong("ai_usage_timestamp", System.currentTimeMillis())
            .apply()
        if (provider.isNotBlank()) {
            recordProviderUsage(
                provider = provider,
                tokensUsed = tokensUsed,
                requestsRemaining = requestsRemaining,
                requestsLimit = requestsLimit,
                isLimitReached = isLimitReached,
                resetInSeconds = resetInSeconds,
                error = error,
            )
        }
        Log.d(TAG, "saveAiUsage: provider=$provider used=$tokensUsed, remaining=$tokensRemaining, limit=$tokensLimit, reqRemaining=$requestsRemaining, reqLimit=$requestsLimit, isLimitReached=$isLimitReached")
    }

    private fun recordProviderUsage(
        provider: String,
        tokensUsed: Int,
        requestsRemaining: Int? = null,
        requestsLimit: Int? = null,
        isLimitReached: Boolean = false,
        resetInSeconds: Int = 0,
        error: String? = null,
    ) {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val all = try {
            JSONObject(prefs.getString(KEY_AI_PROVIDER_STATS, "{}") ?: "{}")
        } catch (_: Exception) {
            JSONObject()
        }
        val providerStats = all.optJSONObject(provider) ?: JSONObject()
        if (providerStats.optString("date") != today) {
            providerStats.put("date", today)
            providerStats.put("requestsToday", 0)
            providerStats.put("tokensToday", 0)
            providerStats.put("isLimitReached", false)
            providerStats.remove("requestsRemaining")
            providerStats.remove("lastError")
        }
        if (tokensUsed > 0) {
            providerStats.put("requestsToday", providerStats.optInt("requestsToday", 0) + 1)
            providerStats.put("tokensToday", providerStats.optInt("tokensToday", 0) + tokensUsed)
        }
        if (requestsLimit != null && requestsLimit > 0) {
            providerStats.put("requestsLimit", requestsLimit)
        }
        if (requestsRemaining != null) {
            providerStats.put("requestsRemaining", requestsRemaining)
        }
        if (isLimitReached) {
            providerStats.put("isLimitReached", true)
            if (requestsRemaining == null) {
                providerStats.put("requestsRemaining", 0)
            }
        } else if (requestsRemaining != null && requestsRemaining > 0) {
            providerStats.put("isLimitReached", false)
        }
        if (resetInSeconds > 0) {
            providerStats.put("limitResetTimestamp", System.currentTimeMillis() + (resetInSeconds * 1000L))
        }
        if (!error.isNullOrBlank()) {
            providerStats.put("lastError", error)
        } else if (tokensUsed > 0 && !isLimitReached) {
            providerStats.remove("lastError")
        }
        all.put(provider, providerStats)
        prefs.edit().putString(KEY_AI_PROVIDER_STATS, all.toString()).apply()
    }

    fun getAiUsage(): Map<String, Any> {
        return mapOf(
            "tokensUsed" to prefs.getInt("ai_tokens_used", 0),
            "tokensRemaining" to prefs.getInt("ai_tokens_remaining", 0),
            "tokensLimit" to prefs.getInt("ai_tokens_limit", 0),
            "resetInSeconds" to prefs.getInt("ai_reset_seconds", 0),
            "error" to (prefs.getString("ai_usage_error", "") ?: ""),
            "timestamp" to prefs.getLong("ai_usage_timestamp", 0).toInt(),
            "providerStats" to getAiProviderStats(),
        )
    }

    fun getAiProviderStats(): Map<String, Map<String, Any>> {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val now = System.currentTimeMillis()
        val result = mutableMapOf<String, Map<String, Any>>()
        val all = try {
            JSONObject(prefs.getString(KEY_AI_PROVIDER_STATS, "{}") ?: "{}")
        } catch (_: Exception) {
            JSONObject()
        }
        for (key in all.keys()) {
            val provider = key ?: continue
            val obj = all.optJSONObject(provider) ?: continue
            if (obj.optString("date") != today) {
                result[provider] = mapOf(
                    "requestsToday" to 0,
                    "tokensToday" to 0,
                    "requestsLimit" to obj.optInt("requestsLimit", 0),
                    "requestsRemaining" to -1,
                    "isLimitReached" to false,
                    "limitResetTimestamp" to 0L,
                    "lastError" to "",
                )
            } else {
                val resetTs = obj.optLong("limitResetTimestamp", 0L)
                val isExpired = resetTs in 1..now
                val limitReached = if (isExpired) false else obj.optBoolean("isLimitReached", false)
                val remaining = if (limitReached) 0 else if (obj.has("requestsRemaining")) obj.optInt("requestsRemaining") else -1
                result[provider] = mapOf(
                    "requestsToday" to obj.optInt("requestsToday", 0),
                    "tokensToday" to obj.optInt("tokensToday", 0),
                    "requestsLimit" to obj.optInt("requestsLimit", 0),
                    "requestsRemaining" to remaining,
                    "isLimitReached" to limitReached,
                    "limitResetTimestamp" to resetTs,
                    "lastError" to obj.optString("lastError", ""),
                )
            }
        }
        return result
    }

    fun isAiLimitReached(engineType: String): Boolean {
        val customLimit = getAiReplyLimit(engineType)
        val stats = getAiProviderStats()[engineType]
        val requestsToday = (stats?.get("requestsToday") as? Number)?.toInt() ?: 0

        // 1. Check user-configured limit
        if (customLimit > 0 && requestsToday >= customLimit) {
            return true
        }

        // 2. Check live quota limit from API
        val isLimitReached = (stats?.get("isLimitReached") as? Boolean) == true
        if (isLimitReached) return true

        val remaining = (stats?.get("requestsRemaining") as? Number)?.toInt()
        if (remaining != null && remaining == 0) return true

        val requestsLimit = (stats?.get("requestsLimit") as? Number)?.toInt() ?: 0
        if (requestsLimit > 0 && requestsToday >= requestsLimit) return true

        return false
    }

    fun getAiReplyLimit(engineType: String): Int {
        try {
            val json = readSettingsJson()
            if (json != "{}") {
                val obj = JSONObject(json)
                return when (engineType) {
                    "cerebras_api" -> obj.optInt("cerebrasReplyLimit", 0)
                    "groq_api" -> obj.optInt("groqReplyLimit", 0)
                    "gemini_api" -> obj.optInt("geminiReplyLimit", 0)
                    "phi_local", "deepseek_local" -> obj.optInt("localReplyLimit", 0)
                    else -> 0
                }
            }
        } catch (_: Exception) {}
        return 0
    }

    // ── Duplicate tracking (in-memory, resets on service restart) ────────────

    private val recentReplies = mutableListOf<Triple<String, String, Long>>()
    private val dedupeWindowMs = 5 * 60 * 1000L // 5 minutes

    // All reply texts this app has sent (including AI replies), to detect self-sent messages
    private val sentReplyTexts = mutableSetOf<String>()
    // Track sent messages with timestamps for cleanup
    private val sentReplyTimestamps = mutableListOf<Pair<String, Long>>()

    fun wasReplyRecentlySent(sender: String, replyText: String): Boolean {
        val now = System.currentTimeMillis()
        recentReplies.removeAll { now - it.third > dedupeWindowMs }
        return recentReplies.any { it.first == sender && it.second == replyText }
    }

    fun recordReplySent(sender: String, replyText: String) {
        recentReplies.add(Triple(sender, replyText, System.currentTimeMillis()))
        // Track the reply text for self-detection
        sentReplyTexts.add(replyText.trim().lowercase())
        sentReplyTimestamps.add(Pair(replyText.trim().lowercase(), System.currentTimeMillis()))
        // Cleanup old entries (keep last 10 minutes of sent replies)
        val cutoff = System.currentTimeMillis() - 10 * 60 * 1000L
        sentReplyTimestamps.removeAll { it.second < cutoff }
        sentReplyTexts.retainAll { text ->
            sentReplyTimestamps.any { it.first == text }
        }
        Log.d(TAG, "recordReplySent: tracked ${sentReplyTexts.size} sent reply texts")
    }

    // ── Write helpers (called from Flutter sync via MethodChannel) ────────────

    fun saveRules(rulesJson: String) {
        try {
            val array = JSONArray(rulesJson) // validate JSON
            // Write to both file and SharedPreferences for redundancy
            File(filesDir(), RULES_FILE).writeText(rulesJson)
            prefs.edit().putString(KEY_RULES, rulesJson).commit()
            Log.d(TAG, "saveRules: saved ${array.length()} rules (file + prefs)")
        } catch (e: Exception) {
            Log.e(TAG, "saveRules failed: $e")
        }
    }

    fun saveSettings(json: String) {
        try {
            val obj = JSONObject(json)
            File(filesDir(), SETTINGS_FILE).writeText(json)
            prefs.edit()
                .putBoolean(KEY_MASTER_ENABLED, obj.optBoolean("masterEnabled", true))
                .putBoolean(KEY_WHATSAPP_ENABLED, obj.optBoolean("whatsappEnabled", true))
                .putBoolean(KEY_INSTAGRAM_ENABLED, obj.optBoolean("instagramEnabled", true))
                .putBoolean(KEY_IGNORE_GROUP_CHATS, obj.optBoolean("ignoreGroupChats", false))
                .putInt(KEY_MIN_REPLY_DELAY_SECONDS, obj.optInt("minReplyDelaySeconds", 0))
                .putInt(KEY_MAX_REPLY_DELAY_SECONDS, obj.optInt("maxReplyDelaySeconds", 10))
                .putBoolean(KEY_PREVENT_DUPLICATES, obj.optBoolean("preventDuplicateReplies", true))
                .putBoolean("ai_reply_enabled", obj.optBoolean("aiReplyEnabled", false))
                .putBoolean("fallback_to_local_model", obj.optBoolean("fallbackToLocalModel", true))
                .putString("ai_model_type", obj.optString("aiModelType", "cerebras_api"))
                .putString("cerebras_api_key", obj.optString("cerebrasApiKey", ""))
                .putString("cerebras_model", obj.optString("cerebrasModel", "llama-3.3-70b"))
                .putString("groq_api_key", obj.optString("groqApiKey", ""))
                .putString(
                    "groq_model",
                    CloudAiModel.normalizeGroqModel(obj.optString("groqModel", CloudAiModel.DEFAULT_GROQ_MODEL))
                )
                .putString("gemini_api_key", obj.optString("geminiApiKey", ""))
                .putString(
                    "gemini_model",
                    CloudAiModel.normalizeGeminiModel(
                        obj.optString("geminiModel", CloudAiModel.DEFAULT_GEMINI_MODEL)
                    )
                )
                .putString("ai_system_prompt", obj.optString("aiSystemPrompt",
                    "You are a friendly assistant. Reply naturally and helpfully to the message. Keep replies short and conversational."))
                .putBoolean("schedule_enabled", obj.optBoolean("scheduleEnabled", false))
                .putInt("schedule_start_hour", obj.optInt("scheduleStartHour", 8))
                .putInt("schedule_start_minute", obj.optInt("scheduleStartMinute", 0))
                .putInt("schedule_end_hour", obj.optInt("scheduleEndHour", 22))
                .putInt("schedule_end_minute", obj.optInt("scheduleEndMinute", 0))
                .putBoolean("confirm_before_reply", obj.optBoolean("confirmBeforeReply", false))
                .putBoolean("busy_mode_enabled", obj.optBoolean("busyModeEnabled", false))
                .putString("busy_reply_text", obj.optString("busyReplyText", ""))
                .putLong("busy_until_timestamp", obj.optLong("busyUntilTimestamp", 0))
                .putString("gemma_local_server_url", obj.optString("gemmaLocalServerUrl", ""))
                .putString("gemma_local_model", obj.optString("gemmaLocalModel", "llama_3_2_1b"))
                .putString("selected_local_model", obj.optString("selectedLocalModel", "llama_3_2_1b"))
                .putBoolean(KEY_CONTACT_WHITELIST_ENABLED, obj.optBoolean("contactWhitelistEnabled", false))
                .putString(KEY_CONTACT_WHITELIST, obj.optString("contactWhitelist", "[]"))
                .putString(KEY_CONTACT_BLACKLIST, obj.optString("contactBlacklist", "[]"))
                .commit()
            Log.d(TAG, "saveSettings: saved to file + prefs")
        } catch (e: Exception) {
            Log.e(TAG, "saveSettings failed: $e")
        }
    }
}
