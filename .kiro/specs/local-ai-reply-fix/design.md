# Local AI Reply Fix — Bugfix Design

## Overview

Three related bugs cause local AI models (Gemma 270M, Gemma 3 1B, Llama 3.2 1B, Qwen3 0.6B) to
silently fail at producing useful auto-replies.

**Bug 1 — Wrong prompt format:** `GemmaLocalService.buildPrompt()` uses a plain-text
`"System: …\nUser: …\nAssistant:"` format that no GGUF instruct model recognises as a chat
template. Each model family requires its own delimiter scheme.

**Bug 2 — Silent fallback on failure:** `GemmaLocalService.getAiReplyBatch()` returns a
hardcoded random string on timeout or empty output instead of signalling failure via a `null`
reply and a populated `AiUsage.error`.

**Bug 3 — Sending the fallback as a real reply:** `AppNotificationListenerService.sendBatchedAiReply()`
receives the non-null fallback from the `onBatchResult` callback and sends it to the recipient
as if it were a genuine AI reply, because it only checks for `null`.

The fix strategy is:
1. Replace `buildPrompt()` with a model-family-aware `buildChatPrompt()` that dispatches to a
   per-family template builder.
2. Change every `callback(fallbackReplies.random(), …)` failure path in `getAiReplyBatch()` to
   `callback(null, AiUsage(error = "…"))`.
3. Add a `null` guard in `onBatchResult` inside `sendBatchedAiReply()` and log the failure
   instead of forwarding to the send path.

---

## Glossary

- **Bug_Condition (C)**: An `InferenceRequest` whose `modelId` is one of the four local model IDs
  (`gemma_270m`, `gemma_1b`, `bharat_tiny`, `qwen3_0.6b`). These are the only inputs affected by
  the wrong chat template and the silent fallback.
- **Property (P)**: For any input where C holds and inference succeeds, the reply must reflect the
  system prompt and not be a hardcoded fallback string; for failure paths the reply must be `null`
  with a non-null `AiUsage.error`.
- **Preservation**: All code paths where C does **not** hold — `smart_reply`, rule-based replies,
  busy mode, model-not-downloaded, Flutter UI channel — must produce identical behaviour before and
  after the fix.
- **`buildPrompt()`**: The private method in `GemmaLocalService.kt` (line ~230) that currently
  appends plain `"System: / User: / Assistant:"` labels.
- **`getAiReplyBatch()`**: The public method in `GemmaLocalService.kt` (line ~190) that runs
  inference on the executor thread and calls back with `(String?, AiUsage?)`.
- **`sendBatchedAiReply()`**: The private method in `AppNotificationListenerService.kt` (line ~330)
  that assembles the `onBatchResult` closure, dispatches to the selected AI service, and (after fix)
  must guard against a `null` reply.
- **`onBatchResult`**: The lambda inside `sendBatchedAiReply()` that processes the AI result and
  either queues a send or triggers the confirmation notification.
- **Chat template**: Model-family-specific string delimiters inserted around system/user/assistant
  turns so the GGUF instruct model correctly identifies each role.

---

## Bug Details

### Bug Condition

The bug manifests whenever a local instruct model is selected and `getAiReplyBatch()` is invoked
with a system prompt. `buildPrompt()` ignores `modelId` entirely and always produces the same
plain-text format, which none of the four supported instruct models recognise as a proper chat
template.

**Formal Specification:**

```
FUNCTION isBugCondition(X)
  INPUT: X of type InferenceRequest { modelId, systemPrompt, messages }
  OUTPUT: boolean

  RETURN X.modelId IN {"gemma_270m", "gemma_1b", "bharat_tiny", "qwen3_0.6b"}
END FUNCTION
```

### Examples

| # | Input | Current (defective) output | Expected output |
|---|-------|---------------------------|-----------------|
| 1 | `modelId=gemma_270m`, system prompt "Reply in French", message "Hello" | Model echoes `"System: Reply in French\nUser: Hello\n…"` or ignores system prompt entirely | Short French reply reflecting the system instruction |
| 2 | `modelId=qwen3_0.6b`, any system prompt | `<\|im_start\|>` delimiters absent → model continues generating prompt text instead of a reply | Reply wrapped in Qwen3 `<\|im_start\|>assistant` … `<\|im_end\|>` template |
| 3 | `modelId=bharat_tiny` (Llama 3.2), inference takes > 60 s | `callback("Thanks for your message!", AiUsage(error="Inference timed out"))` — fallback sent as real reply | `callback(null, AiUsage(error="Inference timed out"))` — nothing sent |
| 4 | `modelId=gemma_1b`, model returns blank text | `callback("Noted, thank you!", AiUsage(error="Empty response"))` — fallback sent | `callback(null, AiUsage(error="Empty response"))` — nothing sent, failure logged with modelId |

