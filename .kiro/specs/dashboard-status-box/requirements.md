# Requirements Document

## Introduction

This feature adds a real-time status box to the Auto Replier dashboard screen. The status box displays the live pipeline state for each incoming message as it moves through the native Android processing pipeline — from notification arrival through AI/rule processing to reply dispatch. All state transitions are driven by actual events emitted by the native Kotlin pipeline (`AppNotificationListenerService`, `GemmaLocalService`, `RuleEngine`) and delivered to the Flutter UI via the existing `MethodChannel` (`com.example.auto_reply_assistant/notification`). No mock or hardcoded data is used at any stage.

## Glossary

- **Status_Box**: The UI widget on `DashboardScreen` that displays the live pipeline status for the most recently active message.
- **Pipeline**: The end-to-end native Android processing sequence: notification received → rule/AI analysis → reply generated → reply countdown → reply sent.
- **Pipeline_State**: One of four named states the Status_Box can display: `GotMessage`, `Analysing`, `ReplyReady`, `Sending`.
- **Status_Provider**: The Riverpod `StateNotifierProvider` (`pipelineStatusProvider`) that holds the current `PipelineStatusData` and drives the Status_Box widget.
- **Auto_Reply_Service**: The existing Flutter service (`AutoReplyService`) that handles all `MethodChannel` callbacks from the native side.
- **Notification_Channel**: The existing `MethodChannel` named `com.example.auto_reply_assistant/notification` used for native → Flutter event delivery.
- **Native_Pipeline**: The Kotlin components `AppNotificationListenerService`, `GemmaLocalService`, and `RuleEngine` that run on the Android side.
- **Sender**: The display name of the contact whose message triggered a pipeline run (e.g., "Alice").
- **Countdown_Seconds**: The integer number of seconds remaining before the scheduled reply is sent, derived from the `delayMs` field of the `onReplyScheduled` event.
- **Dashboard_Screen**: The main Flutter screen at `lib/screens/dashboard_screen.dart`.
- **MethodChannel_Event**: A named method invocation sent from the Native_Pipeline to the Flutter engine over the Notification_Channel.
- **Idle_State**: The Status_Provider state where `pipelineState` is `null`, `sender` is `null`, and `countdownSeconds` is `null`. The Status_Box is hidden in this state.

---

## Requirements

### Requirement 1: Pipeline State Model

**User Story:** As a developer, I want a well-defined state model for the pipeline status, so that the UI and the provider layer share a single, unambiguous representation of what the pipeline is doing.

#### Acceptance Criteria

1. THE Status_Provider SHALL represent the pipeline as exactly one of the following four named states at any given time: `GotMessage`, `Analysing`, `ReplyReady`, and `Sending`.
2. WHEN the pipeline state is `Analysing`, `ReplyReady`, or `Sending`, THE Status_Provider SHALL include the Sender name (a non-null, non-empty string) so the Status_Box can display which contact's message is being processed.
3. WHEN the pipeline state is `GotMessage` and the Sender name has not yet been parsed from the notification, THE Status_Provider SHALL permit the Sender name to be absent or empty string.
4. WHEN the pipeline state is `Sending`, THE Status_Provider SHALL include the `Countdown_Seconds` value as a non-negative integer so the Status_Box can display a live countdown.
5. WHEN the pipeline state is `GotMessage`, `Analysing`, or `ReplyReady`, THE Status_Provider SHALL set `Countdown_Seconds` to `null` in the state data, to avoid UI confusion.
6. THE Status_Provider SHALL expose an Idle_State (pipelineState = null, sender = null, countdownSeconds = null) that causes the Status_Box to be removed from the widget tree.
7. THE Status_Provider SHALL be implemented as a Riverpod `StateNotifierProvider<PipelineStatusNotifier, PipelineStatusData>` in `lib/providers/pipeline_status_provider.dart`, consistent with the existing provider patterns in `lib/providers/`.

---

### Requirement 2: Native-to-Flutter Event Mapping

**User Story:** As a developer, I want every pipeline stage to emit a MethodChannel event to Flutter, so that the Status_Provider can transition through all four states using real data.

#### Acceptance Criteria

