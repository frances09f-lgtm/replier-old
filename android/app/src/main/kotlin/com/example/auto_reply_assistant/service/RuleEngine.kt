package com.example.auto_reply_assistant.service

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
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
        val exactMatch: Boolean,
        val containsMatch: Boolean,
        val caseSensitive: Boolean,
        val isEnabled: Boolean,
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
                Rule(
                    id = it.optString("id", ""),
                    triggerText = it.optString("triggerText", ""),
                    triggerTexts = triggerList,
                    replyText = it.optString("replyText", ""),
                    replies = replyList,
                    exactMatch = it.optBoolean("exactMatch", false),
                    containsMatch = it.optBoolean("containsMatch", true),
                    caseSensitive = it.optBoolean("caseSensitive", false),
                    isEnabled = it.optBoolean("isEnabled", true),
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse rules: $e")
            emptyList()
        }
    }

    /** Find the first matching rule for a given message */
    fun findMatchingRule(message: String): Rule? {
        val rules = getEnabledRules()
        Log.d(TAG, "findMatchingRule: '${message.take(60)}' vs ${rules.size} rules")
        val match = rules.firstOrNull { it.matches(message) }
        if (match != null) Log.d(TAG, "findMatchingRule: MATCHED '${match.triggerText}'")
        else Log.d(TAG, "findMatchingRule: no match")
        return match
    }

    /** Check if a message matches a rule (any trigger matches) */
    private fun Rule.matches(message: String): Boolean {
        val msg = if (caseSensitive) message else message.lowercase()
        return effectiveTriggers.any { t ->
            val trigger = if (caseSensitive) t else t.lowercase()
            when {
                exactMatch    -> msg.trim() == trigger.trim()
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
                minSec = obj.optInt("minReplyDelaySeconds", 0)
                maxSec = obj.optInt("maxReplyDelaySeconds", 10)
                val delay = if (minSec >= maxSec) minSec else Random.nextInt(minSec, maxSec + 1)
                return delay * 1000L
            }
        } catch (_: Exception) {}
        val fallbackMin = prefs.getInt(KEY_MIN_REPLY_DELAY_SECONDS, 0)
        val fallbackMax = prefs.getInt(KEY_MAX_REPLY_DELAY_SECONDS, 10)
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
            if (json != "{}") return JSONObject(json).optString("aiModelType", "groq")
        } catch (_: Exception) {}
        return prefs.getString("ai_model_type", "groq") ?: "groq"
    }

    fun getGroqApiKey(): String {
        try {
            val json = readSettingsJson()
            if (json != "{}") return JSONObject(json).optString("groqApiKey", "")
        } catch (_: Exception) {}
        return prefs.getString("groq_api_key", "") ?: ""
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
            if (json != "{}") return JSONObject(json).optString("geminiModel", "gemini-2.0-flash")
        } catch (_: Exception) {}
        return prefs.getString("gemini_model", "gemini-2.0-flash") ?: "gemini-2.0-flash"
    }

    fun getLocalModelPath(): String {
        try {
            val json = readSettingsJson()
            if (json != "{}") return JSONObject(json).optString("localModelPath", "")
        } catch (_: Exception) {}
        return prefs.getString("local_model_path", "") ?: ""
    }

    fun isLocalModelDownloaded(): Boolean {
        try {
            val json = readSettingsJson()
            if (json != "{}") return JSONObject(json).optBoolean("localModelDownloaded", false)
        } catch (_: Exception) {}
        return prefs.getBoolean("local_model_downloaded", false)
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
                .putString("ai_model_type", obj.optString("aiModelType", "groq"))
                .putString("groq_api_key", obj.optString("groqApiKey", ""))
                .putString("gemini_api_key", obj.optString("geminiApiKey", ""))
                .putString("gemini_model", obj.optString("geminiModel", "gemini-2.0-flash"))
                .putString("local_model_path", obj.optString("localModelPath", ""))
                .putBoolean("local_model_downloaded", obj.optBoolean("localModelDownloaded", false))
                .putString("ai_system_prompt", obj.optString("aiSystemPrompt",
                    "You are a friendly assistant. Reply naturally and helpfully to the message. Keep replies short and conversational."))
                .commit()
            Log.d(TAG, "saveSettings: saved to file + prefs")
        } catch (e: Exception) {
            Log.e(TAG, "saveSettings failed: $e")
        }
    }
}
