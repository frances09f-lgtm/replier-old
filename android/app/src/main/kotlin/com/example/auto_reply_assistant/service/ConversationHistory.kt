package com.example.auto_reply_assistant.service

import android.util.Log

/**
 * In-memory per-sender conversation history for AI context.
 *
 * Keeps the last [MAX_MESSAGES] messages (alternating user/assistant)
 * so the AI can answer follow-up questions with context.
 * History is keyed by sender name and resets when the service restarts.
 */
object ConversationHistory {

    private const val TAG = "ConversationHistory"
    private const val MAX_MESSAGES = 5

    data class ChatMessage(
        val role: String,   // "user" or "assistant"
        val content: String
    )

    // Per-sender history, keyed by sender name
    private val histories = mutableMapOf<String, MutableList<ChatMessage>>()

    @Synchronized
    fun addMessage(sender: String, role: String, content: String) {
        val history = histories.getOrPut(sender) { mutableListOf() }
        history.add(ChatMessage(role, content))
        // Trim to last MAX_MESSAGES
        while (history.size > MAX_MESSAGES) {
            history.removeAt(0)
        }
        Log.d(TAG, "addMessage: sender=$sender, role=$role, historySize=${history.size}")
    }

    @Synchronized
    fun getHistory(sender: String): List<ChatMessage> {
        return histories[sender]?.toList() ?: emptyList()
    }

    @Synchronized
    fun clearHistory(sender: String) {
        histories.remove(sender)
        Log.d(TAG, "clearHistory: sender=$sender")
    }

    @Synchronized
    fun clearAll() {
        histories.clear()
        Log.d(TAG, "clearAll")
    }
}