1. WHEN `AppNotificationListenerService` receives a notification that passes all pre-processing guards (package filter, cooldown, master switch, schedule window), THE Native_Pipeline SHALL invoke `methodChannel?.invokeMethod("onPipelineStatus", mapOf("state" to "got_message", "sender" to senderName))` on the Android main thread before any rule matching or AI batching begins.
2. WHEN `AppNotificationListenerService` reaches the decision point where it begins rule matching (calling `RuleEngine.findMatchingRule()`) or initiates AI batch inference (submitting to `MessageBatcher`), THE Native_Pipeline SHALL invoke `methodChannel?.invokeMethod("onPipelineStatus", mapOf("state" to "analysing", "sender" to senderName))` on the Android main thread at that decision point, not after the 5-second batch window expires.
3. WHEN a reply text has been determined — either a rule match is found by `RuleEngine` or `GemmaLocalService`/`SmartReplyService` returns a non-null reply — but before `sendReply()` or `scheduleReply()` is called, THE Native_Pipeline SHALL invoke `methodChannel?.invokeMethod("onPipelineStatus", mapOf("state" to "reply_ready", "sender" to senderName))` on the Android main thread. In the confirm-before-reply path this event SHALL be emitted before the confirmation notification is shown.
4. WHEN `AppNotificationListenerService` schedules a reply with a delay, THE Native_Pipeline SHALL invoke `methodChannel?.invokeMethod("onReplyScheduled", mapOf("sender" to sender: String, "replyText" to replyText: String, "delayMs" to delayMs: Long, "scheduledAt" to System.currentTimeMillis(): Long))` on the Android main thread.
5. THE Native_Pipeline SHALL emit all `onPipelineStatus` and `onReplyScheduled` events using `mainHandler.post { methodChannel?.invokeMethod(...) }` consistent with the existing event emission pattern in `AppNotificationListenerService`.
6. IF the `methodChannel` reference is null when any `onPipelineStatus` or `onReplyScheduled` event is to be emitted (Flutter engine not running), THEN THE Native_Pipeline SHALL skip only the `invokeMethod` call without throwing an exception, while continuing all other processing (rule matching, AI inference, reply dispatch, logging) unchanged.

---

### Requirement 3: Flutter Provider State Transitions

**User Story:** As a user, I want the status box to update in real time as my message is processed, so that I can see each stage of the pipeline without any manual refresh.

#### Acceptance Criteria

1. WHEN `AutoReplyService` receives an `onPipelineStatus` callback with `state = "got_message"`, THE Status_Provider SHALL transition to the `GotMessage` state with `pipelineState = PipelineState.gotMessage` and `sender` set to the provided sender string (may be empty).
2. WHEN `AutoReplyService` receives an `onPipelineStatus` callback with `state = "analysing"`, THE Status_Provider SHALL transition to the `Analysing` state with `pipelineState = PipelineState.analysing` and `sender` set to the provided non-empty sender string.
3. WHEN `AutoReplyService` receives an `onPipelineStatus` callback with `state = "reply_ready"`, THE Status_Provider SHALL transition to the `ReplyReady` state with `pipelineState = PipelineState.replyReady` and `sender` set to the provided non-empty sender string.
4. WHEN `AutoReplyService` receives an `onReplyScheduled` callback, THE Status_Provider SHALL transition to the `Sending` state with `pipelineState = PipelineState.sending`, `sender` set to the provided sender string, `countdownSeconds` initialised to `(delayMs / 1000).ceil()`, and a `Timer.periodic` started to decrement `countdownSeconds` once per second.
5. WHEN `AutoReplyService` receives an `onReplySuccess` or `onReplyFailed` callback, THE Status_Provider SHALL transition to Idle_State (`pipelineState = null`, `sender = null`, `countdownSeconds = null`) and cancel any active `Timer.periodic` before the next periodic tick fires.
6. WHEN the `Sending` state countdown reaches zero seconds and no terminal event (`onReplySuccess` or `onReplyFailed`) has been received, THE Status_Provider SHALL stop the `Timer.periodic`, hold `countdownSeconds` at 0, and remain in `Sending` state until the terminal event arrives.
7. WHEN a new `onPipelineStatus` or `onReplyScheduled` event is received while the Status_Provider is already in a non-idle state, THE Status_Provider SHALL immediately supersede the current state with the new state derived from the incoming event, cancelling any active `Timer.periodic` before the next tick fires, regardless of whether the events relate to the same or different senders.

---

### Requirement 4: Dashboard Status Box Widget

**User Story:** As a user, I want to see a clearly visible status box on the dashboard, so that I can monitor what the auto-replier is doing at a glance.

#### Acceptance Criteria

