package com.example.auto_reply_assistant.service

import android.content.Context
import android.util.Log
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit

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
        const val KEY_REPLY_DELAY_SECONDS = "reply_delay_seconds"
        const val KEY_PREVENT_DUPLICATES = "prevent_duplicate_replies"
        const val KEY_AI_ENABLED = "ai_enabled"
        const val KEY_GROQ_API_KEY = "groq_api_key"
        const val KEY_AI_MODEL = "ai_model"
        const val KEY_AI_SYSTEM_PROMPT = "ai_system_prompt"

        private const val RULES_FILE = "auto_reply_rules.json"
        private const val SETTINGS_FILE = "auto_reply_settings.json"
        private const val GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions"
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
        val exactMatch: Boolean,
        val containsMatch: Boolean,
        val caseSensitive: Boolean,
        val isEnabled: Boolean,
        val isAiPowered: Boolean = false,
    ) {
        /** All active trigger texts: uses triggerTexts when populated, else falls back to triggerText */
        val effectiveTriggers: List<String>
            get() = if (triggerTexts.isNotEmpty()) triggerTexts else listOf(triggerText)
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
                Rule(
                    id = it.optString("id", ""),
                    triggerText = it.optString("triggerText", ""),
                    triggerTexts = triggerList,
                    replyText = it.optString("replyText", ""),
                    exactMatch = it.optBoolean("exactMatch", false),
                    containsMatch = it.optBoolean("containsMatch", true),
                    caseSensitive = it.optBoolean("caseSensitive", false),
                    isEnabled = it.optBoolean("isEnabled", true),
                    isAiPowered = it.optBoolean("isAiPowered", false),
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
        val rules = getEnabledRules()
        val lower = message.trim().lowercase()
        return rules.any { it.replyText.trim().lowercase() == lower }
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
            if (json != "{}") return JSONObject(json).optBoolean("ignoreGroupChats", false)
        } catch (_: Exception) {}
        return prefs.getBoolean(KEY_IGNORE_GROUP_CHATS, false)
    }

    fun getReplyDelayMs(): Long {
        try {
            val json = readSettingsJson()
            if (json != "{}") return JSONObject(json).optInt("replyDelaySeconds", 0) * 1000L
        } catch (_: Exception) {}
        return prefs.getInt(KEY_REPLY_DELAY_SECONDS, 0) * 1000L
    }

    fun shouldPreventDuplicates(): Boolean {
        try {
            val json = readSettingsJson()
            if (json != "{}") return JSONObject(json).optBoolean("preventDuplicateReplies", true)
        } catch (_: Exception) {}
        return prefs.getBoolean(KEY_PREVENT_DUPLICATES, true)
    }

    fun isAiEnabled(): Boolean {
        try {
            val json = readSettingsJson()
            if (json != "{}") return JSONObject(json).optBoolean("aiEnabled", false)
        } catch (_: Exception) {}
        return prefs.getBoolean(KEY_AI_ENABLED, false)
    }

    fun getGroqApiKey(): String? {
        try {
            val json = readSettingsJson()
            if (json != "{}") {
                val key = JSONObject(json).optString("groqApiKey", null)
                if (key != null && key.isNotEmpty()) return key
            }
        } catch (_: Exception) {}
        return prefs.getString(KEY_GROQ_API_KEY, null)
    }

    fun getAiModel(): String {
        try {
            val json = readSettingsJson()
            if (json != "{}") {
                val model = JSONObject(json).optString("aiModel", null)
                if (model != null && model.isNotEmpty()) return model
            }
        } catch (_: Exception) {}
        return prefs.getString(KEY_AI_MODEL, "llama-3.1-8b-instant") ?: "llama-3.1-8b-instant"
    }

    fun getAiSystemPrompt(): String {
        try {
            val json = readSettingsJson()
            if (json != "{}") {
                val prompt = JSONObject(json).optString("aiSystemPrompt", null)
                if (prompt != null && prompt.isNotEmpty()) return prompt
            }
        } catch (_: Exception) {}
        return prefs.getString(KEY_AI_SYSTEM_PROMPT, 
            "You are a helpful auto-reply assistant. Keep responses brief, friendly, and conversational. Respond as if you are the person receiving the message."
        ) ?: "You are a helpful auto-reply assistant. Keep responses brief, friendly, and conversational. Respond as if you are the person receiving the message."
    }

    // ── Duplicate tracking (in-memory, resets on service restart) ────────────

    private val recentReplies = mutableListOf<Triple<String, String, Long>>()
    private val dedupeWindowMs = 5 * 60 * 1000L // 5 minutes

    fun wasReplyRecentlySent(sender: String, replyText: String): Boolean {
        val now = System.currentTimeMillis()
        recentReplies.removeAll { now - it.third > dedupeWindowMs }
        return recentReplies.any { it.first == sender && it.second == replyText }
    }

    fun recordReplySent(sender: String, replyText: String) {
        recentReplies.add(Triple(sender, replyText, System.currentTimeMillis()))
    }

    // ── AI Reply Generation ─────────────────────────────────────────────────────

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .writeTimeout(10, TimeUnit.SECONDS)
        .build()

    /**
     * Generate an AI reply using Groq API
     * Returns null if AI is disabled or API call fails
     */
    fun generateAiReply(message: String, senderName: String? = null, personalityHint: String? = null): String? {
        if (!isAiEnabled()) {
            Log.d(TAG, "AI is disabled in settings")
            return null
        }

        val apiKey = getGroqApiKey()
        if (apiKey.isNullOrEmpty()) {
            Log.d(TAG, "Groq API key not configured")
            return null
        }

        val model = getAiModel()
        val systemPrompt = if (personalityHint != null && personalityHint.isNotEmpty()) {
            "$personalityHint ${getAiSystemPrompt()}"
        } else {
            getAiSystemPrompt()
        }

        try {
            val messagesJson = JSONArray()
            messagesJson.put(JSONObject().apply {
                put("role", "system")
                put("content", systemPrompt)
            })

            val userMessage = if (senderName != null && senderName.isNotEmpty()) {
                "Message from $senderName: $message"
            } else {
                message
            }
            messagesJson.put(JSONObject().apply {
                put("role", "user")
                put("content", userMessage)
            })

            val requestBody = JSONObject().apply {
                put("model", model)
                put("messages", messagesJson)
                put("max_tokens", 150)
                put("temperature", 0.7)
                put("top_p", 0.9)
            }

            val mediaType = "application/json".toMediaType()
            val body = requestBody.toString().toRequestBody(mediaType)

            val request = Request.Builder()
                .url(GROQ_API_URL)
                .addHeader("Authorization", "Bearer $apiKey")
                .addHeader("Content-Type", "application/json")
                .post(body)
                .build()

            Log.d(TAG, "Calling Groq API with model: $model")

            httpClient.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    Log.e(TAG, "Groq API error: ${response.code}")
                    return null
                }

                val responseBody = response.body?.string()
                if (responseBody != null) {
                    val jsonResponse = JSONObject(responseBody)
                    val choices = jsonResponse.optJSONArray("choices")
                    if (choices != null && choices.length() > 0) {
                        val firstChoice = choices.getJSONObject(0)
                        val messageObj = firstChoice.getJSONObject("message")
                        val reply = messageObj.optString("content", "").trim()
                        Log.d(TAG, "AI generated reply: '${reply.take(50)}...'")
                        return reply
                    }
                }
            }
        } catch (e: IOException) {
            Log.e(TAG, "Network error calling Groq API", e)
        } catch (e: Exception) {
            Log.e(TAG, "Error generating AI reply", e)
        }

        return null
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
            // Write to file
            File(filesDir(), SETTINGS_FILE).writeText(json)
            // Write to SharedPreferences
            prefs.edit()
                .putBoolean(KEY_MASTER_ENABLED, obj.optBoolean("masterEnabled", true))
                .putBoolean(KEY_WHATSAPP_ENABLED, obj.optBoolean("whatsappEnabled", true))
                .putBoolean(KEY_INSTAGRAM_ENABLED, obj.optBoolean("instagramEnabled", true))
                .putBoolean(KEY_IGNORE_GROUP_CHATS, obj.optBoolean("ignoreGroupChats", false))
                .putInt(KEY_REPLY_DELAY_SECONDS, obj.optInt("replyDelaySeconds", 0))
                .putBoolean(KEY_PREVENT_DUPLICATES, obj.optBoolean("preventDuplicateReplies", true))
                .putBoolean(KEY_AI_ENABLED, obj.optBoolean("aiEnabled", false))
                .putString(KEY_GROQ_API_KEY, obj.optString("groqApiKey", null))
                .putString(KEY_AI_MODEL, obj.optString("aiModel", "llama-3.1-8b-instant"))
                .putString(KEY_AI_SYSTEM_PROMPT, obj.optString("aiSystemPrompt", 
                    "You are a helpful auto-reply assistant. Keep responses brief, friendly, and conversational. Respond as if you are the person receiving the message."))
                .commit()
            Log.d(TAG, "saveSettings: saved to file + prefs")
        } catch (e: Exception) {
            Log.e(TAG, "saveSettings failed: $e")
        }
    }
}
