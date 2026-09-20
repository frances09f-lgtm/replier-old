package com.example.auto_reply_assistant.service

import org.json.JSONArray
import org.json.JSONObject

/**
 * Builds provider-specific AI request bodies (testable, no network).
 */
object CloudAiRequestBuilder {

    fun buildFormattedSystemPrompt(userSystemPrompt: String, senderName: String): String {
        val effectiveSender = if (senderName.isBlank()) "the user" else senderName
        val sb = StringBuilder()
        sb.append(
            "You are an AI assistant auto-replying to incoming messages from $effectiveSender " +
                "on behalf of the app user.\n\n"
        )

        val trimmedUserPrompt = userSystemPrompt.trim()
        if (trimmedUserPrompt.isNotBlank()) {
            sb.append("User Guidelines & Persona:\n")
            sb.append(trimmedUserPrompt)
            sb.append("\n\n")
        }

        sb.append("Instructions:\n")
        sb.append("- Reply directly to $effectiveSender in a natural, friendly, and helpful tone.\n")
        sb.append("- Reply in the same language as the incoming message (e.g. English, Marathi, or mixed).\n")
        sb.append("- Keep replies brief, conversational, and under 30 words.\n")
        sb.append("- Do NOT repeat or echo $effectiveSender's message.\n")
        sb.append("- Do NOT include role prefixes like 'Assistant:', 'AI:', or '$effectiveSender:'.\n")
        sb.append(
            "- CRITICAL: Do NOT think out loud, do NOT include reasoning, internal monologue, thought process, explanations, or notes. " +
                "Output ONLY the final message reply text."
        )

        return sb.toString()
    }

    fun buildOpenAiCompatiblePayload(
        model: String,
        systemPrompt: String,
        incomingMessage: String,
        senderName: String,
        history: List<ConversationHistory.ChatMessage> = emptyList(),
        maxTokens: Int = 256,
        temperature: Double = 0.7,
        provider: String = "",
    ): JSONObject {
        val messagesArray = JSONArray()

        messagesArray.put(JSONObject().apply {
            put("role", "system")
            put("content", systemPrompt)
        })

        for (msg in history) {
            val role = if (msg.role == "user") "user" else "assistant"
            val content = if (msg.role == "user" && !msg.content.startsWith("$senderName:")) {
                "$senderName: ${msg.content}"
            } else {
                msg.content
            }
            messagesArray.put(JSONObject().apply {
                put("role", role)
                put("content", content)
            })
        }

        val currentContent = if (!incomingMessage.startsWith("$senderName:")) {
            "$senderName: $incomingMessage"
        } else {
            incomingMessage
        }

        messagesArray.put(JSONObject().apply {
            put("role", "user")
            put("content", currentContent)
        })

        return JSONObject().apply {
            put("model", model)
            put("messages", messagesArray)
            put("max_tokens", maxTokens)
            put("temperature", temperature)

            val isGroqOrReasoning = provider == "groq_api" ||
                model.contains("oss", ignoreCase = true) ||
                model.contains("r1", ignoreCase = true) ||
                model.contains("deepseek", ignoreCase = true)

            if (isGroqOrReasoning) {
                put("reasoning_format", "hidden")
                if (model.contains("oss", ignoreCase = true)) {
                    put("reasoning_effort", "low")
                }
            }
        }
    }

    fun buildGeminiPayload(
        systemPrompt: String,
        incomingMessage: String,
        senderName: String,
        history: List<ConversationHistory.ChatMessage> = emptyList(),
        maxOutputTokens: Int = 256,
        temperature: Double = 0.7,
    ): JSONObject {
        val contentsArray = JSONArray()

        for (msg in history) {
            val role = if (msg.role == "user") "user" else "model"
            val contentText = if (msg.role == "user" && !msg.content.startsWith("$senderName:")) {
                "$senderName: ${msg.content}"
            } else {
                msg.content
            }
            contentsArray.put(JSONObject().apply {
                put("role", role)
                put("parts", JSONArray().put(JSONObject().put("text", contentText)))
            })
        }

        val currentContent = if (!incomingMessage.startsWith("$senderName:")) {
            "$senderName: $incomingMessage"
        } else {
            incomingMessage
        }

        contentsArray.put(JSONObject().apply {
            put("role", "user")
            put("parts", JSONArray().put(JSONObject().put("text", currentContent)))
        })

        return JSONObject().apply {
            put("contents", contentsArray)
            put("systemInstruction", JSONObject().apply {
                put("parts", JSONArray().put(JSONObject().put("text", systemPrompt)))
            })
            put("generationConfig", JSONObject().apply {
                put("maxOutputTokens", maxOutputTokens)
                put("temperature", temperature)
            })
        }
    }
}
