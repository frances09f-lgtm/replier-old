# Design Document: Enhanced AI Models with API Fallback

## Architecture Overview

### High-Level System Flow

```
User Message
    ↓
[Complexity Detection] → Score (0-100)
    ↓
[Model Selection] → Qwen or Indra (based on language)
    ↓
[Local Inference] → Success?
    ├─ YES → Return Local Response ✓
    └─ NO or Complexity ≥ 70?
        ↓
    [Cerebras API Available?] → Check API Key
        ├─ YES → Send to Cerebras API
        │   ├─ Success → Return API Response ✓
        │   └─ Fail → Fallback Reply
        └─ NO → Fallback Reply ✓
```

## Core Components

### 1. AiLocalService (Renamed from PhiLocalService)

**Responsibilities:**
- Manage model registry (Qwen, Indra)
- Handle local model download, loading, unloading
- Execute local inference
- Implement complexity detection
- Orchestrate fallback strategy
- Manage Cerebras API integration

**Key Changes:**
- Remove Phi model entries
- Add Indra model configuration
- Add Cerebras API configuration
- Add complexity detection algorithm
- Add fallback routing logic

### 2. Data Classes

#### ModelConfig (Enhanced)
```kotlin
data class ModelConfig(
    val id: String,                    // "qwen2_5_1_5b", "indra_model", "cerebras_api"
    val displayName: String,           // User-friendly name
    val filename: String,              // Local file (empty for API models)
    val url: String,                   // Download URL
    val sizeBytes: Long,               // ~1GB
    val description: String,           // "~1GB, compact..."
    val threads: Int = 4,              // CPU threads
    val contextSize: Int = 2048,       // Context window
    val isLocal: Boolean = true,       // true for Qwen/Indra, false for Cerebras
    val supportedLanguages: List<String> = listOf("en"), // ["en", "mr"] for Indra
)
```

#### CerebrasConfig
```kotlin
data class CerebrasConfig(
    val apiKey: String = "",           // User's API key
    val apiUrl: String = "https://api.cerebras.ai/v1/chat/completions",
    val model: String = "cerebras/model-name",
    val timeout: Long = 15_000L,       // 15 seconds
)
```

#### InferenceResult (Enhanced)
```kotlin
data class InferenceResult(
    val text: String,
    val source: String,                // "local_qwen", "local_indra", "api_cerebras", "fallback"
    val tokensPerSecond: Float = 0f,
    val responseTimeMs: Long = 0L,
    val complexityScore: Int = 0,
    val wasFallback: Boolean = false,
)
```

### 3. Complexity Detection Algorithm

