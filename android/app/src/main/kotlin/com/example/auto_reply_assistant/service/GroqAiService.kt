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
        callback: (String?) -> Unit
    ) {
        val messagesArray = JSONArray().apply {
            put(JSONObject().apply {
                put("role", "system")
                put("content", systemPrompt)
            })
            put(JSONObject().apply {
                put("role", "user")
                put("content", "Message from $senderName: $incomingMessage")
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
                callback(null)
            }

            override fun onResponse(call: Call, response: Response) {
                response.use {
                    if (!response.isSuccessful) {
                        Log.e(TAG, "Groq API error: ${response.code} ${response.body?.string()}")
                        callback(null)
                        return
                    }

                    try {
                        val responseBody = response.body?.string() ?: ""
                        val json = JSONObject(responseBody)
                        val choices = json.getJSONArray("choices")
                        if (choices.length() > 0) {
                            val content = choices.getJSONObject(0)
                                .getJSONObject("message")
                                .getString("content")
                                .trim()
                            callback(content)
                        } else {
                            callback(null)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to parse Groq response", e)
                        callback(null)
                    }
                }
            }
        })
    }
}
