# 10 · AI Assistant (Claude)

Both apps include an **Assistant** side panel powered by Claude. All model calls happen on the
**server** (API key never reaches clients). The assistant acts on documents through the **same
tool layer as MCP** ([09-mcp.md](09-mcp.md)), so anything it does is permission-checked,
attributed (`actorKind: ai`) and undoable as one step.

## 1. Model and API usage

- Dart has no official Anthropic SDK → the server calls the **Messages API over HTTPS**
  (`POST https://api.anthropic.com/v1/messages`) with the `http` package, wrapped in an
  `AnthropicClient` class in `wonky_server/lib/src/platform/ai/anthropic_client.dart`.
- Headers: `x-api-key` (from `config/passwords.yaml` → `anthropicApiKey`),
  `anthropic-version: 2023-06-01`, `content-type: application/json`, and
  `anthropic-beta: server-side-fallback-2026-07-01` (for refusal fallbacks, below).
- **Default model: `claude-opus-5-5`.** User setting "AI quality" maps to:
  | Setting | Model | Effort |
  |---------|-------|--------|
  | Best (default) | `claude-opus-5-5` | `high` |
  | Balanced | `claude-opus-5-5` | `medium` |
  | Fast | `claude-haiku-5-5` | `low` |
  Inline completions (autocomplete-style suggestions, formula suggestions) use
  `claude-haiku-5-5`. Model ids live in one constants file; never hard-code elsewhere.
- **Thinking**: `thinking: {type: "adaptive"}` (do not send `budget_tokens` — rejected on these
  models). Effort is set via `output_config: {effort: …}`. Do not set `temperature`/`top_p`.
- **Streaming** (`"stream": true`, SSE) for every assistant request; `max_tokens: 64000`. The
  server parses SSE events and relays text deltas and tool activity to the client over a
  Serverpod stream.
- **Tool use**: tools are generated from the MCP tool registry (same JSON schemas). Use
  `tool_choice: {type: "auto"}` only (forced tool choice returns 400 on these models). Mark
  tools `strict: true` where schemas allow it. Set `eager_input_streaming: true` on tools; the
  server validates the parsed input against the schema before executing, and returns an
  `is_error: true` tool_result on invalid input. Execute parallel tool calls concurrently and
  return all `tool_result` blocks in one user message.
- **Stop reasons**: always check `stop_reason` before reading content. Handle `refusal`
  (show "The assistant can't help with that request."), `max_tokens` (offer "Continue"),
  `pause_turn`, `tool_use` (loop).
- **Refusal fallbacks**: send `fallbacks: "default"` with the beta header above.
- **Prompt caching**: stable prefix order = tools (sorted, deterministic) → system prompt (frozen,
  no timestamps) → document context → conversation. Put `cache_control: {type: "ephemeral"}` on
  the system prompt and after the document snapshot. Volatile data (current selection, time)
  goes at the end of the latest user turn. Log `usage.cache_read_input_tokens` to verify.
- **History**: assistant transcripts are append-only (never edit earlier turns; thinking blocks
  are passed back unchanged). New context (e.g. the document changed) is appended as a new user
  turn element, not by rewriting history.
- **Limits & cost control**: per-user daily token budget (config), per-request timeout 10 min,
  concurrency 2 requests per user. Usage stored in `AiUsage` table (userId, model, input/output/
  cache tokens, at).
- **Privacy**: AI is opt-out per user (Settings → AI) and can be disabled server-wide
  (`config: ai.enabled`). The panel shows a notice that document content is sent to Anthropic.

## 2. Server components (`wonky_server/lib/src/platform/ai/`)

| File | Responsibility |
|------|----------------|
| `anthropic_client.dart` | HTTP + SSE parsing, retries (429/5xx/connection with exponential backoff, honor `retry-after`), typed request/response models. |
| `assistant_service.dart` | Agent loop: build request, stream, execute tools via `ToolExecutor`, loop until `end_turn`. One loop = one undo transaction for the user ("AI: …"). |
| `context_builder.dart` | Builds document context: Write → Markdown of doc (or outline + selected sections if > 200k tokens); Sheets → sheet list, used ranges, headers, sample rows, selection values, named ranges. |
| `prompts/` | System prompts per app/mode, versioned constants. |
| `assistant_endpoint.dart` | Endpoint `assistant`: `chat(threadId, message, contextHints)` → `Stream<AssistantEvent>`; `listThreads(itemUuid)`, `getThread`, `deleteThread`, `stop(threadId)`. |

