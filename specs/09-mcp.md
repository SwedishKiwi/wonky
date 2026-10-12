# 09 · MCP — Model Context Protocol Integration

Wonky Work is **fully controllable through MCP**. There are two layers, served by **one MCP
endpoint** on the Serverpod server:

1. **Headless tools** — operate on drive items, documents and spreadsheets directly on the server
   (no app needs to be open). Namespaces: `drive.*`, `write.*`, `sheets.*`, `comments.*`,
   `versions.*`.
2. **UI bridge tools** — drive a **live app window** (web or desktop) of the same user:
   navigate, read UI state, invoke any command, operate dialogs, take screenshots. Namespace
   `ui.*`. Tool calls are relayed from the server to the chosen app session over a Serverpod
   stream.

Both layers enforce exactly the same permissions as the human UI, record `actorKind: mcp`, and
land on undo stacks as described in [08-commands-and-undo.md](08-commands-and-undo.md) §3.4.

## 1. Server hosting

- Library: **`mcp_dart`** (latest 2.x; supports MCP 2025-11-25 and 2026-07-28 protocol
  profiles, Streamable HTTP server transport, tools/resources/prompts, auth hooks).
- Endpoint: `POST/GET/DELETE https://<host>/mcp` (Streamable HTTP) on the Serverpod **web
  server** (port 8082 in development; the apps' origin in production).
- **Decision (implemented):** a custom `mcp_dart` `Transport` behind a Relic route —
  `McpRoute` → `McpHttpHandler` → `McpExchangeTransport`
  (`wonky_server/lib/src/platform/mcp/`). `mcp_dart`'s `StreamableHTTPServerTransport`
  needs a `dart:io` `HttpRequest`, which Relic does not expose, so the route parses the
  JSON-RPC body itself and delivers it to an `mcp_dart` `McpServer`; responses are matched
  back by JSON-RPC id. The protocol layer (version negotiation, `initialize`,
  `server/discover`, lists, pings) stays `mcp_dart`'s:
  - **MCP 2026-07-28 (stateless):** a POST without `Mcp-Session-Id` that is not
    `initialize` gets a fresh `McpServer` for that one request.
  - **Initialize-era (2025-11-25 and earlier):** `initialize` creates a session
    (`Mcp-Session-Id` response header, in-memory map, 60 min idle expiry, max 20 per user,
    bound to the token that created it); `DELETE` ends it; `GET` opens an event stream
    (SSE, keep-alive comments) for server notifications.
  - Responses are `application/json` (SSE only when the client does not accept JSON);
    request-related progress/log notifications are dropped; JSON-RPC batches and
    `subscriptions/listen` are refused.
  - The route runs on an internal Serverpod session (Serverpod's web-call session would
    pass the bearer header to the JWT handler).
- DNS-rebinding protection: `wonky: mcp: allowedHosts` / `allowedOrigins` in
  `config/<runMode>.yaml` (defaults: the configured public hosts + loopback, and
  Serverpod's `allowedOrigins`). Requests without `Origin` (non-browser clients) are
  allowed; browser origins must match (CORS headers only for them).
- A **stdio shim** is also provided for local clients that only support stdio:
  `dart run wonky_mcp_stdio --url https://host/mcp --token $WONKY_TOKEN` (package
  `packages/wonky_mcp_stdio`), which simply proxies stdio ↔ Streamable HTTP.

## 2. Authentication & authorization

- **Personal access tokens** (Settings → Developer/MCP), sent as `Authorization: Bearer
  wkpat_…`. Tokens have scopes:
  | Scope | Grants |
  |-------|--------|
  | `drive:read` / `drive:write` | Drive listing/search / create, rename, move, trash, share |
  | `write:read` / `write:edit` | Read documents / edit documents & comments |
  | `sheets:read` / `sheets:edit` | Read spreadsheets / edit spreadsheets |
  | `scripts:run` | Run Sheets scripts/macros |
  | `ui:control` | Use `ui.*` bridge tools |
- OAuth 2.1 (authorization code + PKCE, with Protected Resource Metadata) is a later milestone;
  `mcp_dart`'s server auth hooks are used so it can be added without changing tools.
- Every tool call resolves the token → user → effective role on the target item; the tool is
  rejected with an MCP error (`isError: true`, code `forbidden`) if insufficient.
- Rate limits: 600 tool calls/min per token (`wonky: mcp: rateLimitPerMinute`); large
  reads paginated.
- `tools/list` only lists the tools the token's scopes allow; `ToolExecutor` checks scopes
  again on every call. The web apps' auth cookie is never accepted on `/mcp`.

## 3. Package structure

| Package / folder | Content |
|------------------|---------|
| `wonky_core/lib/mcp/` | Tool **definitions** (name, description, JSON schema, result schema) shared by server, apps and the AI assistant. One file per namespace. |
| `wonky_server/lib/src/platform/mcp/` | `McpRoute`/transport, auth, `ToolExecutor` (dispatch by name), `UiBridgeHub` (session registry + relay). |
| `wonky_server/lib/src/write/mcp/`, `…/sheets/mcp/` | Headless tool **implementations** per app. |
| `wonky_app/lib/mcp_bridge/` | Client side of the UI bridge (shared `ui.*` tools). |
| `wonky_write/lib/mcp/`, `wonky_sheets/lib/mcp/` | App-specific `ui.*` extensions (e.g. `ui.write.get_selection`). |

Tool naming: `namespace.verb_noun` in snake_case (e.g. `sheets.set_values`). Names are part of
the public API — never rename; deprecate instead.

## 4. Shared headless tools

### drive.*
| Tool | Args | Result |
|------|------|--------|
| `drive.search` | `query?, kind?, folder_uuid?, owned_by_me?, shared_with_me?, starred?, modified_after?, limit, cursor` | items |
| `drive.list_folder` | `folder_uuid?` (null = root), `limit, cursor` | items |
| `drive.get_item` | `uuid` | item + role + path + sharing summary |
| `drive.create_folder` | `name, parent_uuid?` | item |
| `drive.create_document` | `name, parent_uuid?, markdown?, template_uuid?` | item |
| `drive.create_spreadsheet` | `name, parent_uuid?, template_uuid?, sheets?: [{name, values?}]` | item |
| `drive.rename` · `drive.move` · `drive.copy` · `drive.trash` · `drive.restore` · `drive.star` | … | item |
| `drive.share` | `uuid, email, role, notify?, message?` | permission |
| `drive.unshare` | `uuid, email` | ok |
| `drive.set_link_sharing` | `uuid, mode: off|viewer|commenter|editor` | link |
| `drive.export` | `uuid, format` | `{download_url, expires_at}` (signed, 15 min) — or inline text for md/txt/csv |
| `drive.import` | `name, kind, format, content_base64 \| text, parent_uuid?` | item |

### comments.*
`comments.list(uuid, status?)`, `comments.create(uuid, anchor, body)` (anchor formats per app:
Write `{quote, occurrence?}` or `{start, length}`; Sheets `{sheet, a1}`), `comments.reply`,
`comments.resolve`, `comments.reopen`, `comments.delete`.

### versions.*
`versions.list(uuid)`, `versions.name_current(uuid, name)`, `versions.get(uuid, version_id,
format)` (Write: markdown; Sheets: values JSON for a range), `versions.restore(uuid, version_id)`.

### changes.*
`changes.revert(change_id)` — reverts a previous headless tool change (24 h window).

App-specific headless tools are listed in each app's MCP spec:
[Write 09 · MCP and AI](wonky_write/09-mcp-and-ai.md),
[Sheets 12 · MCP and AI](wonky_sheets/12-mcp-and-ai.md).

## 5. Resources & prompts

- Resources: `wonky://drive/recent`, `wonky://doc/<uuid>` (Markdown, `text/markdown`),
  `wonky://sheet/<uuid>/<sheetName>` (CSV of used range, `text/csv`),
  `wonky://doc/<uuid>/outline`. Resource templates registered for each. Subscriptions emit
  `notifications/resources/updated` when content changes (debounced 2 s) — *not yet
  implemented* (§7).
- Prompts: `summarize_document`, `review_document`, `analyze_sheet`, `build_dashboard` — thin
  templates that reference resources.

## 6. UI bridge

### 6.1 Transport
```
UiBridgeEndpoint.connect(Stream<UiBridgeMessage> fromApp) → Stream<UiBridgeMessage> toApp
```
- Each running app window opens this stream after sign-in **if** the user has enabled
  "Allow MCP to control this window" (Settings → Developer; default **on** in development,
  **off** in production builds; remembered per device).
- On connect the app sends `UiBridgeHello {app, deviceLabel, platform, route,
  openItemUuid, title, focused, tools}` and gets `UiBridgeWelcome {sessionId}`; it reports
  route / open item / window focus changes with `UiBridgeStatus` (debounced 200 ms). The
  `UiBridgeHub` is **in-memory per server instance** (a client reaches the windows
  connected to the instance serving its `/mcp` requests; cross-instance relay via
  `session.messages` is a later step).
- MCP tool `ui.*` call → hub picks the target session (explicit `session_id` or the user's
  most recently focused window) → sends `UiBridgeRequest {requestId, tool, args}` → app executes
  → returns `UiBridgeResponse {requestId, result | error}`. Timeout 30 s (configurable per tool,
  e.g. 120 s for `ui.wait_for`).
- While any `ui.*` call is active, the app shows the **MCP control pill** with *Stop*.
  *Stop* fails the running calls (`stopped_by_user`) and the hub refuses new calls to that
  window for 30 s (`UiBridgeStop {pauseMs}`); a timed-out call sends `UiBridgeCancel`.
- Errors of `ui.*` calls: `no_session` (no window allows control, or none implements the
  tool), `timeout`, `stopped_by_user`, plus the app's codes (`not_found`, `invalid_args`,
  `forbidden`, `disabled`, `unsupported`, `no_document`).

### 6.2 Shared `ui.*` tools

| Tool | Description |
|------|-------------|
| `ui.list_sessions` | Live app windows of the user (id, app, route, open item, focused, last active). |
| `ui.get_state` | Route, open item, mode (edit/suggest/view), selection summary, open dialog/panel, zoom, theme, online status, undo/redo labels. |
| `ui.navigate` | `route` (e.g. `/d/<uuid>`, `/settings/appearance`) or `{open_item_uuid}`. |
| `ui.list_commands` | All commands for the current context with id, title, description, args schema, enabled, checked, shortcut, menu path. |
| `ui.invoke_command` | `command_id, args` → runs via `CommandDispatcher` (source `mcp`). |
| `ui.get_menu_tree` | Full `MenuSpec` tree with enabled/checked states. |
| `ui.undo` / `ui.redo` | Same as Edit menu. |
| `ui.get_dialog` | Describes the open dialog: title, fields (id, label, type, value, options), buttons. |
| `ui.fill_dialog` | `{field_id: value}`; `ui.press_dialog_button(button_id)`. |
| `ui.close_dialog` | Esc. |
| `ui.open_panel` / `ui.close_panel` | `panel_id` (outline, comments, history, assistant, …). |
| `ui.set_app_theme` | system/light/dark. |
| `ui.screenshot` | PNG of the window (`RepaintBoundary.toImage`), optional `region`/`scale`; returned as MCP image content. |
| `ui.get_semantics` | Accessibility tree dump (role, label, value, bounds) for generic inspection. |
| `ui.type_text` / `ui.press_keys` | Synthesized key events into the focused element (last resort; prefer commands). |
| `ui.wait_for` | Wait until a condition (`idle`, `synced`, `dialog_open`, `route_matches`) or timeout. |
| `ui.events` | Returns events since cursor (command invocations, route changes, errors) for polling agents. |

Dialogs are made MCP-operable by building them with a `WonkyDialogSpec` (declarative fields +
buttons) rendered by a shared `WonkyFormDialog`; custom dialogs must implement
`McpDescribableDialog` (`describe()`, `setField()`, `press()`).

App-specific `ui.*` tools (e.g. `ui.write.get_selection`, `ui.write.select_text`,
`ui.sheets.select_range`, `ui.sheets.get_visible_range`) are listed in each app's MCP spec.

## 7. Conventions for tool implementations

- Inputs are validated against the JSON schema (the `wonky_core` definitions, by
  `ToolExecutor`, so both protocol eras behave the same); errors use `isError: true` with a
  structured `{code, message, details}` text payload (`invalid_args` details:
  `[{pointer, message}]`).
- Results include machine-readable JSON (`structuredContent`) plus a short human text summary.
- Every mutating tool returns `change_id` and the new `revision`/`sync_version` where relevant.
- Large outputs are paginated (`cursor`) and capped (default 50k chars) with a `truncated` flag.
- Tool descriptions are written for LLMs: what it does, when to use it, units/addressing
  conventions (A1 notation for Sheets, 0-based Delta offsets vs. Markdown for Write), examples.
- Every tool has an integration test in the server package calling it through
  `ToolExecutor` with a token-resolved user (`test/support/mcp_harness.dart`); the route
  itself is covered end to end over HTTP (raw JSON-RPC, the `mcp_dart` client in both
  protocol profiles, and `wonky_mcp_stdio`).
- Not yet: resource subscriptions (`resources/subscribe`, `notifications/resources/updated`)
  and MCP 2026 `subscriptions/listen`; OAuth 2.1.
