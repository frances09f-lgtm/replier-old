# Bugfix Requirements Document

## Introduction

Local AI models (Gemma 270M, Gemma 3 1B, Llama 3.2 1B, Qwen3 0.6B) fail to produce useful auto-replies
in several distinct ways. The prompt sent to the on-device llama.cpp engine uses a plain-text
`"System: … \nUser: … \nAssistant:"` format that most GGUF instruct models do not recognise as a
proper chat template, causing them to ignore the system prompt, continue generating the prompt
rather than a reply, or produce no output at all. Additionally, the service silently swallows these
failures and falls back to a hardcoded generic phrase, making it impossible to know whether the
model genuinely replied or simply failed.

The three affected code paths are:
- `GemmaLocalService.buildPrompt()` — constructs a raw-text prompt instead of the
  model-specific chat template (e.g. `<start_of_turn>` for Gemma, `<|im_start|>` for Qwen3,
  `<|begin_of_text|>` for Llama 3).
- `GemmaLocalService.getAiReplyBatch()` — on timeout or empty result, silently returns a
  fallback generic reply with no error propagation to the notification layer.
- `AppNotificationListenerService.sendBatchedAiReply()` — treats a non-null fallback reply as
  a successful AI reply and sends it, bypassing the `onBatchResult` error signal.

---

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN a local model (any of Gemma 270M, Gemma 1B, Llama 3.2 1B, Qwen3 0.6B) is selected and
    `getAiReplyBatch()` is called with a non-empty system prompt THEN the system formats the prompt
    as plain `"System: <text>\nUser: <text>\nAssistant:"` — a format those instruct models do not
    recognise — so the model ignores or echoes the system prompt instead of following it.

1.2 WHEN the plain-text prompt is passed to a Gemma instruct model THEN the system receives
    output that begins with a repetition of the prompt text or a continuation of the user message
    rather than an assistant reply, because Gemma expects `<start_of_turn>model` / `<end_of_turn>`
    delimiters.

1.3 WHEN the plain-text prompt is passed to a Qwen3 instruct model THEN the system receives
    output that ignores the system instruction because Qwen3 expects `<|im_start|>system` /
    `<|im_end|>` delimiters.

1.4 WHEN the plain-text prompt is passed to a Llama 3.2 instruct model THEN the system receives
    output that ignores the system instruction because Llama 3 expects the
    `<|begin_of_text|><|start_header_id|>system<|end_header_id|>` template.

1.5 WHEN `Llama.complete()` times out after 60 seconds THEN the system silently returns a random
    hardcoded fallback string (e.g. "Thanks for your message!") via the callback without signalling
    a failure, so the caller cannot distinguish a genuine AI reply from a timeout fallback.

1.6 WHEN `Llama.complete()` returns a result whose `text` field is blank or null THEN the system
    silently returns a random hardcoded fallback string via the callback without logging enough
    context to diagnose which model produced the empty output.

1.7 WHEN `sendBatchedAiReply()` receives the fallback reply from `onBatchResult` it treats it as
    a valid AI reply, records it in `ConversationHistory`, and sends it to the recipient — even
    though the model failed to generate a real response.

### Expected Behavior (Correct)

2.1 WHEN a local model is selected and `getAiReplyBatch()` is called with a system prompt THEN the
    system SHALL format the prompt using the correct chat template for that model family:
    - Gemma models: `<start_of_turn>user\n…<end_of_turn>\n<start_of_turn>model\n`
    - Qwen3 models: `<|im_start|>system\n…<|im_end|>\n<|im_start|>user\n…<|im_end|>\n<|im_start|>assistant\n`
    - Llama 3 models: `<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n…<|eot_id|><|start_header_id|>user<|end_header_id|>\n…<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n`

2.2 WHEN the model-specific chat template is used THEN the system SHALL produce a reply that
    reflects the content of the system prompt (e.g. language, tone, persona) instead of
    echoing or ignoring it.

2.3 WHEN `Llama.complete()` times out THEN the system SHALL invoke the callback with a `null`
    reply and an `AiUsage` object whose `error` field is set to `"Inference timed out"`, so
    the caller can handle the failure explicitly.

2.4 WHEN `Llama.complete()` returns blank/null text THEN the system SHALL invoke the callback
    with a `null` reply and an `AiUsage` object whose `error` field is set to `"Empty response"`,
    and SHALL log the model ID and prompt length for diagnostics.

2.5 WHEN `sendBatchedAiReply()` receives a `null` reply from `onBatchResult` THEN the system
    SHALL NOT send any message to the recipient and SHALL log the failure with the sender name
    and model type.

### Unchanged Behavior (Regression Prevention)

3.1 WHEN the `smart_reply` model type is selected THEN the system SHALL CONTINUE TO call
    `SmartReplyService.getAiReplyBatch()` exactly as before, with no change to that code path.

3.2 WHEN a matched rule exists for an incoming message THEN the system SHALL CONTINUE TO send the
    rule-based reply directly, without invoking `GemmaLocalService`.

3.3 WHEN a local model is not yet downloaded (`isModelAvailable()` returns false) THEN the system
    SHALL CONTINUE TO return a `null` reply with an `AiUsage` error of `"Model not downloaded"`.

3.4 WHEN `getAiReply()` is called from the Flutter UI test screen via the `chatWithGemmaLocal`
    MethodChannel THEN the system SHALL CONTINUE TO return the model response (or a structured
    error) through `result.success` / `result.error` as before.

3.5 WHEN the conversation history is non-empty THEN the system SHALL CONTINUE TO include prior
    turns in the formatted prompt so the model has context for its reply.

3.6 WHEN `postProcess()` cleans the raw model output THEN the system SHALL CONTINUE TO strip
    model-specific special tokens (`<end_of_turn>`, `<bos>`, `<eos>`) and truncate to 500
    characters.

3.7 WHEN `confirmBeforeReply` is enabled and a valid AI reply is produced THEN the system SHALL
    CONTINUE TO show the confirmation notification before sending.

---

## Bug Condition Pseudocode

### Bug Condition Function

```pascal
FUNCTION isBugCondition(X)
  INPUT: X of type InferenceRequest { modelId, systemPrompt, messages }
  OUTPUT: boolean

  // Bug triggers when a local instruct model is used — the current plain-text
  // prompt format is not recognised by any of these model families.
  RETURN X.modelId IN {"gemma_270m", "gemma_1b", "bharat_tiny", "qwen3_0.6b"}
END FUNCTION
```

### Fix Checking Property

```pascal
// Property: Fix Checking — model-specific templates produce on-topic replies
FOR ALL X WHERE isBugCondition(X) DO
  result ← getAiReplyBatch'(X)
  // A reply that respects the system prompt must differ from a generic fallback
  // and must not be an echo of the input
  ASSERT result ≠ fallbackReplies.any()
       AND result does NOT start_with(X.messages.last())
       AND result reflects systemPrompt intent
END FOR
```

### Silent Failure Fix Checking Property

```pascal
// Property: No silent fallback on timeout or empty output
FOR ALL X WHERE isBugCondition(X) AND (timeout OR empty_output) DO
  (reply, usage) ← getAiReplyBatch'(X)
  ASSERT reply = null
       AND usage.error ≠ null
       AND usage.error ≠ ""
END FOR
```

### Preservation Checking Property

```pascal
// Property: Preservation Checking — non-local-AI paths are unaffected
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT F(X) = F'(X)   // smart_reply, rule-based, and busy-mode paths unchanged
END FOR
```
