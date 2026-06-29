package com.example.auto_reply_assistant.service

import android.util.Log
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class LocalAiService private constructor() {

    companion object {
        private const val TAG = "LocalAiService"
        private const val MODEL_DIR = "local_models"
        private var isLoaded = false
        private var nativeAvailable = false
        private var instance: LocalAiService? = null
        private val executor = Executors.newFixedThreadPool(2)
        private val isGenerating = AtomicBoolean(false)

        init {
            try {
                System.loadLibrary("llama_bridge")
                nativeAvailable = true
                Log.d(TAG, "llama_bridge native library loaded")
            } catch (e: UnsatisfiedLinkError) {
                Log.w(TAG, "llama_bridge not available — local models disabled")
            }
        }

        fun getInstance(): LocalAiService {
            if (instance == null) {
                instance = LocalAiService()
            }
            return instance!!
        }

        fun isNativeAvailable(): Boolean = nativeAvailable
    }

    data class LocalAiResult(
        val reply: String? = null,
        val error: String? = null
    )

    fun isModelLoaded(): Boolean = isLoaded

    fun forceReload(modelPath: String, callback: (Boolean, String?) -> Unit) {
        isGenerating.set(false)
        isLoaded = false
        executor.submit {
            try {
                Log.d(TAG, "Force reloading model: $modelPath")
                val success = nativeLoadModel(modelPath)
                isLoaded = success
                if (success) {
                    Log.d(TAG, "Model reloaded successfully")
                    callback(true, null)
                } else {
                    Log.e(TAG, "Failed to reload model")
                    callback(false, "Failed to reload model")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error reloading model", e)
                isLoaded = false
                callback(false, e.message ?: "Unknown error")
            }
        }
    }

    fun getModelDirectory(context: android.content.Context): File {
        val dir = File(context.filesDir, MODEL_DIR)
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    fun getDownloadedModels(context: android.content.Context): List<File> {
        val dir = getModelDirectory(context)
        return dir.listFiles()
            ?.filter { it.name.endsWith(".gguf") }
            ?.sortedByDescending { it.lastModified() }
            ?: emptyList()
    }

    fun loadModel(
        modelPath: String,
        callback: (Boolean, String?) -> Unit
    ) {
        executor.submit {
            try {
                Log.d(TAG, "Loading model: $modelPath")
                val success = nativeLoadModel(modelPath)
                isLoaded = success
                if (success) {
                    Log.d(TAG, "Model loaded successfully")
                    callback(true, null)
                } else {
                    Log.e(TAG, "Failed to load model")
                    callback(false, "Failed to load model")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error loading model", e)
                isLoaded = false
                callback(false, e.message ?: "Unknown error")
            }
        }
    }

    fun generateReply(
        systemPrompt: String,
        senderName: String,
        incomingMessage: String,
        maxTokens: Int = 128,
        temperature: Float = 0.7f,
        callback: (LocalAiResult) -> Unit
    ) {
        if (!isGenerating.compareAndSet(false, true)) {
            Log.w(TAG, "Generation already in progress, skipping")
            callback(LocalAiResult(error = "Busy generating another reply"))
            return
        }

        // For local models, truncate system prompt to keep persona instructions
        // but stay within the small context window (~100 tokens for sys prompt)
        val localSysPrompt = if (systemPrompt.length > 150) {
            systemPrompt.take(150)
        } else {
            systemPrompt
        }

        executor.submit {
            try {
                if (!isLoaded) {
                    callback(LocalAiResult(error = "Model not loaded"))
                    return@submit
                }

                Log.d(TAG, "Generating reply (sys=${localSysPrompt.length}, msg=${incomingMessage.length})")

                val result = nativeGenerate(localSysPrompt, senderName, incomingMessage, maxTokens, temperature)

                if (result.isNullOrBlank()) {
                    callback(LocalAiResult(error = "Empty response from model"))
                } else {
                    val cleaned = cleanReply(result.trim())
                    Log.d(TAG, "Generated reply: $cleaned")
                    callback(LocalAiResult(reply = cleaned))
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error generating reply", e)
                callback(LocalAiResult(error = e.message ?: "Generation failed"))
            } finally {
                isGenerating.set(false)
            }
        }
    }

    fun unloadModel() {
        executor.submit {
            try {
                if (isLoaded) {
                    nativeUnloadModel()
                    isLoaded = false
                    Log.d(TAG, "Model unloaded")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error unloading model", e)
            }
        }
    }

    private fun cleanReply(reply: String): String {
        var cleaned = reply
        val stopPhrases = listOf(
            "Message from", "Your reply:", "User:", "Assistant:",
            "\n---", "---", "[INST]", "[/INST]"
        )
        for (phrase in stopPhrases) {
            val idx = cleaned.indexOf(phrase)
            if (idx >= 0) {
                cleaned = cleaned.substring(0, idx)
            }
        }
        val lines = cleaned.split("\n")
            .map { it.trim() }
            .filter { it.isNotBlank() }
        return lines.joinToString(" ")
    }

    private external fun nativeLoadModel(modelPath: String): Boolean
    private external fun nativeGenerate(systemPrompt: String, senderName: String, incomingMessage: String, maxTokens: Int, temperature: Float): String?
    private external fun nativeUnloadModel()
}
