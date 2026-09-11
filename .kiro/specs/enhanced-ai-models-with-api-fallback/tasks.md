# Tasks: Enhanced AI Models with API Fallback

## Task 1: Update MODEL_REGISTRY - Remove Phi, Keep Qwen, Add Indra

**Objective:** Update the MODEL_REGISTRY in AiLocalService to reflect the new model strategy.

**Description:**
Remove the Phi-3.5 Mini model entry and add the Indra multilingual model. The Qwen2.5 1.5B model should remain unchanged.

**Acceptance Criteria:**
- [ ] "phi_3_5_mini" entry removed from MODEL_REGISTRY
- [ ] "qwen2_5_1_5b" entry remains unchanged with original configuration
- [ ] "indra_model" entry added with:
  - id: "indra_model"
  - displayName: "Indra Model (Multilingual + Marathi)"
  - filename: "indra-instruct-q4_k_m.gguf"
  - url: pointing to valid HuggingFace Indra model GGUF download
  - sizeBytes: 2_500_000_000L (2.5GB estimated)
  - description: "~2.5GB, multilingual with Marathi support"
  - threads: 4
  - contextSize: 4096
- [ ] MODEL_REGISTRY contains only Qwen and Indra models
- [ ] No references to Phi remain in the model registry

**Sub-tasks:**
- Find and verify Indra model GGUF download URL from HuggingFace
- Update ModelConfig class if needed to support language metadata
- Update any documentation or comments referencing removed Phi model

---

## Task 2: Add CerebrasConfig Data Class

**Objective:** Create a data class to manage Cerebras API configuration.

**Description:**
Add a new data class to store Cerebras API configuration including API key, API endpoint, model name, and timeout values.

**Acceptance Criteria:**
- [ ] CerebrasConfig data class created with fields:
  - apiKey: String (default empty)
  - apiUrl: String (default "https://api.cerebras.ai/v1/chat/completions")
  - model: String (default appropriate model identifier)
  - timeout: Long (default 15_000L)
- [ ] CerebrasConfig can be instantiated and copied
- [ ] All fields have appropriate default values
- [ ] Class is located in AiLocalService.kt or separate file

---

## Task 3: Implement Cerebras API Configuration Storage

**Objective:** Add methods to save and retrieve Cerebras API key from persistent storage.

**Description:**
Implement methods in AiLocalService to securely store and retrieve the Cerebras API key from SharedPreferences. Include validation and masking for logging.

**Acceptance Criteria:**
- [ ] getCerebrasConfig() method returns current CerebrasConfig
- [ ] setCerebrasApiKey(apiKey: String) method saves API key to SharedPreferences
- [ ] loadCerebrasApiKey() method retrieves saved API key from SharedPreferences
- [ ] isCerebrasAvailable() method returns true only if API key is non-empty
- [ ] clearCerebrasApiKey() method removes saved API key
- [ ] API key is not logged in full (use masking like "abc123..." in logs)
- [ ] Retrieval persists across app restarts
- [ ] Empty/blank API key is treated as unavailable

---

## Task 4: Implement Complexity Detection Algorithm

**Objective:** Create an algorithm to detect message complexity and determine if API fallback is needed.

**Description:**
Implement the detectComplexity(message: String) function that analyzes incoming messages and returns a complexity score from 0-100.

