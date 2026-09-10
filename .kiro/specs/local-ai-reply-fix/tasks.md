# Implementation Plan

## Overview

Fix three related bugs in local AI inference: replace the model-agnostic `buildPrompt()` with a
model-family-aware `buildChatPrompt()` supporting Gemma, Llama 3, and ChatML/Qwen3 templates;
replace all `fallbackReplies.random()` failure returns in `getAiReplyBatch()` with
`callback(null, AiUsage(error=…))`; and improve the failure log in `sendBatchedAiReply()`.
The workflow follows explore → preserve → implement → validate order.

## Tasks

- [ ] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Wrong Chat Template & Fallback-on-Failure
  - **CRITICAL**: This test MUST FAIL on unfixed code — failure confirms the bugs exist
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior — it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate all three bugs on the unfixed code
  - **Scoped PBT Approach**: Scope properties to each of the four concrete model IDs for deterministic reproducibility
  - Create `GemmaLocalServiceTest.kt` (or equivalent JUnit test class) under `android/app/src/test/...`
  - **Sub-test A — Gemma template**: call `buildPrompt("You are helpful.", emptyList(), "Hi")` on the private method (expose via reflection or test-friendly wrapper) and assert the result contains `<start_of_turn>` — WILL FAIL (contains `"System:"` instead)
  - **Sub-test B — Qwen3 template**: same call, assert result contains `<|im_start|>` — WILL FAIL
  - **Sub-test C — Llama 3 template**: same call, assert result contains `<|begin_of_text|>` — WILL FAIL
  - **Sub-test D — Timeout fallback**: mock `Llama.complete()` to return `null`; invoke `getAiReplyBatch()` with `modelId="gemma_270m"` and assert `callback` receives `reply == null` — WILL FAIL (receives `"Thanks for your message!"`)
  - **Sub-test E — Empty-output fallback**: mock `Llama.complete()` to return a result whose `text` field is blank; assert `callback` receives `reply == null` — WILL FAIL (receives a fallback string)
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: All sub-tests FAIL — this proves the bugs exist
  - Document counterexamples found (e.g., `buildPrompt(...)` starts with `"System: "`, `getAiReplyBatch()` callback receives non-null fallback on timeout)
  - Mark task complete when tests are written, run, and failures are documented
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_