Models:

```yaml
class: AssistantThread
table: assistant_thread
fields:
  userId: int, relation(parent=user_profile, onDelete=Cascade)
  itemId: int?, relation(parent=drive_item, onDelete=Cascade)
  title: String
  createdAt: DateTime
  updatedAt: DateTime

class: AssistantMessage
table: assistant_message
fields:
  threadId: int, relation(parent=assistant_thread, onDelete=Cascade)
  role: String                 # user | assistant
  contentJson: String          # raw API content blocks (kept verbatim for replay)
  displayText: String          # rendered text for the UI
  toolCallsJson: String?       # summarized tool calls for the UI
  createdAt: DateTime

class: AssistantEvent           # not a table — streamed to client
fields:
  type: AssistantEventType      # textDelta, toolStarted, toolFinished, error, done, usage
  text: String?
  toolName: String?
  toolSummary: String?
  error: String?
```

## 3. UI — Assistant panel (`wonky_app` `AssistantPanel`, specialized per app)

- Toggle: toolbar ✨ button, *Tools › Assistant*, `Mod+J` (contextual binding: in Write, inside an
  empty paragraph `Mod+J` opens the inline AI prompt instead — see suite 08 §1.2). Right side panel (resizable,
  360–640 px), shares the right-panel slot with Comments/History/Outline (tabbed).
- Header: thread picker (dropdown of threads for this file + "New chat"), ⋮ (Clear, Delete thread,
  Settings).
- Message list: user bubbles, assistant Markdown rendering (code blocks with copy), **tool
  activity chips** ("Edited 3 paragraphs", "Wrote 120 cells to Sheet1!A1:D30") with *Show* (jumps
  to and highlights the change) and *Undo* buttons.
