package com.example.auto_reply_assistant.service

/**
 * Detects notifications for messages this app sent, without treating
 * third-party text that merely mentions a past reply as self-sent.
 */
object SelfSentReplyGuard {

    fun isSelfSender(sender: String): Boolean {
        val normalized = sender.trim().lowercase()
        return normalized == "you" || normalized == "me"
    }

    fun isSelfSentMessage(
        message: String,
        sender: String,
        sentReplyTexts: Set<String>,
    ): Boolean {
        var lower = message.trim().lowercase()

        val selfPrefixes = listOf("you:", "me:", "you sent:")
        for (prefix in selfPrefixes) {
            if (lower.startsWith(prefix)) {
                lower = lower.removePrefix(prefix).trim()
            }
        }

        if (lower.isBlank()) return true

        // Only WhatsApp "You" / "Me" outgoing notifications are self-sent.
        // Never treat a contact's message as self-sent because it mentions our past reply.
        if (!isSelfSender(sender)) return false

        for (sentText in sentReplyTexts) {
            if (sentText.isBlank()) continue
            if (lower == sentText) return true
            if (lower.endsWith(sentText) || lower.startsWith(sentText)) {
                return true
            }
        }
        return false
    }
}