- [ ] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Non-Local-AI Paths Are Unaffected
  - **IMPORTANT**: Follow observation-first methodology
  - **Observe on UNFIXED code** (cases where `isBugCondition` is false):
    - `sendBatchedAiReply` with `modelType="smart_reply"` routes to `SmartReplyService.getAiReplyBatch()` — observe it is still called
    - A matched rule short-circuits before `GemmaLocalService` is touched — observe no AI call is made
    - Busy mode active — observe busy reply text is sent without calling any AI service
    - `postProcess()` strips `<end_of_turn>`, `<bos>`, `<eos>` tokens and truncates to 500 chars — observe the clean output
    - `getAiReplyBatch()` with `isModelAvailable()==false` returns `null` reply + `"Model not downloaded"` error (already non-null reply pre-fix; after fix null is the _same_ signal — test the error field)
  - Write property-based tests: for all `modelType` values ∉ `{"gemma_local"}`, the `onBatchResult` dispatch path is identical before and after the fix
  - Write unit test: `postProcess()` output is unchanged for any input string
  - Write unit test: conversation history turns appear in correct order in the produced prompt (test via the existing `buildPrompt` before the fix to capture current ordering, then reuse after fix to catch regressions)
  - Verify all preservation tests PASS on UNFIXED code before proceeding
  - **EXPECTED OUTCOME**: Tests PASS (confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [ ] 3. Fix: model-aware chat templates, null-on-failure, and improved failure log

  - [ ] 3.1 Add `modelFamily()` helper and `buildChatPrompt()` in GemmaLocalService.kt
    - Add private `modelFamily(modelId: String): String` that maps `{"gemma_270m","gemma_1b"}` → `"gemma"`, `"bharat_tiny"` → `"llama3"`, `"qwen3_0.6b"` → `"chatml"`, default `"chatml"`
    - Add private `buildGemmaPrompt(systemPrompt, history, incomingMessage)`: embed system text inside first `<start_of_turn>user` block; wrap history pairs in `<start_of_turn>user…<end_of_turn>\n<start_of_turn>model…<end_of_turn>\n`; append final `<start_of_turn>model\n`
    - Add private `buildLlama3Prompt(systemPrompt, history, incomingMessage)`: open with `<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n{systemPrompt}<|eot_id|>`; history pairs with `<|start_header_id|>user<|end_header_id|>` / `<|start_header_id|>assistant<|end_header_id|>` blocks; close with `…user…<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n`
    - Add private `buildChatMlPrompt(systemPrompt, history, incomingMessage)`: `<|im_start|>system\n{systemPrompt}<|im_end|>\n`; history with `<|im_start|>user…<|im_end|>\n<|im_start|>assistant…<|im_end|>\n`; close with `<|im_start|>user\n{incomingMessage}<|im_end|>\n<|im_start|>assistant\n`
    - Add `buildChatPrompt(modelId, systemPrompt, history, incomingMessage)` dispatcher that calls the correct family builder via `modelFamily(modelId)`
    - The old `buildPrompt()` can remain as private (it will be unreachable once the call site is updated) or be removed — keep it only if deletion would break tests referencing it
    - _Bug_Condition: `isBugCondition(X)` where `X.modelId IN {"gemma_270m","gemma_1b","bharat_tiny","qwen3_0.6b"}`_
    - _Expected_Behavior: `buildChatPrompt(modelId,…)` returns a prompt containing the correct family delimiter and never containing legacy `"System:"` / `"Assistant:"` labels_
    - _Preservation: conversation history turns must appear in the new template in the same relative order_
    - _Requirements: 2.1, 2.2, 3.5_

  - [ ] 3.2 Update getAiReplyBatch() call site to use buildChatPrompt()
    - Replace `val prompt = buildPrompt(systemPrompt, conversationHistory, combinedMessage)` with `val prompt = buildChatPrompt(modelId, systemPrompt, conversationHistory, combinedMessage)`
    - No other changes to the method signature or surrounding logic
    - _Requirements: 2.1_

  - [ ] 3.3 Replace all fallbackReplies.random() failure returns with callback(null, …) in getAiReplyBatch()
    - **Model not downloaded branch**: `callback(fallbackReplies.random(), AiUsage(error = "Model not downloaded"))` → `callback(null, AiUsage(error = "Model not downloaded"))`
    - **Load failure branch**: `callback(fallbackReplies.random(), AiUsage(error = "Failed to load model"))` → `callback(null, AiUsage(error = "Failed to load model"))`
    - **Timeout branch**: `callback(fallbackReplies.random(), AiUsage(error = "Inference timed out"))` → `callback(null, AiUsage(error = "Inference timed out"))`; also add `Log.e(TAG, "Inference timed out for $modelId (prompt length: ${prompt.length})")`
    - **Empty-output branch**: `callback(fallbackReplies.random(), AiUsage(error = "Empty response"))` → `callback(null, AiUsage(error = "Empty response"))`; also add `Log.e(TAG, "Empty response from $modelId (prompt length: ${prompt.length})")`
    - **Exception branch**: `callback(fallbackReplies.random(), AiUsage(error = e.message))` → `callback(null, AiUsage(error = e.message))`
    - _Bug_Condition: `isBugCondition(X)` AND `(timeout OR empty_output OR load_failure OR exception)`_
    - _Expected_Behavior: `reply == null AND usage.error != null AND usage.error != ""`_
    - _Preservation: success branch is unchanged — non-null, non-blank reply still flows through `postProcess()`_
    - _Requirements: 2.3, 2.4, 3.3_

  - [ ] 3.4 Improve failure log in sendBatchedAiReply() onBatchResult in AppNotificationListenerService.kt
    - Locate the `else` branch of `if (aiReply != null && aiReply.isNotBlank())` inside `onBatchResult`
    - Replace `Log.w(TAG, "Batched AI returned empty reply for sender=$sender")` with `Log.w(TAG, "AI inference failed for sender=$sender model=$modelType error=$error — not sending reply")`
    - No structural change to the send path — `sendReply()` and `ConversationHistory.addMessage()` are already inside the `if` block and are automatically skipped
    - _Bug_Condition: `aiReply == null` (after fix, failure returns null instead of fallback)_
    - _Expected_Behavior: failure is logged with sender, modelType, and error; no message is sent_
    - _Preservation: `confirmBeforeReply` path and valid-reply send path are unchanged_
    - _Requirements: 2.5_

  - [ ] 3.5 Verify bug condition exploration test now passes (Property 1: Expected Behavior)
    - **Property 1: Expected Behavior** - Correct Templates & Null-on-Failure
    - **IMPORTANT**: Re-run the SAME tests from task 1 — do NOT write new tests
    - The tests from task 1 encode the expected behavior; passing them confirms the fix is correct
    - Re-run Sub-tests A/B/C: assert `buildChatPrompt(modelId, …)` returns correct family delimiter for each of `gemma_270m`, `qwen3_0.6b`, `bharat_tiny`
    - Re-run Sub-tests D/E: assert `getAiReplyBatch()` callback receives `reply == null` on timeout and empty-output
    - **EXPECTED OUTCOME**: All sub-tests PASS (confirms bugs are fixed)
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

  - [ ] 3.6 Verify preservation tests still pass (Property 2: Preservation)
    - **Property 2: Preservation** - Non-Local-AI Paths Are Unaffected
    - **IMPORTANT**: Re-run the SAME tests from task 2 — do NOT write new tests
    - Run all preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions in smart_reply, rule-based, busy-mode, postProcess, and conversation-history paths)
    - Confirm every preservation test still passes after the fix