---

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- `SmartReplyService.getAiReplyBatch()` call path in `sendBatchedAiReply()` — no changes to that
  branch or the `SmartReplyService` class itself.
- Rule-based reply path in `onNotificationPosted()` — completely unaffected.
- Busy-mode reply path — completely unaffected.
- The `model not downloaded` early-return in `getAiReplyBatch()` already returns
  `callback(fallbackReplies.random(), AiUsage(error="Model not downloaded"))`. This path will be
  updated to `callback(null, …)` only for consistency — _this is part of the fix scope_.
- `getAiReply()` (single-message wrapper) delegates to `getAiReplyBatch()` — no independent change
  needed; it inherits the fix.
- `postProcess()` — no changes.
- Conversation history inclusion in `buildChatPrompt()` — each prior turn must still be appended
  in the new template format.
- `confirmBeforeReply` flow — the existing `showConfirmationNotification` call in `onBatchResult`
  is guarded by the same `aiReply != null` check, so it is automatically preserved.
- Flutter UI test screen (`chatWithGemmaLocal` MethodChannel / `getAiReply()`) — returns the model
  response or a structured error; no change to that surface.

**Scope:**
All inputs where `isBugCondition(X)` returns `false` — i.e., `modelType == "smart_reply"`,
rule-matched messages, busy mode, and the Flutter UI test path — must be completely unaffected.

---

## Hypothesized Root Cause

1. **`buildPrompt()` is model-agnostic**: The method does not receive or use `modelId`. It always
   formats `"System: …\nUser: …\nAssistant:"`, which is not part of any of the four model families'
   expected chat templates. Instruct GGUFs rely entirely on these delimiters to separate roles;
   without them the model treats the whole string as continuation input.

2. **`getAiReplyBatch()` uses `fallbackReplies.random()` for all failure branches**: The timeout
   branch (`result == null`), the empty-output branch (`reply.isBlank()`), the load-failure
   branch, and even the model-not-downloaded branch all pass a non-null string to the callback.
   `sendBatchedAiReply()` therefore cannot tell a real reply from a failure — the only signal is
   `AiUsage.error`, which it never inspects.

3. **`onBatchResult` in `sendBatchedAiReply()` checks `aiReply != null && aiReply.isNotBlank()`
   but the fallback is always non-null and non-blank**: So every failure slips through the `if`
   guard, gets written to `ConversationHistory`, and is sent via `sendReply()`.

---

## Correctness Properties

Property 1: Bug Condition — Model-Specific Chat Templates Produce On-Topic Replies

_For any_ `InferenceRequest X` where `isBugCondition(X)` is true and inference completes without
timeout or empty output, the fixed `getAiReplyBatch'(X)` SHALL invoke the callback with a non-null
reply that:
- is NOT a member of `fallbackReplies`,
- does NOT start with a verbatim repetition of the last user message, and
- reflects the intent of `X.systemPrompt` (e.g. language, persona, tone).

**Validates: Requirements 2.1, 2.2**

Property 2: Silent Failure Elimination — Null Reply on Timeout or Empty Output

_For any_ `InferenceRequest X` where `isBugCondition(X)` is true and inference times out or
returns blank/null text, the fixed `getAiReplyBatch'(X)` SHALL invoke the callback with
`reply = null` and `usage.error` set to a non-empty, non-null string describing the failure.

**Validates: Requirements 2.3, 2.4**

Property 3: Preservation — Non-Local-AI Paths Are Unaffected

_For any_ input `X` where `isBugCondition(X)` is false (i.e. `modelType` is `"smart_reply"`,
a rule match exists, busy mode is active, or the `getAiReply()` Flutter channel path is invoked),
the fixed code SHALL produce exactly the same observable behaviour as the original code.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7**

---

## Fix Implementation

### Changes Required

#### File: `android/app/src/main/kotlin/com/example/auto_reply_assistant/service/GemmaLocalService.kt`

**Function: `buildPrompt()` → replace with `buildChatPrompt(modelId, systemPrompt, history, incomingMessage)`**

1. **Add model-family detection helper**:
   ```
   FUNCTION modelFamily(modelId): String
     IF modelId IN {"gemma_270m", "gemma_1b"} THEN RETURN "gemma"
     IF modelId == "bharat_tiny"               THEN RETURN "llama3"
     IF modelId == "qwen3_0.6b"                THEN RETURN "chatml"
     RETURN "chatml"  // safe default
   END FUNCTION
   ```