1. THE Dashboard_Screen SHALL render the Status_Box as a `Card` widget positioned below the master switch and above the Statistics section.
2. WHEN the Status_Provider is in Idle_State, THE Status_Box SHALL be removed from the widget tree (using a conditional render or `Visibility` with `maintainState: false`).
3. IF the Status_Box widget is rendered while the Status_Provider is in Idle_State, THE Dashboard_Screen SHALL force-hide it by wrapping it in a `Visibility(visible: false)` widget.
4. WHEN the Status_Provider is in `GotMessage` state, THE Status_Box SHALL display the label "Got new message" and the Sender name if non-empty, or "Unknown" if the sender is empty.
5. WHEN the Status_Provider is in `Analysing` state, THE Status_Box SHALL display the label "Analysing" with a `CircularProgressIndicator` (or equivalent animated loading widget) and the Sender name.
6. WHEN the Status_Provider is in `ReplyReady` state, THE Status_Box SHALL display the label "Reply ready" and the Sender name.
7. WHEN the Status_Provider is in `Sending` state, THE Status_Box SHALL display the label "Sending in XX seconds" where XX is the current `Countdown_Seconds` value (including 0), and the Sender name.
8. THE Status_Box SHALL use the following per-state icon and accent color: `GotMessage` — inbox icon, blue; `Analysing` — hourglass icon, amber; `ReplyReady` — check-circle icon, green; `Sending` — send icon, purple.
9. WHEN the Status_Provider state changes, THE Status_Box SHALL reflect the new state within 1 second without any user interaction or page refresh, by rebuilding via Riverpod's `ConsumerWidget` or `Consumer` widget.

---

### Requirement 5: Countdown Accuracy

**User Story:** As a user, I want the countdown timer in the status box to accurately reflect the actual seconds remaining before the reply is sent, so that the displayed number matches the real delay.

#### Acceptance Criteria

1. WHEN the Status_Provider enters `Sending` state, THE Status_Provider SHALL initialise `Countdown_Seconds` to `(delayMs / 1000).ceil()` where `delayMs` is the integer millisecond delay from the `onReplyScheduled` event payload.
2. WHILE the Status_Provider is in `Sending` state and `Countdown_Seconds` is greater than 0, THE Status_Provider SHALL decrement `Countdown_Seconds` by 1 every 1000 milliseconds using a single `dart:async` `Timer.periodic(Duration(seconds: 1), ...)`.
3. WHEN `Countdown_Seconds` reaches 0, THE Status_Provider SHALL cancel the `Timer.periodic` and hold `countdownSeconds` at 0 in the state until a terminal event (`onReplySuccess` or `onReplyFailed`) is received.
4. WHEN the Status_Provider transitions out of `Sending` state due to a terminal event, THE Status_Provider SHALL call `timer.cancel()` before the next periodic tick fires, ensuring no further state updates are emitted after the transition to Idle_State.
5. IF a new `onReplyScheduled` event arrives while a `Timer.periodic` countdown is already active, THEN THE Status_Provider SHALL cancel the existing timer before starting a new `Timer.periodic` with `Countdown_Seconds` initialised from the new `delayMs` value.
6. IF the `delayMs` value in the `onReplyScheduled` event is 0 or negative, THEN THE Status_Provider SHALL initialise `Countdown_Seconds` to 0 and NOT start a `Timer.periodic`, remaining in `Sending` state at 0 seconds until the terminal event arrives.

---

### Requirement 6: Data Source Integrity

**User Story:** As a developer, I want a guarantee that all status data originates from real pipeline events, so that users are never shown fabricated or stale information.

#### Acceptance Criteria

1. THE Status_Box SHALL source every displayed value (state label, sender name, countdown) exclusively from the `PipelineStatusData` object held by the Status_Provider, which is populated only from events received over the Notification_Channel.
2. THE Status_Provider SHALL initialise to Idle_State on construction, with no hardcoded sender name, countdown value, or pipeline state set at initialisation time.
3. THE Status_Provider SHALL not call `Timer` or `Future.delayed` for any purpose other than the `Timer.periodic` countdown in `Sending` state that is driven by a real `onReplyScheduled` event.
4. WHEN the app is launched and no `onPipelineStatus` or `onReplyScheduled` event has been received in the current session, THE Status_Box SHALL remain hidden (Status_Provider in Idle_State).
5. IF the Status_Provider is in `Sending` state with `Countdown_Seconds` equal to 0 and no terminal event (`onReplySuccess` or `onReplyFailed`) has been received for 30 seconds after `Countdown_Seconds` reached 0, THEN THE Status_Provider SHALL transition to Idle_State and hide the Status_Box, to prevent indefinitely stale display.
