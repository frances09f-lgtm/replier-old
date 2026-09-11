package com.example.auto_reply_assistant.service

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import dev.ffmpegkit.llama.Llama
import dev.ffmpegkit.llama.LlamaConfig
import dev.ffmpegkit.llama.LlamaModel
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeoutOrNull
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class PhiLocalService private constructor(private val context: Context) {

    companion object {
        private const val TAG = "PhiLocalService"

        @Volatile
        private var instance: PhiLocalService? = null

        fun getInstance(context: Context): PhiLocalService {
            return instance ?: synchronized(this) {
                instance ?: PhiLocalService(context.applicationContext).also { instance = it }
            }
        }

        data class ModelConfig(
            val id: String,
            val displayName: String,
            val filename: String,
            val url: String,
            val sizeBytes: Long,
            val description: String,
            val threads: Int = 4,
            val contextSize: Int = 2048,
        )

        /**
         * Data class for Cerebras API configuration.
         * Manages API endpoint, model name, and timeout settings.
         * API key is stored separately in SharedPreferences for security.
         */
        data class CerebrasConfig(
            val apiKey: String = "",
            val apiUrl: String = "https://api.cerebras.ai/v1/chat/completions",
            val model: String = "cerebras-instant",
            val timeout: Long = 15_000L,
        )

        val MODEL_REGISTRY = mapOf(
            "llama_3_2_1b" to ModelConfig(
                id = "llama_3_2_1b",
                displayName = "Llama 3.2 1B Instruct",
                filename = "llama-3.2-1b-instruct-q4_k_m.gguf",
                url = "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf",
                sizeBytes = 850_000_000L,
                description = "~800MB, blazing fast for basic replies",
                threads = 4,
                contextSize = 4096,
            ),
            "llama_3_2_3b" to ModelConfig(
                id = "llama_3_2_3b",
                displayName = "Llama 3.2 3B Instruct",
                filename = "llama-3.2-3b-instruct-q4_k_m.gguf",
                url = "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf",
                sizeBytes = 2_100_000_000L,
                description = "~2GB, highly intelligent, fits comfortably in RAM",
                threads = 4,
                contextSize = 4096,
            ),
        )

        private val fallbackReplies = listOf(
            "Thanks for your message!",
            "Got it, thanks!",
            "I'll get back to you soon.",
            "Noted, thank you!",
            "Thanks!",
            "Okay, thanks!",
        )
    }

    data class AiUsage(
        val tokensUsed: Int = 0,
        val tokensRemaining: Int = 0,
        val tokensLimit: Int = 0,
        val resetInSeconds: Int = 0,
        val error: String? = null,
    )

    private val loadedModels = ConcurrentHashMap<String, LlamaModel>()
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val downloadProgressMap = ConcurrentHashMap<String, Int>()
    private val downloadingMap = ConcurrentHashMap<String, Boolean>()

    // Cerebras configuration management
    private var currentCerebrasConfig = Companion.CerebrasConfig()
    private val sharedPreferences: SharedPreferences by lazy {
        context.getSharedPreferences("cerebras_config", Context.MODE_PRIVATE)
    }

    init {
        // Load saved API key on initialization
        loadCerebrasApiKey()
    }

    fun getModelConfig(modelId: String): ModelConfig? = MODEL_REGISTRY[modelId]

    fun isModelAvailable(modelId: String): Boolean {
        val config = MODEL_REGISTRY[modelId] ?: return false
        val f = getModelFile(config)
        return f.exists() && f.length() > config.sizeBytes / 2
    }

    fun getModelFile(config: ModelConfig): File = File(context.filesDir, config.filename)

    fun isDownloading(modelId: String): Boolean = downloadingMap[modelId] == true

    fun getDownloadProgress(modelId: String): Int = downloadProgressMap[modelId] ?: 0

    fun downloadModel(
        modelId: String,
        onProgress: ((Int) -> Unit)? = null,
        onComplete: ((Boolean, String?) -> Unit)? = null
    ) {
        val config = MODEL_REGISTRY[modelId]
        if (config == null) {
            onComplete?.invoke(false, "Unknown model: $modelId")
            return
        }
        if (downloadingMap[modelId] == true) {
            onComplete?.invoke(false, "Already downloading")
            return
        }
        if (isModelAvailable(modelId)) {
            onComplete?.invoke(true, null)
            return
        }

        downloadingMap[modelId] = true
        downloadProgressMap[modelId] = 0

        executor.execute {
            var conn: HttpURLConnection? = null
            try {
                val url = URL(config.url)
                conn = url.openConnection() as HttpURLConnection
                conn.connectTimeout = 30_000
                conn.readTimeout = 120_000
                conn.connect()

                val totalSize = conn.contentLength.toLong().coerceAtLeast(config.sizeBytes)
                val input = conn.inputStream
                val output = FileOutputStream(getModelFile(config))

                val buffer = ByteArray(8192)
                var bytesRead: Int
                var totalRead = 0L

                while (input.read(buffer).also { bytesRead = it } != -1) {
                    output.write(buffer, 0, bytesRead)
                    totalRead += bytesRead
                    val progress = ((totalRead * 100) / totalSize).toInt().coerceIn(0, 100)
                    if (progress != (downloadProgressMap[modelId] ?: 0)) {
                        downloadProgressMap[modelId] = progress
                        onProgress?.invoke(progress)
                    }
                }

                output.flush()
                output.close()
                input.close()

                val file = getModelFile(config)
                if (file.exists() && file.length() > config.sizeBytes / 2) {
                    Log.d(TAG, "Model $modelId downloaded: ${file.length()} bytes")
                    onComplete?.invoke(true, null)
                } else {
                    file.delete()
                    onComplete?.invoke(false, "Download incomplete")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Download failed for $modelId", e)
                getModelFile(config).delete()
                onComplete?.invoke(false, e.message)
            } finally {
                conn?.disconnect()
                downloadingMap[modelId] = false
            }
        }
    }

    fun deleteModel(modelId: String) {
        val config = MODEL_REGISTRY[modelId] ?: return
        // Release loaded model first
        loadedModels.remove(modelId)?.let {
            try { Llama.releaseModel(it) } catch (_: Exception) {}
        }
        val file = getModelFile(config)
        if (file.exists()) file.delete()
    }

    private fun loadModel(modelId: String): LlamaModel? {
        loadedModels[modelId]?.let { return it }
        val config = MODEL_REGISTRY[modelId] ?: return null
        try {
            val modelFile = getModelFile(config)
            if (!modelFile.exists()) {
                Log.w(TAG, "Model file not found for $modelId")
                return null
            }

            val loaded = runBlocking {
                Llama.loadModel(
                    modelPath = modelFile.absolutePath,
                    config = LlamaConfig(contextSize = config.contextSize, threads = config.threads)
                )
            }
            loadedModels[modelId] = loaded
            Log.d(TAG, "Model $modelId loaded successfully")
            return loaded
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load model $modelId", e)
            return null
        }
    }

    fun getAiReply(
        modelId: String,
        senderName: String,
        incomingMessage: String,
        systemPrompt: String,
        conversationHistory: List<ConversationHistory.ChatMessage> = emptyList(),
        callback: (String?, AiUsage?) -> Unit,
    ) {
        getAiReplyBatch(modelId, senderName, listOf(incomingMessage), systemPrompt, conversationHistory, callback)
    }

    fun getAiReplyBatch(
        modelId: String,
        senderName: String,
        incomingMessages: List<String>,
        systemPrompt: String,
        conversationHistory: List<ConversationHistory.ChatMessage> = emptyList(),
        callback: (String?, AiUsage?) -> Unit,
    ) {
        executor.execute {
            try {
                if (!isModelAvailable(modelId)) {
                    callback(fallbackReplies.random(), AiUsage(error = "Model not downloaded"))
                    return@execute
                }

                val loadedModel = loadModel(modelId)
                if (loadedModel == null) {
                    callback(fallbackReplies.random(), AiUsage(error = "Failed to load model"))
                    return@execute
                }

                val combinedMessage = if (incomingMessages.size == 1) {
                    "Message from $senderName: ${incomingMessages[0]}"
                } else {
                    val conv = incomingMessages.joinToString("\n") { it }
                    "Messages from $senderName (read as one conversation):\n$conv"
                }

                val prompt = buildPrompt(modelId, systemPrompt, conversationHistory, combinedMessage)
                Log.d(TAG, "Running inference for $modelId (prompt: ${prompt.length} chars)")

                val result = runBlocking {
                    withTimeoutOrNull(60_000L) {
                        Llama.complete(
                            model = loadedModel,
                            prompt = prompt,
                            maxTokens = 100
                        )
                    }
                }

                if (result == null) {
                    Log.e(TAG, "Inference timed out for $modelId")
                    callback(fallbackReplies.random(), AiUsage(error = "Inference timed out"))
                } else {
                    val reply = result.text?.trim()
                    Log.d(TAG, "Raw inference result for $modelId: '${reply?.take(200) ?: "NULL"}'")
                    if (reply != null && reply.isNotBlank()) {
                        val cleanReply = postProcess(reply)
                        Log.d(TAG, "Inference complete for $modelId: ${result.tokensPerSecond} tok/s")
                        if (cleanReply.isNotBlank()) {
                            callback(cleanReply, AiUsage(tokensUsed = prompt.length / 4 + cleanReply.length / 4))
                        } else {
                            Log.e(TAG, "Clean reply is blank after postProcess for $modelId")
                            callback(fallbackReplies.random(), AiUsage(error = "Empty response after processing"))
                        }
                    } else {
                        Log.e(TAG, "Raw reply is null or empty for $modelId")
                        callback(fallbackReplies.random(), AiUsage(error = "Empty response"))
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Inference failed for $modelId", e)
                callback(fallbackReplies.random(), AiUsage(error = e.message))
            }
        }
    }

    private fun buildPrompt(
        modelId: String,
        systemPrompt: String,
        history: List<ConversationHistory.ChatMessage>,
        incomingMessage: String,
    ): String {
        val sb = StringBuilder()
        
        val optimizedSystemPrompt = if (systemPrompt.isNotBlank()) {
            systemPrompt
        } else {
            "You are a helpful assistant. Reply naturally and briefly to messages. Keep responses conversational and under 30 words."
        }
        
        // Llama 3 Format
        sb.append("<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n$optimizedSystemPrompt<|eot_id|>\n")
        
        for (msg in history) {
            val role = if (msg.role == "user") "user" else "assistant"
            sb.append("<|start_header_id|>$role<|end_header_id|>\n\n${msg.content}<|eot_id|>\n")
        }
        
        sb.append("<|start_header_id|>user<|end_header_id|>\n\n$incomingMessage<|eot_id|>\n")
        sb.append("<|start_header_id|>assistant<|end_header_id|>\n\n")
        
        val finalPrompt = sb.toString()
        Log.d(TAG, "Built prompt for $modelId (${finalPrompt.length} chars)")
        return finalPrompt
    }

    private fun postProcess(text: String): String {
        Log.d(TAG, "postProcess input: '${text.take(200)}'")
        var result = text.trim()
        
        // Strip model-specific special tokens (Llama 3 specific)
        result = result.replace("<|eot_id|>", "")
            .replace("<|start_header_id|>", "")
            .replace("<|end_header_id|>", "")
            .replace("<|begin_of_text|>", "")
            .trim()
        
        // Remove common model artifacts
        result = result.replace("<end_of_turn>", "")
            .replace("<bos>", "")
            .replace("<eos>", "")
            .trim()
        
        // Only remove role prefixes if they appear at the beginning
        if (result.startsWith("Assistant:", ignoreCase = true)) {
            result = result.removePrefix("Assistant:").trim()
        }
        if (result.startsWith("Human:", ignoreCase = true)) {
            result = result.removePrefix("Human:").trim()
        }
        if (result.startsWith("User:", ignoreCase = true)) {
            result = result.removePrefix("User:").trim()
        }
            
        // If result is empty after filtering, return a fallback
        if (result.isBlank()) {
            Log.w(TAG, "postProcess result is empty after filtering. Original: '${text.take(100)}'")
            return "Got it, thanks!"
        }
        
        // Take the first paragraph and limit length
        val firstParagraph = result.split("\n\n").firstOrNull() ?: result
        val finalResult = firstParagraph.trim().take(300)
        
        Log.d(TAG, "postProcess output: '${finalResult}'")
        return finalResult
    }

    /**
     * Returns true if the message batch is "hard or confusing" and should be
     * escalated to the Cerebras cloud API instead of (or after failing) the local model.
     *
     * Heuristics:
     *  • Total character length > 200 (lengthy question)
     *  • Contains 2+ question marks (multiple questions)
     *  • Contains complexity keywords (explain, why, how does, code, summarize, etc.)
     *  • Contains technical indicators (algorithm, function, error, exception, bug, etc.)
     */
    fun isMessageHardOrConfusing(messages: List<String>): Boolean {
        val combined = messages.joinToString(" ").lowercase()
        val charLen = combined.length

        if (charLen > 200) {
            Log.d(TAG, "isHard: length=$charLen > 200")
            return true
        }

        val questionCount = combined.count { it == '?' }
        if (questionCount >= 2) {
            Log.d(TAG, "isHard: questionCount=$questionCount")
            return true
        }

        val complexityKeywords = listOf(
            "explain", "why", "how does", "how do", "can you", "what is", "what are",
            "describe", "summarize", "summary", "difference between", "compare",
            "help me", "assist", "code", "function", "algorithm", "implement",
            "error", "exception", "bug", "fix", "solve", "calculate", "analyze"
        )
        val hasComplexKeyword = complexityKeywords.any { combined.contains(it) }
        if (hasComplexKeyword) {
            Log.d(TAG, "isHard: matched complexity keyword in: '${combined.take(80)}'")
            return true
        }

        return false
    }

    /**
     * Calls the Cerebras cloud API and returns a reply via callback.
     * Runs on the executor (background thread). Callback is invoked on the same thread.
     */
    fun getCerebrasReplyBatch(
        apiKey: String,
        model: String,
        senderName: String,
        incomingMessages: List<String>,
        systemPrompt: String,
        conversationHistory: List<ConversationHistory.ChatMessage> = emptyList(),
        callback: (String?, AiUsage?) -> Unit,
    ) {
        if (apiKey.isBlank()) {
            Log.w(TAG, "Cerebras API key is empty — skipping")
            callback(fallbackReplies.random(), AiUsage(error = "No Cerebras API key configured"))
            return
        }

        executor.execute {
            try {
                val url = URL(currentCerebrasConfig.apiUrl)
                val conn = url.openConnection() as java.net.HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/json")
                conn.setRequestProperty("Authorization", "Bearer $apiKey")
                conn.connectTimeout = currentCerebrasConfig.timeout.toInt()
                conn.readTimeout = currentCerebrasConfig.timeout.toInt()
                conn.doOutput = true

                // Build messages array
                val messagesArray = org.json.JSONArray()

                // System message
                messagesArray.put(org.json.JSONObject().apply {
                    put("role", "system")
                    put("content", systemPrompt)
                })

                // Conversation history
                for (msg in conversationHistory) {
                    messagesArray.put(org.json.JSONObject().apply {
                        put("role", msg.role)
                        put("content", msg.content)
                    })
                }

                // Incoming user messages
                val userContent = if (incomingMessages.size == 1) {
                    "Message from $senderName: ${incomingMessages[0]}"
                } else {
                    "Messages from $senderName:\n${incomingMessages.joinToString("\n")}"
                }
                messagesArray.put(org.json.JSONObject().apply {
                    put("role", "user")
                    put("content", userContent)
                })

                val body = org.json.JSONObject().apply {
                    put("model", model)
                    put("messages", messagesArray)
                    put("max_tokens", 150)
                    put("temperature", 0.7)
                }.toString()

                conn.outputStream.use { it.write(body.toByteArray()) }

                val responseCode = conn.responseCode
                val responseBody = if (responseCode == 200) {
                    conn.inputStream.bufferedReader().readText()
                } else {
                    conn.errorStream?.bufferedReader()?.readText() ?: "HTTP $responseCode"
                }
                conn.disconnect()

                if (responseCode != 200) {
                    Log.e(TAG, "Cerebras API error $responseCode: $responseBody")
                    callback(fallbackReplies.random(), AiUsage(error = "Cerebras API error $responseCode"))
                    return@execute
                }

                val json = org.json.JSONObject(responseBody)
                val choices = json.optJSONArray("choices")
                val reply = choices?.optJSONObject(0)
                    ?.optJSONObject("message")
                    ?.optString("content")
                    ?.trim()

                val usage = json.optJSONObject("usage")
                val tokensUsed = usage?.optInt("total_tokens", 0) ?: 0

                if (!reply.isNullOrBlank()) {
                    Log.d(TAG, "Cerebras reply: '${reply.take(100)}'")
                    callback(reply, AiUsage(tokensUsed = tokensUsed))
                } else {
                    Log.e(TAG, "Cerebras returned empty content")
                    callback(fallbackReplies.random(), AiUsage(error = "Empty response from Cerebras"))
                }
            } catch (e: Exception) {
                Log.e(TAG, "Cerebras API call failed", e)
                callback(fallbackReplies.random(), AiUsage(error = e.message))
            }
        }
    }



    fun close() {
        loadedModels.values.forEach {
            try { Llama.releaseModel(it) } catch (_: Exception) {}
        }
        loadedModels.clear()
        executor.shutdown()
    }

    // ===== Cerebras API Configuration Methods =====

    /**
     * Returns the current Cerebras API configuration.
     * @return CerebrasConfig with current settings including API key
     */
    fun getCerebrasConfig(): Companion.CerebrasConfig = currentCerebrasConfig

    /**
     * Saves the Cerebras API key to SharedPreferences.
     * API key is persisted for use across app sessions.
     * @param apiKey The API key to save (can be empty to clear)
     */
    fun setCerebrasApiKey(apiKey: String) {
        val trimmedKey = apiKey.trim()
        currentCerebrasConfig = currentCerebrasConfig.copy(apiKey = trimmedKey)
        sharedPreferences.edit().putString("cerebras_api_key", trimmedKey).apply()
        Log.d(TAG, "Cerebras API key saved (${maskApiKey(trimmedKey)})")
    }

    /**
     * Loads the saved Cerebras API key from SharedPreferences.
     * Called automatically on service initialization.
     */
    fun loadCerebrasApiKey() {
        val savedKey = sharedPreferences.getString("cerebras_api_key", "")?.trim() ?: ""
        currentCerebrasConfig = currentCerebrasConfig.copy(apiKey = savedKey)
        Log.d(TAG, "Cerebras API key loaded (${maskApiKey(savedKey)})")
    }

    /**
     * Checks if Cerebras API is available and configured.
     * Returns true only if API key is non-empty and non-blank.
     * @return true if API key is configured, false otherwise
     */
    fun isCerebrasAvailable(): Boolean {
        val available = currentCerebrasConfig.apiKey.isNotBlank()
        Log.d(TAG, "Cerebras availability check: $available")
        return available
    }

    /**
     * Clears the saved Cerebras API key.
     * API becomes unavailable after this call.
     */
    fun clearCerebrasApiKey() {
        currentCerebrasConfig = currentCerebrasConfig.copy(apiKey = "")
        sharedPreferences.edit().remove("cerebras_api_key").apply()
        Log.d(TAG, "Cerebras API key cleared")
    }

    /**
     * Masks API key for safe logging.
     * Shows first 3 and last 3 characters with "..." in between.
     * @param apiKey The API key to mask
     * @return Masked API key suitable for logging
     */
    private fun maskApiKey(apiKey: String): String {
        return when {
            apiKey.isBlank() -> "(empty)"
            apiKey.length <= 6 -> "***"
            else -> apiKey.take(3) + "..." + apiKey.takeLast(3)
        }
    }
}