2. **Implement Gemma template builder** (`<start_of_turn>` / `<end_of_turn>`):
   - Prefix system text inside the first user turn (Gemma has no dedicated system turn):
     `<start_of_turn>user\n{systemPrompt}\n\n{userText}<end_of_turn>\n<start_of_turn>model\n`
   - History turns: wrap each pair in `<start_of_turn>user … <end_of_turn>\n<start_of_turn>model … <end_of_turn>\n`

3. **Implement Llama 3 template builder** (`<|begin_of_text|>` / `<|eot_id|>`):
   - `<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n{systemPrompt}<|eot_id|>`
   - History: `<|start_header_id|>user<|end_header_id|>\n\n{text}<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n{text}<|eot_id|>`
   - Final user turn: `…user…\n\n{incomingMessage}<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n`

4. **Implement ChatML template builder** (`<|im_start|>` / `<|im_end|>`, used by Qwen3):
   - `<|im_start|>system\n{systemPrompt}<|im_end|>\n`
   - History: `<|im_start|>user\n{text}<|im_end|>\n<|im_start|>assistant\n{text}<|im_end|>\n`
   - Final: `<|im_start|>user\n{incomingMessage}<|im_end|>\n<|im_start|>assistant\n`

5. **Pass `modelId` through**: Update the call site in `getAiReplyBatch()` from
   `buildPrompt(systemPrompt, history, combinedMessage)` to
   `buildChatPrompt(modelId, systemPrompt, conversationHistory, combinedMessage)`.

**Function: `getAiReplyBatch()` — eliminate all `fallbackReplies.random()` returns**

6. **Model not downloaded branch**: change
   `callback(fallbackReplies.random(), AiUsage(error = "Model not downloaded"))` →
   `callback(null, AiUsage(error = "Model not downloaded"))`

7. **Load failure branch**: change
   `callback(fallbackReplies.random(), AiUsage(error = "Failed to load model"))` →
   `callback(null, AiUsage(error = "Failed to load model"))`

8. **Timeout branch**: change
   `callback(fallbackReplies.random(), AiUsage(error = "Inference timed out"))` →
   `callback(null, AiUsage(error = "Inference timed out"))`
   Also add: `Log.e(TAG, "Inference timed out for $modelId (prompt length: ${prompt.length})")`

9. **Empty-output branch**: change
   `callback(fallbackReplies.random(), AiUsage(error = "Empty response"))` →
   `callback(null, AiUsage(error = "Empty response"))`
   Also add: `Log.e(TAG, "Empty response from $modelId (prompt length: ${prompt.length})")`

10. **Exception branch**: change
    `callback(fallbackReplies.random(), AiUsage(error = e.message))` →
    `callback(null, AiUsage(error = e.message))`

#### File: `android/app/src/main/kotlin/com/example/auto_reply_assistant/service/AppNotificationListenerService.kt`

**Function: `sendBatchedAiReply()` — guard against null reply in `onBatchResult`**

11. **The `else` branch of `if (aiReply != null && aiReply.isNotBlank())`** currently only logs
    `"Batched AI returned empty reply"`. After the fix to `getAiReplyBatch()`, a failed inference
    will arrive here as `aiReply == null`. The existing condition already catches `null`, so the
    only change needed is to **improve the log message** to include `sender`, `modelType`, and the
    `error` field from `AiUsage`:
    ```kotlin
    } else {
        Log.w(TAG, "AI inference failed for sender=$sender model=$modelType error=$error — not sending reply")
    }
    ```
    No send path is entered; the `ConversationHistory.addMessage` calls inside the `if` block are
    already skipped. This satisfies Requirement 2.5 with no additional structural change.

---

## Testing Strategy

### Validation Approach

Testing follows two phases: first run exploratory tests against the **unfixed** code to surface
counterexamples and confirm the root-cause hypothesis; then, after applying the fix, run fix-checking
and preservation tests to verify correctness.

### Exploratory Bug Condition Checking

**Goal:** Surface counterexamples that demonstrate the three bugs on unfixed code. Confirm or
refute the root-cause analysis before committing to the implementation.

**Test Plan:** Write unit tests that call `buildPrompt()` directly and `getAiReplyBatch()` with a
mock `Llama.complete()` that simulates timeout and empty-output scenarios. Run against the unfixed
code; expect the tests to fail, revealing the wrong template and the non-null fallback returns.

**Test Cases:**

1. **Gemma template test** — call `buildPrompt("You are helpful.", emptyList(), "Hi")` and assert
   the result contains `<start_of_turn>`. Will fail (contains `"System:"` instead).
2. **Qwen3 template test** — call `buildPrompt(…)` and assert the result contains `<|im_start|>`.
   Will fail.
