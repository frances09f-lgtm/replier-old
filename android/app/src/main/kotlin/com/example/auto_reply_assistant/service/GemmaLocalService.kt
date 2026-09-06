package com.example.auto_reply_assistant.service

import android.content.Context
import android.util.Log
import dev.ffmpegkit.llama.Llama
import dev.ffmpegkit.llama.LlamaConfig
import dev.ffmpegkit.llama.LlamaModel
import kotlinx.coroutines.runBlocking
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class GemmaLocalService(private val context: Context) {

    companion object {
        private const val TAG = "GemmaLocalService"
        private const val MODEL_FILENAME = "gemma-3-270m-it-Q4_K_M.gguf"
        private const val MODEL_URL = "https://huggingface.co/lmstudio-community/gemma-3-270m-it-GGUF/resolve/main/gemma-3-270m-it-Q4_K_M.gguf"
        private const val MODEL_SIZE_BYTES = 173_000_000L

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

    private var model: LlamaModel? = null
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()

    @Volatile
    private var downloading = false

    @Volatile
    private var downloadProgress = 0

    fun isModelAvailable(): Boolean {
        val f = getModelFile()
        return f.exists() && f.length() > MODEL_SIZE_BYTES / 2
    }

    fun getModelFile(): File = File(context.filesDir, MODEL_FILENAME)

    fun isDownloading(): Boolean = downloading

    fun getDownloadProgress(): Int = downloadProgress

    fun downloadModel(
        onProgress: ((Int) -> Unit)? = null,
        onComplete: ((Boolean, String?) -> Unit)? = null
    ) {
        if (downloading) {
            onComplete?.invoke(false, "Already downloading")
            return
        }
        if (isModelAvailable()) {
            onComplete?.invoke(true, null)
            return
        }

        downloading = true
        downloadProgress = 0

        executor.execute {
            var conn: HttpURLConnection? = null
            try {
                val url = URL(MODEL_URL)
                conn = url.openConnection() as HttpURLConnection
                conn.connectTimeout = 30_000
                conn.readTimeout = 120_000
                conn.connect()

                val totalSize = conn.contentLength.toLong().coerceAtLeast(MODEL_SIZE_BYTES)
                val input = conn.inputStream
                val output = FileOutputStream(getModelFile())

                val buffer = ByteArray(8192)
                var bytesRead: Int
                var totalRead = 0L

                while (input.read(buffer).also { bytesRead = it } != -1) {
                    output.write(buffer, 0, bytesRead)
                    totalRead += bytesRead
                    val progress = ((totalRead * 100) / totalSize).toInt().coerceIn(0, 100)
                    if (progress != downloadProgress) {
                        downloadProgress = progress
                        onProgress?.invoke(progress)
                    }
                }

                output.flush()
                output.close()
                input.close()

                val file = getModelFile()
                if (file.exists() && file.length() > MODEL_SIZE_BYTES / 2) {
                    Log.d(TAG, "Model downloaded: ${file.length()} bytes")
                    onComplete?.invoke(true, null)
                } else {
                    file.delete()
                    onComplete?.invoke(false, "Download incomplete")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Download failed", e)
                getModelFile().delete()
                onComplete?.invoke(false, e.message)
            } finally {
                conn?.disconnect()
                downloading = false
            }
        }
    }

    private fun loadModel(): LlamaModel? {
        if (model != null) return model
        try {
            val modelFile = getModelFile()
            if (!modelFile.exists()) {
                Log.w(TAG, "Model file not found")
                return null
            }

            model = runBlocking {
                Llama.loadModel(
                    modelPath = modelFile.absolutePath,
                    config = LlamaConfig(contextSize = 2048, threads = 4)
                )
            }
            Log.d(TAG, "Model loaded successfully")
            return model
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load model", e)
            model = null
            return null
        }
    }

    fun getAiReply(
        senderName: String,
        incomingMessage: String,
        systemPrompt: String,
        conversationHistory: List<ConversationHistory.ChatMessage> = emptyList(),
        callback: (String?, AiUsage?) -> Unit,
    ) {
        getAiReplyBatch(senderName, listOf(incomingMessage), systemPrompt, conversationHistory, callback)
    }

    fun getAiReplyBatch(
        senderName: String,
        incomingMessages: List<String>,
        systemPrompt: String,
        conversationHistory: List<ConversationHistory.ChatMessage> = emptyList(),
        callback: (String?, AiUsage?) -> Unit,
    ) {
        executor.execute {
            try {
                if (!isModelAvailable()) {
                    callback(fallbackReplies.random(), AiUsage(error = "Model not downloaded"))
                    return@execute
                }

                val loadedModel = loadModel()
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
                Log.d(TAG, "Running local inference (prompt: ${prompt.length} chars)")

                val result = runBlocking {
                    Llama.complete(
                        model = loadedModel,
                        prompt = prompt,
                        systemPrompt = systemPrompt,
                        maxTokens = 150
                    )
                }

                val reply = result.text?.trim()
                if (reply != null && reply.isNotBlank()) {
                    val cleanReply = postProcess(reply)
                    Log.d(TAG, "Local inference complete: ${result.tokensPerSecond} tok/s")
                    callback(cleanReply, AiUsage(tokensUsed = prompt.length / 4 + cleanReply.length / 4))
                } else {
                    callback(fallbackReplies.random(), AiUsage(error = "Empty response"))
                }
            } catch (e: Exception) {
                Log.e(TAG, "Local inference failed", e)
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
        for (msg in history) {
            if (msg.role == "user") {
                sb.append("User: ${msg.content}\n")
            } else {
                sb.append("Assistant: ${msg.content}\n")
            }
        }
        sb.append("User: $incomingMessage\nAssistant:")
        return sb.toString()
    }

    private fun postProcess(text: String): String {
        var result = text.trim()
        result = result.replace("<end_of_turn>", "")
            .replace("<bos>", "")
            .replace("<eos>", "")
            .trim()
        val firstParagraph = result.split("\n\n").firstOrNull() ?: result
        return firstParagraph.trim().take(500)
    }

    fun close() {
        model?.let {
            try { Llama.releaseModel(it) } catch (_: Exception) {}
        }
        model = null
        executor.shutdown()
    }
}