**Acceptance Criteria:**
- [ ] detectComplexity() function created and returns Int (0-100)
- [ ] Algorithm scores based on:
  - Message length (longer = more complex)
  - Question count (more questions = more complex)
  - Unique word ratio (more variety = more complex)
  - Special characters count
  - Technical keywords presence (code, bug, error, etc.)
  - Code block indicators ({}, ```, etc.)
- [ ] Score is capped at 0-100 range
- [ ] Execution time < 100ms on typical messages
- [ ] Score >= 70 indicates "complex" message
- [ ] Unit tests cover:
  - Simple message: "Thanks" → low score
  - Complex message with technical terms → high score
  - Long message with questions → high score

---

## Task 5: Implement Language Detection and Model Selection

**Objective:** Detect message language and select appropriate model (Qwen for English, Indra for Marathi).

**Description:**
Implement detectLanguage() and selectPrimaryModel() functions to automatically choose the best local model based on message content.

**Acceptance Criteria:**
- [ ] detectLanguage(message: String) returns "mr" for Marathi, "en" for others
- [ ] Marathi detection uses:
  - Marathi script detection (Devanagari Unicode range)
  - Common Marathi words (नमस्ते, धन्यवाद, etc.)
- [ ] selectPrimaryModel(message: String) returns modelId
- [ ] Logic: 
  - If Marathi detected AND Indra available → "indra_model"
  - Otherwise → "qwen2_5_1_5b"
- [ ] Function respects user's manually selected model preference (if set)
- [ ] Language detection < 50ms execution time
- [ ] Unit tests cover:
  - Marathi message detection
  - English message detection
  - Mixed language fallback

---

## Task 6: Implement Cerebras API Request Builder

**Objective:** Create methods to build and send requests to the Cerebras API.

**Description:**
Implement buildCerebrasRequest() to construct properly formatted JSON requests for the Cerebras API including messages, tokens, and parameters.

**Acceptance Criteria:**
- [ ] buildCerebrasRequest() method creates JSON with:
  - System message (using provided systemPrompt)
  - Last 5 messages from conversation history
  - Current user message with sender name
  - max_tokens: 100
  - temperature: 0.7
- [ ] Request format is valid JSON
- [ ] Message format: {"role": "user"/"assistant", "content": "..."}
- [ ] Handles empty history gracefully
- [ ] Request is properly escaped and formatted

---

## Task 7: Implement Cerebras API Response Parser

**Objective:** Create method to parse Cerebras API response and extract the generated reply.

**Description:**
Implement parseCerebrasResponse() to extract the AI-generated text from Cerebras API JSON responses.

**Acceptance Criteria:**
- [ ] parseCerebrasResponse() method parses JSON response
- [ ] Extracts text from response.choices[0].message.content
- [ ] Returns null if response format is invalid
- [ ] Handles and logs parsing errors
- [ ] Works with standard OpenAI-compatible API format
- [ ] Unit tests cover:
  - Valid response parsing
  - Invalid JSON handling
  - Missing fields handling

---

## Task 8: Implement sendToCerebrasApi() Method

**Objective:** Implement HTTP communication with the Cerebras API.

**Description:**
Implement sendToCerebrasApi() to make HTTP POST requests to the Cerebras API endpoint with proper error handling and timeouts.

**Acceptance Criteria:**
- [ ] sendToCerebrasApi() method signature:
  - Parameters: senderName, message, systemPrompt, history, callback
  - Runs on executor thread (async)
- [ ] HTTP POST request with:
  - URL: from CerebrasConfig
  - Authorization: Bearer token with API key
  - Content-Type: application/json
  - Timeout: 15 seconds
- [ ] Handles HTTP status codes:
  - 200: Success, parse and return response
  - 401/403: API key invalid, log error
  - 429: Rate limited, log error
  - 5xx: Server error, log error
  - Other: Generic error
- [ ] Network errors caught and logged
- [ ] Timeout enforced (15 seconds max)
- [ ] Callback invoked with response or null on error
- [ ] No blocking operations on main thread

---

## Task 9: Implement API Error Handling and Validation

**Objective:** Add robust error handling and validation for Cerebras API interactions.

**Description:**
Implement error handling, logging, and recovery mechanisms for API failures.

**Acceptance Criteria:**
- [ ] Invalid API key detected and handled gracefully
- [ ] Rate limit errors (429) trigger graceful degradation
- [ ] Network timeouts return appropriate error message
- [ ] All API errors logged with context (timestamp, error code)
- [ ] API key validation before API call (basic format check)
- [ ] Fallback to local model on any API error
- [ ] Error messages user-friendly (not exposing internal details)
- [ ] Clear logging distinguishes between different error types
- [ ] No crashes on API failures

---

## Task 10: Implement getAiReplyLocal() Method

**Objective:** Extract existing local inference logic into a dedicated method.

**Description:**
Refactor existing getAiReply() logic into a separate getAiReplyLocal() method that handles only local model inference.

**Acceptance Criteria:**
- [ ] getAiReplyLocal() method created with parameters:
  - modelId, senderName, message, systemPrompt, history, callback
- [ ] Contains existing local inference logic unchanged
- [ ] Runs on executor thread
- [ ] Calls buildPrompt() and postProcess()
- [ ] Returns callback with (reply, AiUsage)
- [ ] Handles model not available
- [ ] Handles model loading failures
- [ ] Handles inference timeouts (60 seconds)
- [ ] Logs inference results

---

## Task 11: Implement getAiReplyWithFallback() Orchestration

**Objective:** Create the main inference orchestration logic that coordinates local and API fallback.

**Description:**
Implement getAiReplyWithFallback() that combines complexity detection, local inference, and API fallback into a coherent strategy.

**Acceptance Criteria:**
- [ ] getAiReplyWithFallback() method with parameters:
  - primaryModelId, senderName, message, systemPrompt, history, callback
- [ ] Execution flow:
  1. Detect message complexity (0-100 score)
  2. Attempt local inference with primary model
  3. If local succeeds → return local response
  4. If local fails AND complexity >= 70 AND API available → try Cerebras
  5. If API succeeds → return API response with "api_fallback" indicator
  6. If both fail → return generic fallback reply
- [ ] InferenceResult includes:
  - text (the reply)
  - source ("local_qwen", "local_indra", "api_cerebras", "fallback")
  - complexityScore
  - wasFallback (boolean)
  - responseTimeMs
- [ ] Logging at each decision point
- [ ] Timeout enforcement:
  - Local: 60 seconds
  - API: 15 seconds total
- [ ] Non-blocking (uses executor)

---

## Task 12: Update getAiReply() to Use Intelligent Routing

**Objective:** Update existing getAiReply() to use intelligent model selection and fallback strategy.

**Description:**
Modify the public getAiReply() API to use the new intelligent routing, language detection, and fallback strategy.

**Acceptance Criteria:**
- [ ] getAiReply() calls selectPrimaryModel() to choose Qwen or Indra
- [ ] getAiReply() delegates to getAiReplyWithFallback()
- [ ] Existing API signature unchanged (backwards compatible)
- [ ] Complexity score logged
- [ ] Model selection logged
- [ ] Language detection logged
- [ ] Fallback reason logged when applicable
- [ ] Works with empty history
- [ ] Works with non-empty history (last 5 messages)

---

## Task 13: Update buildPrompt() for Indra Model

**Objective:** Ensure buildPrompt() correctly handles Indra model format.

**Description:**
Update buildPrompt() to recognize Indra model and format prompts appropriately (same as Qwen format).

**Acceptance Criteria:**
- [ ] buildPrompt() detects Indra model by checking modelId
- [ ] Indra uses same chat format as Qwen:
  - `<|im_start|>system\n{prompt}<|im_end|>\n`
  - `<|im_start|>user\n{message}<|im_end|>\n`
  - `<|im_start|>assistant\n`
- [ ] History messages formatted correctly
- [ ] System prompt uses default if empty
- [ ] Prompt length logged for debugging
- [ ] Supports Marathi text in prompts
- [ ] No encoding issues with Marathi characters

---

## Task 14: Update postProcess() for Multiple Models

**Objective:** Ensure post-processing works correctly for all models (Qwen and Indra).

**Description:**
Verify that postProcess() correctly cleans responses from both Qwen and Indra models.

**Acceptance Criteria:**
- [ ] Removes both Phi and Qwen special tokens (for compatibility):
  - `<|end|>`, `<|system|>`, `<|user|>`, `<|assistant|>`
  - `<|im_start|>`, `<|im_end|>`
- [ ] Removes common model artifacts:
  - `<end_of_turn>`, `<bos>`, `<eos>`
- [ ] Removes role prefixes at start of text:
  - "Assistant:", "Human:", "User:"
- [ ] Limits response to 300 characters
- [ ] Handles Marathi text without corruption
- [ ] Returns fallback if result is empty
- [ ] Logs input and output for debugging

---

## Task 15: Add Comprehensive Logging

**Objective:** Add detailed logging throughout the inference pipeline for debugging and monitoring.

**Description:**
Add structured logging at key decision points to track which models are used, why fallbacks happen, and performance metrics.

**Acceptance Criteria:**
- [ ] Each inference attempt logs:
  - Message received timestamp
  - Complexity score
  - Model selected (and reason)
  - Local inference result (success/failure, time)
  - Fallback triggered (reason)
  - Final result source
  - Total response time
- [ ] API usage logs:
  - API call initiated
  - API response received or failed
  - Error code if failed
  - Response time
- [ ] API key never logged in full (mask as "abc...xyz")
- [ ] Errors logged with full stack traces
- [ ] Different log levels:
  - DEBUG: Detailed flow (complexity score, model selection)
  - INFO: Major decision points (fallback trigger, API used)
  - WARN: Recoverable errors (model not loaded)
  - ERROR: Failures (API error, inference failure)
- [ ] Timestamp on every log entry
- [ ] Model ID in every log for filtering

---

## Task 16: Test Complexity Detection with Various Inputs

**Objective:** Verify the complexity detection algorithm works correctly with diverse message types.

**Description:**
Write and run tests to validate complexity detection across simple, medium, and complex messages.

**Acceptance Criteria:**
- [ ] Test cases created and passing:
  - Simple message (< 50 chars, no questions): score < 30
  - Medium message (100 chars, 1 question): score 30-70
  - Complex message (technical terms, code): score > 70
  - Long message (> 300 chars): elevated score
  - Message with code blocks: high score
  - Marathi message: score based on content, not language
- [ ] All tests pass with consistent results
- [ ] Performance test: 100 messages processed in < 100ms average

---

## Task 17: Test Language Detection with Marathi and English

**Objective:** Verify language detection correctly identifies Marathi vs English messages.

**Description:**
Write and run tests for language detection and model selection.

**Acceptance Criteria:**
- [ ] Test cases created and passing:
  - Pure Marathi message: detects "mr"
  - Pure English message: detects "en"
  - Mixed Marathi/English: detects "mr" (Marathi takes precedence)
  - Message with Marathi script: detects "mr"
  - Message with common Marathi words: detects "mr"
- [ ] Model selection respects detection:
  - Marathi → Indra (if available) or Qwen
  - English → Qwen
- [ ] All tests pass

---

## Task 18: Test Local Inference with Qwen and Indra

**Objective:** Verify local inference works correctly with both Qwen and Indra models.

**Description:**
Test that both models can be downloaded, loaded, and used for inference.

**Acceptance Criteria:**
- [ ] Manual test (or integration test):
  - Download Qwen model (if not present)
  - Load Qwen model
  - Generate reply with sample message
  - Verify reply is sensible and non-empty
- [ ] Indra model test:
  - Download Indra model (if not present, skip if unavailable)
  - Load Indra model
  - Generate reply with Marathi message
  - Verify reply is non-empty
- [ ] Both models can be loaded without crashes
- [ ] Inference completes within 60-second timeout
- [ ] Response is post-processed correctly
- [ ] Models can be unloaded without memory leaks

---

## Task 19: Test Cerebras API Integration (Mocked)

**Objective:** Verify Cerebras API integration works with mock/test API.

**Description:**
Test Cerebras API communication with a mock endpoint or test account (if available).

**Acceptance Criteria:**
- [ ] API request builder creates valid JSON
- [ ] API request includes all required fields
- [ ] API key is used in Authorization header
- [ ] Request times out after 15 seconds
- [ ] 200 response parsed correctly
- [ ] 401/403 errors detected
- [ ] 429 rate limit errors detected
- [ ] Network errors caught and logged
- [ ] Response parser handles edge cases
- [ ] Callback invoked with correct parameters

---

## Task 20: Test Fallback Scenario - Local Failure → API Success

**Objective:** Verify fallback logic works when local inference fails but API succeeds.

**Description:**
Test scenario where local model fails but Cerebras API is available and succeeds.

**Acceptance Criteria:**
- [ ] Complex message sent to system
- [ ] Local inference fails (simulated)
- [ ] System attempts Cerebras API
- [ ] API response received and returned
- [ ] InferenceResult.source = "api_cerebras"
- [ ] InferenceResult.wasFallback = true
- [ ] Logging indicates fallback reason
- [ ] User receives valid response

---

## Task 21: Test Fallback Scenario - Both Fail → Generic Reply

**Objective:** Verify system returns graceful fallback when both local and API fail.

**Description:**
Test scenario where both local inference and API call fail.

**Acceptance Criteria:**
- [ ] Message sent to system
- [ ] Local inference fails
- [ ] Cerebras API unavailable or fails
- [ ] Generic fallback reply returned
- [ ] InferenceResult.source = "fallback"
- [ ] InferenceResult.wasFallback = true
- [ ] Error is logged
- [ ] System doesn't crash
- [ ] User sees sensible message

---

## Task 22: Test Simple Message Skips API

**Objective:** Verify simple messages don't trigger API fallback.

**Description:**
Test that simple messages (complexity < 70) don't attempt API call even if available.

**Acceptance Criteria:**
- [ ] Simple message sent ("Thanks!")
- [ ] Complexity score < 70
- [ ] Local inference attempted
- [ ] If local succeeds: API NOT called
- [ ] Response returned from local only
- [ ] InferenceResult.source = "local_qwen"
- [ ] Performance: no unnecessary API overhead
- [ ] Logging confirms API not attempted

---

## Task 23: Test API Key Management

**Objective:** Verify API key can be saved, retrieved, and cleared correctly.

**Description:**
Test Cerebras API key configuration storage and retrieval.

**Acceptance Criteria:**
- [ ] setCerebrasApiKey() saves key to SharedPreferences
- [ ] loadCerebrasApiKey() retrieves key
- [ ] isCerebrasAvailable() returns false when key empty
- [ ] isCerebrasAvailable() returns true when key set
- [ ] clearCerebrasApiKey() removes key
- [ ] Invalid/blank keys handled gracefully
- [ ] Key persists across object recreation
- [ ] Retrieval works after app restart (simulated)

---

## Task 24: Performance Validation

**Objective:** Verify system meets performance targets.

**Description:**
Measure and validate performance metrics across all operations.

**Acceptance Criteria:**
- [ ] Complexity detection: < 100ms per message
- [ ] Language detection: < 50ms per message
- [ ] Local inference: 30-90 seconds (device-dependent)
- [ ] Cerebras API call: < 15 seconds timeout
- [ ] Model loading: 5-10 seconds
- [ ] Prompt building: < 100ms
- [ ] Post-processing: < 50ms
- [ ] Only 1 model loaded in memory at a time
- [ ] No memory leaks on repeated inference calls

---

## Task 25: Documentation and Code Comments

**Objective:** Add comprehensive documentation and comments for maintainability.

**Description:**
Add KDoc comments to all new methods and classes, update class overview documentation.

**Acceptance Criteria:**
- [ ] AiLocalService class javadoc updated
- [ ] All public methods have KDoc comments
- [ ] All parameters documented
- [ ] Return values documented
- [ ] Key algorithms documented (complexity detection, selection logic)
- [ ] Configuration storage documented
- [ ] Fallback strategy documented
- [ ] Code follows Kotlin style guide
- [ ] Comments explain "why", not just "what"

---

## Task 26: Update Import Statements and Rename Class

**Objective:** Rename PhiLocalService to AiLocalService and update references.

**Description:**
Rename the service class to reflect that it's no longer Phi-specific and handles multiple models.

**Acceptance Criteria:**
- [ ] File renamed: PhiLocalService.kt → AiLocalService.kt
- [ ] Class name changed: PhiLocalService → AiLocalService
- [ ] Singleton instance updated
- [ ] All imports updated in other files
- [ ] References in AndroidManifest updated (if any)
- [ ] Documentation/comments updated
- [ ] No broken references
- [ ] App compiles and runs without errors

