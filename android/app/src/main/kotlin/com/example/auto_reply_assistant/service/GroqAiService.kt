package com.example.auto_reply_assistant.service

import android.util.Log
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit

class GroqAiService {

    companion object {
        private const val TAG = "GroqAiService"
        private const val API_URL = "https://api.groq.com/openai/v1/chat/completions"
        private const val MODEL = "llama-3.3-70b-versatile"
    }

    data class AiUsage(
        val tokensUsed: Int = 0,
        val tokensRemaining: Int = 0,
        val tokensLimit: Int = 0,
        val resetInSeconds: Int = 0,
        val error: String? = null
    )

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    fun getAiReply(
        apiKey: String,
        senderName: String,
        incomingMessage: String,
        systemPrompt: String,
        conversationHistory: List<ConversationHistory.ChatMessage> = emptyList(),
        callback: (String?, AiUsage?) -> Unit
    ) {
        getAiReplyBatch(apiKey, senderName, listOf(incomingMessage), systemPrompt, conversationHistory, callback)
    }

    /**
     * Batch version: accepts multiple messages from the same sender and combines
     * them into a single user prompt so the AI can reply to all at once.
     */
    fun getAiReplyBatch(
        apiKey: String,
        senderName: String,
        incomingMessages: List<String>,
        systemPrompt: String,
        conversationHistory: List<ConversationHistory.ChatMessage> = emptyList(),
        callback: (String?, AiUsage?) -> Unit
    ) {
        val combinedMessage = if (incomingMessages.size == 1) {
            "Message from $senderName: ${incomingMessages[0]}"
        } else {
            val conversation = incomingMessages.joinToString("\n") { msg -> msg }
            "Messages from $senderName (read them as one conversation and reply accordingly):\n$conversation"
        }

        val messagesArray = JSONArray().apply {
            put(JSONObject().apply {
                put("role", "system")
                put("content", systemPrompt)
            })
            for (msg in conversationHistory) {
                put(JSONObject().apply {
                    put("role", msg.role)
                    put("content", if (msg.role == "user") "Message from $senderName: ${msg.content}" else msg.content)
                })
            }
            put(JSONObject().apply {
                put("role", "user")
                put("content", combinedMessage)
            })
        }

        val requestBody = JSONObject().apply {
            put("model", MODEL)
            put("messages", messagesArray)
            put("max_tokens", 150)
            put("temperature", 0.7)
        }

        val request = Request.Builder()
            .url(API_URL)
            .addHeader("Authorization", "Bearer $apiKey")
            .addHeader("Content-Type", "application/json")
            .post(requestBody.toString().toRequestBody("application/json".toMediaType()))
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e(TAG, "Groq API call failed", e)
                callback(null, null)
            }

            override fun onResponse(call: Call, response: Response) {
                response.use {
                    val usage = parseUsageHeaders(response)

                    if (!response.isSuccessful) {
                        val errorBody = response.body?.string() ?: ""
                        Log.e(TAG, "Groq API error: ${response.code} $errorBody")
                        val errorUsage = parseErrorBody(errorBody, response.code)
                        callback(null, errorUsage)
                        return
                    }

                    try {
                        val responseBody = response.body?.string() ?: ""
                        val json = JSONObject(responseBody)
                        val bodyUsage = parseUsageBody(json)
                        val finalUsage = if (usage.tokensLimit > 0) usage else bodyUsage

                        val choices = json.getJSONArray("choices")
                        if (choices.length() > 0) {
                            val content = choices.getJSONObject(0)
                                .getJSONObject("message")
                                .getString("content")
                                .trim()
                            callback(content, finalUsage)
                        } else {
                            callback(null, finalUsage)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to parse Groq response", e)
                        callback(null, usage)
                    }
                }
            }
        })
    }

    private fun parseUsageBody(json: JSONObject): AiUsage {
        return try {
            val usage = json.optJSONObject("usage")
            if (usage != null) {
                val promptTokens = usage.optInt("prompt_tokens", 0)
                val completionTokens = usage.optInt("completion_tokens", 0)
                val totalTokens = usage.optInt("total_tokens", promptTokens + completionTokens)
                Log.d(TAG, "Usage from body: prompt=$promptTokens, completion=$completionTokens, total=$totalTokens")
                AiUsage(
                    tokensUsed = totalTokens,
                    tokensRemaining = -1,
                    tokensLimit = -1,
                    resetInSeconds = 0
                )
            } else {
                AiUsage()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse usage from body", e)
            AiUsage()
        }
    }

    private fun parseUsageHeaders(response: Response): AiUsage {
        val limit = response.header("x-ratelimit-limit-tokens-minute")?.toIntOrNull()
            ?: response.header("x-ratelimit-limit-tokens")?.toIntOrNull() ?: 0
        val remaining = response.header("x-ratelimit-remaining-tokens-minute")?.toIntOrNull()
            ?: response.header("x-ratelimit-remaining-tokens")?.toIntOrNull() ?: 0
        val resetSeconds = (response.header("x-ratelimit-reset-tokens-minute")
            ?: response.header("x-ratelimit-reset-tokens"))?.let { header ->
            val match = Regex("(\\d+)(?:\\.\\d+)?s?").find(header)
            match?.groupValues?.get(1)?.toIntOrNull() ?: 0
        } ?: 0

        return AiUsage(
            tokensUsed = limit - remaining,
            tokensRemaining = remaining,
            tokensLimit = limit,
            resetInSeconds = resetSeconds
        )
    }

    private fun parseErrorBody(errorBody: String, statusCode: Int): AiUsage {
        return try {
            val json = JSONObject(errorBody)
            val error = json.getJSONObject("error")
            val message = error.getString("message")

            // Parse rate limit error: "Limit 100000, Used 99141, Requested 1848. Please try again in 14m14.496s."
            val limitMatch = Regex("Limit\\s+(\\d+)").find(message)
            val usedMatch = Regex("Used\\s+(\\d+)").find(message)
            val resetMatch = Regex("try again in (\\d+)m(\\d+\\.?\\d*)s").find(message)

            val limit = limitMatch?.groupValues?.get(1)?.toIntOrNull() ?: 0
            val used = usedMatch?.groupValues?.get(1)?.toIntOrNull() ?: 0
            val resetMinutes = resetMatch?.groupValues?.get(1)?.toIntOrNull() ?: 0
            val resetSeconds = resetMatch?.groupValues?.get(2)?.toDoubleOrNull()?.toInt() ?: 0

            AiUsage(
                tokensUsed = used,
                tokensRemaining = limit - used,
                tokensLimit = limit,
                resetInSeconds = resetMinutes * 60 + resetSeconds,
                error = message
            )
        } catch (e: Exception) {
            AiUsage(error = errorBody)
        }
    }
}
