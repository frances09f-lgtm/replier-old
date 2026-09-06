package com.example.auto_reply_assistant.service

import android.util.Log
import com.google.mlkit.nl.smartreply.SmartReply
import com.google.mlkit.nl.smartreply.SmartReplySuggestion
import com.google.mlkit.nl.smartreply.TextMessage
import java.util.concurrent.Executors

class SmartReplyService {

    companion object {
        private const val TAG = "SmartReplyService"

        private val fallbackReplies = listOf(
            "Thanks for your message!",
            "Got it, thanks!",
            "I'll get back to you soon.",
            "Noted, thank you!",
            "Thanks!",
            "Okay, thanks!",
        )

        // Matches messages that are media-only (images, videos, files, etc.)
        private val mediaPatterns = listOf(
            Regex("""(?i)\.(png|jpg|jpeg|gif|bmp|webp|svg|mp4|avi|mov|mkv|mp3|wav|ogg|pdf|docx?|xlsx?|zip|rar|7z)$"""),
            Regex("""(?i)^(image|photo|picture|video|audio|file|document|sticker|gif)\s*(\.\w+)?$"""),
            Regex("""(?i)^\d+\s+(photo|photo|video|image|document|file)s?$"""),
            Regex("""(?i)^(image|video|audio|document)\s+(attached|sent|received)$"""),
            Regex("""(?i)^(sent|shared)\s+(a|an)\s+(image|photo|picture|video|audio|file|document|sticker|gif)"""),
            Regex("""^[😀-🙏🀀-🟫🌀-🗿]+$"""), // emoji-only
        )

        fun isMediaOnly(text: String): Boolean {
            val trimmed = text.trim()
            if (trimmed.isEmpty()) return true
            return mediaPatterns.any { it.containsMatchIn(trimmed) }
        }
    }

    data class AiUsage(
        val tokensUsed: Int = 0,
        val tokensRemaining: Int = 0,
        val tokensLimit: Int = 0,
        val resetInSeconds: Int = 0,
        val error: String? = null,
    )

    private val smartReply = SmartReply.getClient()
    private val executor = Executors.newSingleThreadExecutor()

    fun getAiReply(
        senderName: String,
        incomingMessage: String,
        conversationHistory: List<ConversationHistory.ChatMessage>,
        callback: (String?, AiUsage?) -> Unit,
    ) {
        getAiReplyBatch(senderName, listOf(incomingMessage), conversationHistory, callback)
    }

    fun getAiReplyBatch(
        senderName: String,
        incomingMessages: List<String>,
        conversationHistory: List<ConversationHistory.ChatMessage>,
        callback: (String?, AiUsage?) -> Unit,
    ) {
        executor.execute {
            try {
                val conversation = mutableListOf<TextMessage>()
                var hasLocalMessage = false
                var ts = System.currentTimeMillis()

                // Add previous conversation history
                for (msg in conversationHistory) {
                    val text = if (msg.content.length > 200) msg.content.take(200) else msg.content
                    if (msg.role == "assistant") {
                        conversation.add(TextMessage.createForLocalUser(text, ts++))
                        hasLocalMessage = true
                    } else {
                        conversation.add(TextMessage.createForRemoteUser(text, ts++, senderName))
                    }
                }

                // Add the new incoming messages (skip media-only content)
                var hasTextMessage = false
                for (msg in incomingMessages) {
                    if (isMediaOnly(msg)) {
                        Log.d(TAG, "Skipping media-only message: '${msg.take(50)}'")
                        continue
                    }
                    val text = if (msg.length > 200) msg.take(200) else msg
                    conversation.add(TextMessage.createForRemoteUser(text, ts++, senderName))
                    hasTextMessage = true
                }

                if (conversation.isEmpty() || !hasTextMessage) {
                    Log.d(TAG, "No text messages to process, using fallback")
                    callback(fallbackReplies.random(), AiUsage())
                    return@execute
                }

                // If no local user messages (first interaction), seed with a neutral message
                if (!hasLocalMessage) {
                    val seeded = mutableListOf<TextMessage>()
                    seeded.add(TextMessage.createForLocalUser("ok", ts++))
                    seeded.addAll(conversation)
                    suggestReplies(seeded, callback)
                } else {
                    suggestReplies(conversation, callback)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Unexpected error", e)
                callback(null, AiUsage(error = e.message))
            }
        }
    }

    private fun suggestReplies(
        conversation: List<TextMessage>,
        callback: (String?, AiUsage?) -> Unit,
    ) {
        smartReply.suggestReplies(conversation)
            .addOnSuccessListener { result ->
                val suggestions = result.suggestions
                if (suggestions.isNotEmpty()) {
                    val reply = suggestions[0].text
                    Log.d(TAG, "Smart Reply suggestion: '$reply'")
                    callback(reply, AiUsage())
                } else {
                    Log.d(TAG, "Smart Reply returned no suggestions, using fallback")
                    callback(fallbackReplies.random(), AiUsage())
                }
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Smart Reply failed: ${e.message}")
                callback(fallbackReplies.random(), AiUsage(error = e.message))
            }
    }
}
