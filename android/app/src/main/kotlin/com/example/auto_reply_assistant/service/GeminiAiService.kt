package com.example.auto_reply_assistant.service

import android.util.Log
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit

class GeminiAiService {

    companion object {
        private const val TAG = "GeminiAiService"
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
        model: String,
        senderName: String,
        incomingMessage: String,
        systemPrompt: String,
        callback: (String?, AiUsage?) -> Unit
    ) {
        val contentsArray = JSONArray().apply {
            put(JSONObject().apply {
                put("role", "user")
                put("parts", JSONArray().apply {
                    put(JSONObject().apply {
                        put("text", "Message from $senderName: $incomingMessage")
                    })
                })
            })
        }

        val systemInstruction = JSONObject().apply {
            put("parts", JSONArray().apply {
                put(JSONObject().apply {
                    put("text", systemPrompt)
                })
            })
        }

        val requestBody = JSONObject().apply {
            put("contents", contentsArray)
            put("systemInstruction", systemInstruction)
            put("generationConfig", JSONObject().apply {
                put("maxOutputTokens", 150)
                put("temperature", 0.7)
            })
        }

        val url = "https://generativelanguage.googleapis.com/v1/models/$model:generateContent?key=$apiKey"

        val request = Request.Builder()
            .url(url)
            .addHeader("Content-Type", "application/json")
            .post(requestBody.toString().toRequestBody("application/json".toMediaType()))
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e(TAG, "Gemini API call failed", e)
                callback(null, null)
            }

            override fun onResponse(call: Call, response: Response) {
                response.use {
                    if (!response.isSuccessful) {
                        val errorBody = response.body?.string() ?: ""
                        Log.e(TAG, "Gemini API error: ${response.code}")
                        val errorUsage = parseErrorBody(errorBody, response.code)
                        callback(null, errorUsage)
                        return
                    }

                    try {
                        val responseBody = response.body?.string() ?: ""
                        val json = JSONObject(responseBody)

                        // Parse usage metadata if present
                        val usage = if (json.has("usageMetadata")) {
                            val meta = json.getJSONObject("usageMetadata")
                            AiUsage(
                                tokensUsed = meta.optInt("totalTokenCount", 0),
                                tokensRemaining = 0,
                                tokensLimit = 0
                            )
                        } else {
                            AiUsage()
                        }

                        val candidates = json.getJSONArray("candidates")
                        if (candidates.length() > 0) {
                            val candidate = candidates.getJSONObject(0)

                            // Check for blocked response
                            if (candidate.has("finishReason") &&
                                candidate.getString("finishReason") == "SAFETY") {
                                callback(null, usage.copy(error = "Response blocked by safety filters"))
                                return@use
                            }

                            val content = candidate
                                .getJSONObject("content")
                                .getJSONArray("parts")
                                .getJSONObject(0)
                                .getString("text")
                                .trim()
                            callback(content, usage)
                        } else {
                            callback(null, usage)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to parse Gemini response", e)
                        callback(null, null)
                    }
                }
            }
        })
    }

    private fun parseErrorBody(errorBody: String, statusCode: Int): AiUsage {
        return try {
            val json = JSONObject(errorBody)
            val error = json.getJSONObject("error")

            // Parse retry delay and quota info from details
            var retrySeconds = 0
            val quotaMetrics = mutableListOf<String>()

            if (error.has("details")) {
                val details = error.getJSONArray("details")
                for (i in 0 until details.length()) {
                    val detail = details.getJSONObject(i)
                    val detailType = detail.optString("@type", "")

                    when (detailType) {
                        "type.googleapis.com/google.rpc.RetryInfo" -> {
                            val retryDelay = detail.optString("retryDelay", "")
                            val match = Regex("(\\d+)").find(retryDelay)
                            retrySeconds = match?.groupValues?.get(0)?.toIntOrNull() ?: 0
                        }
                        "type.googleapis.com/google.rpc.QuotaFailure" -> {
                            if (detail.has("violations")) {
                                val violations = detail.getJSONArray("violations")
                                for (j in 0 until violations.length()) {
                                    val v = violations.getJSONObject(j)
                                    val metric = v.optString("quotaMetric", "")
                                    if (metric.isNotEmpty()) {
                                        quotaMetrics.add(metric.substringAfterLast("/"))
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Build user-friendly error message
            val message = error.optString("message", "")
            val hasZeroLimit = message.contains("limit: 0")
            val hasRetryInMessage = Regex("retry in [\\d.]+s", RegexOption.IGNORE_CASE).containsMatchIn(message)

            val displayMessage = when {
                statusCode == 429 && hasZeroLimit -> {
                    "Gemini API key has zero quota. Create a new free key at aistudio.google.com/apikey or enable billing in Google Cloud Console."
                }
                statusCode == 429 && hasRetryInMessage -> {
                    val retryPart = if (retrySeconds > 0) " Retry in ${retrySeconds}s." else ""
                    "Rate limit exceeded.$retryPart"
                }
                statusCode == 429 -> {
                    val retryPart = if (retrySeconds > 0) " Retry in ${retrySeconds}s." else ""
                    val quotaPart = if (quotaMetrics.isNotEmpty()) {
                        " (${quotaMetrics.joinToString(", ")})"
                    } else ""
                    "Rate limit exceeded$quotaPart.$retryPart"
                }
                statusCode == 403 -> "API key invalid or access denied. Create a new key at aistudio.google.com/apikey."
                statusCode == 400 -> "Invalid request."
                else -> message.ifEmpty { "Unknown error ($statusCode)" }
            }

            Log.d(TAG, "Parsed error: $displayMessage (retry=${retrySeconds}s)")

            AiUsage(
                resetInSeconds = retrySeconds,
                error = displayMessage
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse error body", e)
            AiUsage(error = "API error ($statusCode)")
        }
    }
}