- [ ] 4. Checkpoint — Ensure all tests pass
  - Run the full test suite: `./gradlew :app:testDebugUnitTest` (or equivalent)
  - All Property 1 sub-tests (A–E) must PASS
  - All Property 2 preservation tests must PASS
  - No new test failures introduced
  - Ask the user if any questions arise before marking complete

## Task Dependency Graph

```json
{
  "waves": [
    { "wave": 1, "tasks": ["1", "2"] },
    { "wave": 2, "tasks": ["3.1"] },
    { "wave": 3, "tasks": ["3.2"] },
    { "wave": 4, "tasks": ["3.3"] },
    { "wave": 5, "tasks": ["3.4"] },
    { "wave": 6, "tasks": ["3.5", "3.6"] },
    { "wave": 7, "tasks": ["4"] }
  ]
}
```

- Task 1 must be written and run (to failure) before task 3 begins
- Task 2 must be written and verified passing before task 3 begins
- Tasks 3.1 → 3.2 → 3.3 → 3.4 are sequential (each builds on the previous file edit)
- Tasks 3.5 and 3.6 require all of task 3.1–3.4 to be complete
- Task 4 requires 3.5 and 3.6

## Notes

- All source changes are confined to two files: `GemmaLocalService.kt` and `AppNotificationListenerService.kt`
- The `fallbackReplies` list itself is not removed — it may still be useful for the Flutter UI test screen path
- The old `buildPrompt()` private method can be deleted once `buildChatPrompt()` replaces its only call site
- Property-based tests for `buildChatPrompt()` should generate random `(systemPrompt, history, incomingMessage)` tuples for each model family and assert: correct delimiter present, no legacy `"System:"` / `"Assistant:"` labels present
- Property-based tests for preservation should generate random non-`"gemma_local"` modelType values and assert the `onBatchResult` dispatch is unchanged
- Run tests via `./gradlew :app:testDebugUnitTest` from the `android/` directory
