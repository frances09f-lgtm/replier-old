package com.example.auto_reply_assistant.service

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.Calendar
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

    /** Find the first matching rule for a given message and sender */
    fun findMatchingRule(message: String, sender: String? = null): Rule? {
        // Blacklist check: skip if sender is blacklisted
        if (sender != null) {
            val blacklist = getContactBlacklist()
            if (blacklist.any { it.equals(sender, ignoreCase = true) }) {
                Log.d(TAG, "findMatchingRule: sender '$sender' is blacklisted")
                return null
            }
        }

        // Whitelist check: if enabled, sender must be in the whitelist
        if (sender != null && isContactWhitelistEnabled()) {
            val whitelist = getContactWhitelist()
            if (whitelist.isNotEmpty() && !whitelist.any { it.equals(sender, ignoreCase = true) }) {
                Log.d(TAG, "findMatchingRule: sender '$sender' not in whitelist")
                return null
            }
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
    fun isSelfSentMessage(message: String): Boolean {
        val lower = message.trim().lowercase()
        // Check against all sent replies (including AI-generated)
        if (lower in sentReplyTexts) {
            Log.d(TAG, "isSelfSentMessage: matched previously sent reply text")
            return true
        }
        return false
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
                minSec = maxOf(obj.optInt("minReplyDelaySeconds", 1), 1)
                maxSec = maxOf(obj.optInt("maxReplyDelaySeconds", 10), 1)
                val delay = if (minSec >= maxSec) minSec else Random.nextInt(minSec, maxSec + 1)
                return delay * 1000L
            }
        } catch (_: Exception) {}
        val fallbackMin = maxOf(prefs.getInt(KEY_MIN_REPLY_DELAY_SECONDS, 1), 1)
        val fallbackMax = maxOf(prefs.getInt(KEY_MAX_REPLY_DELAY_SECONDS, 10), 1)
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

    fun getAiModelType(): String {
        try {
            val json = readSettingsJson()
            if (json != "{}") return JSONObject(json).optString("aiModelType", "deepseek_local")
        } catch (_: Exception) {}
        return prefs.getString("ai_model_type", "deepseek_local") ?: "deepseek_local"
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

    fun saveAiUsage(tokensUsed: Int, tokensRemaining: Int, tokensLimit: Int, resetInSeconds: Int, error: String?) {
        prefs.edit()
            .putInt("ai_tokens_used", tokensUsed)
            .putInt("ai_tokens_remaining", tokensRemaining)
            .putInt("ai_tokens_limit", tokensLimit)
            .putInt("ai_reset_seconds", resetInSeconds)
            .putString("ai_usage_error", error ?: "")
            .putLong("ai_usage_timestamp", System.currentTimeMillis())
            .apply()
        Log.d(TAG, "saveAiUsage: used=$tokensUsed, remaining=$tokensRemaining, limit=$tokensLimit")
    }

    fun getAiUsage(): Map<String, Any> {
        return mapOf(
            "tokensUsed" to prefs.getInt("ai_tokens_used", 0),
            "tokensRemaining" to prefs.getInt("ai_tokens_remaining", 0),
            "tokensLimit" to prefs.getInt("ai_tokens_limit", 0),
            "resetInSeconds" to prefs.getInt("ai_reset_seconds", 0),
            "error" to (prefs.getString("ai_usage_error", "") ?: ""),
            "timestamp" to prefs.getLong("ai_usage_timestamp", 0).toInt()
        )
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
                .putString("ai_model_type", obj.optString("aiModelType", "deepseek_local"))
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
                .putString("gemma_local_model", obj.optString("gemmaLocalModel", "deepseek_1_5b"))
                .putString("selected_local_model", obj.optString("selectedLocalModel", "gemma_270m"))
                .putBoolean(KEY_CONTACT_WHITELIST_ENABLED, obj.optBoolean("contactWhitelistEnabled", false))
                .putString(KEY_CONTACT_WHITELIST, obj.optString("contactWhitelist", "[]"))
                .putString(KEY_CONTACT_BLACKLIST, obj.optString("contactBlacklist", "[]"))
                .putString("cerebras_api_key", obj.optString("cerebrasApiKey", ""))
                .putString("cerebras_model", obj.optString("cerebrasModel", "llama-3.3-70b"))
                .commit()
            Log.d(TAG, "saveSettings: saved to file + prefs")
        } catch (e: Exception) {
            Log.e(TAG, "saveSettings failed: $e")
        }
    }
}