- Composer: multiline input (Enter send, Shift+Enter newline), context chips ("Selection: 2
  paragraphs", "Sheet1!B2:F40") that can be removed, *Stop* button while streaming, quick
  prompts row.
- **Apply mode** toggle: *Edit directly* (tools mutate the doc) vs *Suggest* (Write: changes
  arrive as suggestions in suggestion mode; Sheets: changes are previewed in a diff dialog with
  Accept/Reject).

## 4. Inline AI entry points

### Write
- Selection floating toolbar → ✨ menu: *Improve writing*, *Fix spelling & grammar*, *Make
  shorter*, *Make longer*, *Change tone ▸ (Professional, Casual, Friendly, Confident)*,
  *Summarize*, *Translate ▸*, *Explain*, *Continue writing*, *Custom…*.
- Empty paragraph: type `/ai` (slash menu) or `Mod+J` → inline prompt box under the caret;
  result streams into a preview block with *Insert*, *Replace*, *Try again*, *Discard*.
- *Tools › Summarize document*, *Generate outline*, *Proofread document* (opens results list in
  the panel with per-issue Accept).

### Sheets
- Formula bar ✨ button: "Describe the formula you need" → suggested formula with explanation,
  *Insert*.
- *Explain formula* in cell context menu.
- *Data › Analyze with AI*: opens panel with prompt suggestions ("Summarize this table",
  "Find anomalies", "Create a pivot table of revenue by region", "Make a chart").
- *Fill with AI*: select a column range with some examples → AI fills the rest (preview first).
- Script editor: "Generate script", "Explain script", "Fix error".

## 5. Commands

`shell.ai.togglePanel`, `shell.ai.newThread`, `shell.ai.send`, `shell.ai.stop`,
`write.ai.rewriteSelection(mode)`, `write.ai.continue`, `write.ai.summarizeDocument`,
`sheets.ai.suggestFormula`, `sheets.ai.explainFormula`, `sheets.ai.fillRange`,
`sheets.ai.analyze`.

## 6. Implementation notes (as built)

- **Server** (`wonky_server/lib/src/platform/ai/`): `anthropic/` (`AnthropicClient` +
  `HttpAnthropicClient`: `package:http`, SSE parser, `MessageAccumulator`, retries on
  408/409/429/5xx/529 and connection errors with exponential backoff + jitter honouring
  `retry-after`/`retry-after-ms`, 10 min wall clock, 3 min idle timeout; `FakeAnthropicClient`
  + `SseScript` replay scripted SSE through the same parser), `ai_models.dart` (the only
  place with model ids), `ai_config.dart`, `ai_usage_service.dart`, `assistant_tools.dart`,
  `assistant_service.dart`, `assistant_endpoint.dart`. Write parts in
  `wonky_server/lib/src/write/ai/` (`write_prompts.dart`, `write_context_builder.dart`,
  `inline_ai_service.dart`, `proofread_service.dart`).
- **Configuration**: `wonky: features: ai` + `wonky: ai:` (`enabled`, `dailyTokenBudget`,
  `maxConcurrentRequests`, `requestTimeoutMinutes`, `maxToolRounds`, `baseUrl`) in
  `config/<runMode>.yaml`; the key is `anthropicApiKey` in `config/passwords.yaml` (or
  `SERVERPOD_PASSWORD_anthropicApiKey`). Without a key `assistant.getStatus` reports
  `reason: notConfigured` and the apps show "AI isn't configured on this server".
- **Request shape**: `thinking: {type: adaptive, display: "updates" (Opus, tool requests),
  block_binding: {prefix_mismatch_behavior: "drop_block"}}`, `output_config.effort`,
  `tool_choice: auto`, `fallbacks: "default"` (not for `claude-haiku-5-5`, which has no
  server-side fallback), betas `server-side-fallback-2026-07-01`,
  `thinking-display-updates-2026-08-18`, `thinking-binding-controls-2026-08-01`. An optional
  feature the API rejects with a 400 (fallbacks, display, block binding, `strict`,
  `eager_input_streaming`, top-level `cache_control`) is switched off for the process and the
  request retried, so beta drift degrades instead of breaking the assistant.
- **Tools**: MCP names contain dots, which the API does not allow: `write.get_document` is sent
  as `write_get_document`. Schemas are the MCP schemas minus the bound keys (`document_uuid`,
  `uuid`, `mode`); strict-compatible schemas (closed objects) are sent with
  numeric/length constraints stripped (the `ToolExecutor` still validates the original) and at
  most 16 tools are marked `strict`. `comments.reply` is checked to target a thread of the open
  file. Accept/reject suggestion tools are only listed for Editors+.
- **Caching**: tools (sorted) → system (breakpoint) → the frozen document snapshot in the
  thread's first user turn (breakpoint) → conversation via the top-level automatic
  `cache_control`, so no stored message is ever edited (append-only history, also required by
  preserved thinking). "Document updated" elements carry the changed sections' Markdown.
- **Endpoint** `assistant`: `getStatus`, `setQuality`, `chat(threadId?, itemUuid, message,
  hints)`, `stop(threadId?, runId?)`, `confirm(runId, confirmationId, allow)` (destructive
  guard), `listThreads(itemUuid)`, `getThread`, `deleteThread`, `clearHistory`,
  `revertChange(changeId)` (panel Undo fallback), `inline(InlineAiRequest)`,
  `proofread(itemUuid, start?, length?)`. `AssistantEventType`: `started`, `textDelta`,
  `progress`, `toolStarted`, `toolFinished`, `confirmationRequired`, `usage`, `maxTokens`,
  `refusal`, `error`, `done`. Extra tables: `ai_user_setting` (quality); `assistant_message`
  adds `visible`, `replay`, `runId`, `stopReason`; `assistant_thread` adds the last context
  revision/Markdown.
- **Budget**: input + cache writes + output + cache reads ÷ 10 per UTC day; concurrency per user
  is in memory per server instance.
- **Client**: shared panel in `packages/wonky_app/lib/src/assistant/` (`ShellAssistant`
  implements `AssistantHook`, `AssistantController`, `AssistantPanel`, `AiSettingsSection`,
  `AssistantDocumentAdapter` for app specialization, `FakeAssistantApi` in
  `package:wonky_app/testing.dart`). Write: `wonky_write/lib/features/ai/`.