3. **Llama 3 template test** — assert result contains `<|begin_of_text|>`. Will fail.
4. **Timeout fallback test** — mock `Llama.complete()` to return `null` (simulating timeout);
   assert `callback` receives `reply == null`. Will fail (receives `"Thanks for your message!"`).
5. **Empty-output fallback test** — mock `Llama.complete()` to return a result with blank text;
   assert `callback` receives `reply == null`. Will fail (receives a fallback string).

**Expected Counterexamples:**
- `buildPrompt` always returns a string starting with `"System: "` regardless of `modelId`.
- `getAiReplyBatch` callback always receives a non-null, non-blank string even on failure.
- `sendBatchedAiReply` sends the fallback to the recipient.

### Fix Checking

**Goal:** Verify that for all inputs where the bug condition holds, the fixed functions produce
correct behaviour.

**Pseudocode:**
```
FOR ALL X WHERE isBugCondition(X) DO

  // Bug 1: correct template
  prompt ← buildChatPrompt'(X.modelId, X.systemPrompt, X.history, X.message)
  IF modelFamily(X.modelId) == "gemma"  THEN ASSERT prompt CONTAINS "<start_of_turn>"
  IF modelFamily(X.modelId) == "llama3" THEN ASSERT prompt CONTAINS "<|begin_of_text|>"
  IF modelFamily(X.modelId) == "chatml" THEN ASSERT prompt CONTAINS "<|im_start|>"

  // Bug 2: null on failure
  (reply, usage) ← getAiReplyBatch'(X) [with simulated timeout / empty output]
  ASSERT reply == null AND usage.error != null

  // Bug 3: nothing sent
  sendBatchedAiReply'(batch where aiReply=null)
  ASSERT NO call to sendReply()
  ASSERT NO call to ConversationHistory.addMessage()

END FOR
```

### Preservation Checking

**Goal:** Verify that for all inputs where the bug condition does NOT hold, the fixed code produces
identical behaviour to the original.

**Pseudocode:**
```
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT F(X) = F'(X)
END FOR
```

**Testing Approach:** Property-based testing is effective here because the space of `modelType`
values and message contents is large. Generating random non-local messages and verifying the
`smart_reply` and rule-based paths are unchanged catches accidental regressions in the dispatch
logic.

**Test Cases:**

1. **Smart reply preservation** — call `sendBatchedAiReply` with `modelType="smart_reply"`;
   assert `SmartReplyService.getAiReplyBatch` is still invoked and the result flows through
   normally.
2. **Rule-based preservation** — inject a matching rule and assert `getAiReplyBatch` is never
   called.
3. **Busy mode preservation** — enable busy mode; assert the busy reply is sent unchanged.
4. **Model-not-downloaded preservation** — assert the `null` reply + `"Model not downloaded"`
   error still short-circuits before loading; also assert that `sendBatchedAiReply` now correctly
   skips sending (this is a combined fix + preservation check).
5. **Conversation history preservation** — assert that prior turns appear in the new chat template
   prompt in the correct order with correct role delimiters.

### Unit Tests

- `buildChatPrompt()` for each of the three model families with and without system prompt and
  conversation history — assert correct delimiter placement, no stray `"System:"` / `"User:"` labels.
- `getAiReplyBatch()` failure branches (timeout, empty, load failure, model not downloaded) —
  assert `reply == null` and `usage.error` is non-null and descriptive in each case.
- `getAiReplyBatch()` success branch — assert reply is non-null, non-blank, and passes through
  `postProcess()`.
- `sendBatchedAiReply()` with `aiReply == null` — assert `sendReply()` is not called and
  `ConversationHistory.addMessage()` is not called.
- `sendBatchedAiReply()` with a valid `aiReply` — assert `sendReply()` **is** called (no regression).

### Property-Based Tests

- Generate random `(modelId, systemPrompt, messages)` tuples where `modelId` is one of the four
  local IDs; assert the produced prompt always contains the correct family delimiter and never
  contains the legacy `"System: "` / `"Assistant:"` labels.
- Generate random non-local `modelType` values and messages; assert the `onBatchResult` flow is
  identical before and after the fix (preservation).
- Generate random error strings; assert that every failure branch in `getAiReplyBatch()` returns
  `(null, AiUsage(error = <that string>))` and never a member of `fallbackReplies`.

### Integration Tests

- Full end-to-end flow: trigger a notification with a local model selected, assert a reply is
  eventually sent and it is not a member of `fallbackReplies`.
- Timeout simulation: mock inference to delay beyond 60 s; assert no message is sent and the
  Flutter UI receives an `onAiUsageUpdate` event with a non-empty `error` field.
- Multi-model smoke test: cycle through all four `modelId` values with a fixed system prompt,
  assert each produced prompt uses the correct template family.