```kotlin
fun detectComplexity(message: String): Int {
    var score = 0
    
    // 1. Message Length (0-20 points)
    score += when {
        message.length < 50 -> 0
        message.length < 150 -> 5
        message.length < 300 -> 10
        else -> 20
    }
    
    // 2. Question Count (0-15 points)
    val questionCount = message.count { it == '?' }
    score += minOf(questionCount * 5, 15)
    
    // 3. Unique Words Ratio (0-15 points)
    val words = message.split(Regex("\\s+"))
    val uniqueRatio = words.distinct().size.toFloat() / words.size
    score += (uniqueRatio * 15).toInt()
    
    // 4. Special Characters (0-15 points)
    val specialChars = message.count { !it.isLetterOrDigit() && !it.isWhitespace() }
    score += minOf(specialChars, 15)
    
    // 5. Code/Technical Indicators (0-20 points)
    val technicalKeywords = listOf(
        "code", "error", "bug", "implement", "algorithm",
        "database", "API", "HTTP", "function", "class",
        "variable", "debug", "compile", "exception"
    )
    val hasTechnicalKeywords = technicalKeywords.any { 
        message.contains(it, ignoreCase = true) 
    }
    if (hasTechnicalKeywords) score += 20
    
    // 6. Language Mixing Detection (0-10 points)
    val hasCodeBlocks = message.contains("```") || message.contains("{") && message.contains("}")
    if (hasCodeBlocks) score += 10
    
    return score.coerceIn(0, 100)
}
```

### 4. Language Detection

```kotlin
fun detectLanguage(message: String): String {
    val marathiPatterns = listOf(
        Regex("[आ-ह]"),  // Marathi script
        "नमस्ते", "धन्यवाद", "कृपया"
    )
    
    val hasMarathi = marathiPatterns.any { 
        if (it is Regex) it.containsMatchIn(message) else message.contains(it)
    }
    
    return if (hasMarathi) "mr" else "en"
}
```

### 5. Model Selection Logic

```kotlin
fun selectPrimaryModel(message: String): String {
    val language = detectLanguage(message)
    
    return when (language) {
        "mr" -> if (isModelAvailable("indra_model")) "indra_model" else "qwen2_5_1_5b"
        else -> "qwen2_5_1_5b"  // English and mixed default to Qwen
    }
}
```

### 6. Inference Orchestration

```kotlin
fun getAiReplyWithFallback(
    primaryModelId: String,
    senderName: String,
    message: String,
    systemPrompt: String,
    history: List<ChatMessage>,
    callback: (String?, InferenceResult?) -> Unit,
) {
    // Step 1: Detect complexity
    val complexity = detectComplexity(message)
    
    // Step 2: Try local inference
    getAiReplyLocal(primaryModelId, senderName, message, systemPrompt, history) { localReply, localUsage ->
        if (localReply != null && !localReply.startsWith("ERROR")) {
            // Local succeeded
            callback(localReply, InferenceResult(
                text = localReply,
                source = "local_${primaryModelId}",
                complexityScore = complexity
            ))
            return@getAiReplyLocal
        }
        
        // Step 3: Check if we should try API
        if (complexity >= 70 && isCerebrasAvailable()) {
            // Try Cerebras API
            sendToCerebrasApi(senderName, message, systemPrompt, history) { apiReply, apiUsage ->
                if (apiReply != null) {
                    callback(apiReply, InferenceResult(
                        text = apiReply,
                        source = "api_cerebras",
                        wasFallback = true,
                        complexityScore = complexity
                    ))
                } else {
                    // API also failed
                    callback(getFallbackReply(), InferenceResult(
                        text = getFallbackReply(),
                        source = "fallback",
                        wasFallback = true,
                        complexityScore = complexity
                    ))
                }
            }
        } else {
            // No API or not complex enough
            callback(getFallbackReply(), InferenceResult(
                text = getFallbackReply(),
                source = "fallback",
                wasFallback = true,
                complexityScore = complexity
            ))
        }
    }
}
```

### 7. Cerebras API Integration

```kotlin
private fun sendToCerebrasApi(
    senderName: String,
    message: String,
    systemPrompt: String,
    history: List<ChatMessage>,
    callback: (String?, AiUsage?) -> Unit,
) {
    executor.execute {
        try {
            if (!isCerebrasAvailable()) {
                callback(null, null)
                return@execute
            }
            
            val config = getCerebrasConfig()
            val url = URL(config.apiUrl)
            val conn = url.openConnection() as HttpURLConnection
            
            conn.apply {
                requestMethod = "POST"
                setRequestProperty("Authorization", "Bearer ${config.apiKey}")
                setRequestProperty("Content-Type", "application/json")
                connectTimeout = 15_000
                readTimeout = 15_000
            }
            
            val requestBody = buildCerebrasRequest(senderName, message, systemPrompt, history)
            conn.outputStream.write(requestBody.toByteArray())
            
            val statusCode = conn.responseCode
            val responseBody = conn.inputStream.bufferedReader().readText()
            
            when {
                statusCode == 200 -> {
                    val reply = parseCerebrasResponse(responseBody)
                    callback(reply, AiUsage())
                }
                statusCode == 401 || statusCode == 403 -> {
                    Log.e(TAG, "Cerebras API: Invalid API key (HTTP $statusCode)")
                    callback(null, AiUsage(error = "Invalid API key"))
                }
                statusCode == 429 -> {
                    Log.e(TAG, "Cerebras API: Rate limited (HTTP 429)")
                    callback(null, AiUsage(error = "API rate limited"))
                }
                else -> {
                    Log.e(TAG, "Cerebras API error: HTTP $statusCode")
                    callback(null, AiUsage(error = "API error"))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Cerebras API exception", e)
            callback(null, AiUsage(error = e.message))
        }
    }
}

private fun buildCerebrasRequest(
    senderName: String,
    message: String,
    systemPrompt: String,
    history: List<ChatMessage>,
): String {
    // Build JSON request body
    val messages = mutableListOf<Map<String, String>>()
    
    // System message
    messages.add(mapOf("role" to "system", "content" to systemPrompt))
    
    // History (last 5 messages)
    history.takeLast(5).forEach { msg ->
        messages.add(mapOf("role" to msg.role, "content" to msg.content))
    }
    
    // Current message
    messages.add(mapOf("role" to "user", "content" to "Message from $senderName: $message"))
    
    return """
    {
        "messages": ${messages.toJSON()},
        "max_tokens": 100,
        "temperature": 0.7
    }
    """.trimIndent()
}

private fun parseCerebrasResponse(responseBody: String): String? {
    // Parse JSON response and extract text
    try {
        val json = JSONObject(responseBody)
        return json.getJSONArray("choices")
            .getJSONObject(0)
            .getJSONObject("message")
            .getString("content")
    } catch (e: Exception) {
        Log.e(TAG, "Failed to parse Cerebras response", e)
        return null
    }
}
```

### 8. Prompt Formatting

**Qwen Format** (existing, unchanged):
```
<|im_start|>system
{system_prompt}
<|im_end|>
<|im_start|>user
{message}
<|im_end|>
<|im_start|>assistant

```

**Indra Format** (same as Qwen, since it uses Qwen's template):
```
<|im_start|>system
{system_prompt}
<|im_end|>
<|im_start|>user
{message}
<|im_end|>
<|im_start|>assistant

```

### 9. Configuration Storage

Store Cerebras API key in SharedPreferences (encrypted):
```kotlin
val sharedPrefs = context.getSharedPreferences("ai_config", Context.MODE_PRIVATE)

// Save API key
sharedPrefs.edit().putString("cerebras_api_key", encryptKey(apiKey)).apply()

// Load API key
val apiKey = decryptKey(sharedPrefs.getString("cerebras_api_key", ""))
```

## File Structure

```
PhiLocalService.kt (RENAME to AiLocalService.kt)
├── AiLocalService (main class)
│   ├── MODEL_REGISTRY (remove Phi, add Indra, add Cerebras)
│   ├── CerebrasConfig
│   ├── InferenceResult
│   ├── Model management methods
│   │   ├── getModelConfig()
│   │   ├── isModelAvailable()
│   │   ├── downloadModel()
│   │   ├── loadModel()
│   │   └── deleteModel()
│   ├── Local inference
│   │   ├── getAiReply()
│   │   ├── getAiReplyLocal()
│   │   ├── buildPrompt()
│   │   └── postProcess()
│   ├── Complexity & Language Detection
│   │   ├── detectComplexity()
│   │   ├── detectLanguage()
│   │   └── selectPrimaryModel()
│   ├── Cerebras API
│   │   ├── isCerebrasAvailable()
│   │   ├── getCerebrasConfig()
│   │   ├── setCerebrasApiKey()
│   │   ├── sendToCerebrasApi()
│   │   ├── buildCerebrasRequest()
│   │   └── parseCerebrasResponse()
│   └── Fallback Strategy
│       └── getAiReplyWithFallback()

ConfigManager.kt (NEW - optional, for API key management)
├── saveCerebrasApiKey()
├── loadCerebrasApiKey()
├── clearCerebrasApiKey()
└── validateApiKey()
```

## Implementation Phases

### Phase 1: Core Model Updates (Tasks 1-3)
1. Remove Phi model from MODEL_REGISTRY
2. Add Indra model configuration
3. Keep Qwen model unchanged

### Phase 2: Complexity Detection (Tasks 4-5)
4. Implement detectComplexity() algorithm
5. Implement detectLanguage() and selectPrimaryModel()

### Phase 3: Cerebras Integration (Tasks 6-9)
6. Add CerebrasConfig data class
7. Implement Cerebras API configuration storage
8. Implement sendToCerebrasApi()
9. Add API validation and error handling

### Phase 4: Fallback Strategy (Tasks 10-11)
10. Implement getAiReplyWithFallback() orchestration logic
11. Update getAiReply() to use new fallback strategy
12. Add comprehensive logging

### Phase 5: Testing & Polish (Tasks 12+)
13. Test local inference with Indra and Qwen
14. Test Cerebras API integration
15. Test fallback scenarios
16. Performance validation

## Dependencies

- Existing: Llama (llama.cpp), Kotlin Coroutines
- New: Possibly JSON parsing library (if not already included)
- HTTP client: Use built-in HttpURLConnection (already available)

## Error Handling Strategy

1. **Model not downloaded**: Show error, offer download
2. **Local inference fails**: Log error, try API if complex
3. **API key invalid**: Log error, fall back to local
4. **Network error**: Fall back to local
5. **Both fail**: Return generic fallback reply
6. **Timeout**: Return fallback reply after timeout

## Security Considerations

- Never log full API keys; use masking (first 10 chars + "...")
- Store API key in encrypted SharedPreferences
- Use HTTPS for Cerebras API
- Validate API key format before saving
- Clear API key on app uninstall/clear data

## Performance Targets

- Complexity detection: < 100ms
- Local inference: 30-90 seconds (device-dependent)
- Cerebras API call: < 15 seconds
- Model loading: 5-10 seconds
- Memory: Only 1 model loaded at a time
