package com.example.auto_reply_assistant.service

import android.content.Context
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

class DeepSeekLocalService private constructor(private val context: Context) {

    companion object {
        private const val TAG = "DeepSeekLocalService"

        @Volatile
        private var instance: DeepSeekLocalService? = null

        fun getInstance(context: Context): DeepSeekLocalService {
            return instance ?: synchronized(this) {
                instance ?: DeepSeekLocalService(context.applicationContext).also { instance = it }
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

        val MODEL_REGISTRY = mapOf(
            "deepseek_1_5b" to ModelConfig(
                id = "deepseek_1_5b",
                displayName = "DeepSeek-R1 1.5B",
                filename = "DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf",
                url = "https://huggingface.co/QuantFactory/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B.Q4_K_M.gguf",
                sizeBytes = 1_000_000_000L,
                description = "~1GB, strong reasoning, distilled from R1",
                threads = 4,
                contextSize = 2048,
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

                val prompt = buildPrompt(systemPrompt, conversationHistory, combinedMessage)
                Log.d(TAG, "Running inference for $modelId (prompt: ${prompt.length} chars)")

                val result = runBlocking {
                    withTimeoutOrNull(60_000L) {
                        Llama.complete(
                            model = loadedModel,
                            prompt = prompt,
                            maxTokens = 150
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
        systemPrompt: String,
        history: List<ConversationHistory.ChatMessage>,
        incomingMessage: String,
    ): String {
        val sb = StringBuilder()
        
        // Use DeepSeek-optimized system prompt
        val optimizedSystemPrompt = if (systemPrompt.isNotBlank()) {
            systemPrompt
        } else {
            "You are a helpful assistant. Reply naturally and briefly to messages. Keep responses conversational and under 50 words."
        }
        
        sb.append("System: $optimizedSystemPrompt\n\n")
        
        // Add conversation history
        for (msg in history) {
            if (msg.role == "user") {
                sb.append("Human: ${msg.content}\n")
            } else {
                sb.append("Assistant: ${msg.content}\n")
            }
        }
        
        // Add current message and prompt for response
        sb.append("Human: $incomingMessage\n")
        sb.append("Assistant:")
        
        val finalPrompt = sb.toString()
        Log.d(TAG, "Built prompt for DeepSeek (${finalPrompt.length} chars): '${finalPrompt.take(300)}...'")
        return finalPrompt
    }

    private fun postProcess(text: String): String {
        Log.d(TAG, "postProcess input: '${text.take(200)}'")
        var result = text.trim()
        
        // Strip DeepSeek R1 chain-of-thought <think>...</think> blocks
        result = result.replace(Regex("<think>[\\s\\S]*?</think>", RegexOption.IGNORE_CASE), "").trim()
        
        // Remove any residual <think> tag if closing tag is missing (incomplete generation)
        val thinkStart = result.indexOf("<think>", ignoreCase = true)
        if (thinkStart >= 0) {
            result = result.substring(0, thinkStart).trim()
        }
        
        // Strip common special tokens
        result = result.replace("<end_of_turn>", "")
            .replace("<bos>", "")
            .replace("<eos>", "")
            .replace("Assistant:", "")
            .replace("Human:", "")
            .trim()
            
        // If result is empty after filtering, return a fallback
        if (result.isBlank()) {
            Log.w(TAG, "postProcess result is empty after filtering. Original: '${text.take(100)}'")
            result = "Got it, thanks!"
        }
        
        val firstParagraph = result.split("\n\n").firstOrNull() ?: result
        val finalResult = firstParagraph.trim().take(500)
        
        Log.d(TAG, "postProcess output: '${finalResult}'")
        return finalResult
    }

    fun close() {
        loadedModels.values.forEach {
            try { Llama.releaseModel(it) } catch (_: Exception) {}
        }
        loadedModels.clear()
        executor.shutdown()
    }
}
