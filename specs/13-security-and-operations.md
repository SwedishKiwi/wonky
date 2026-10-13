# 13 · Security, Privacy and Operations

## 1. Threat model (summary)

| Threat | Mitigation |
|--------|------------|
| Unauthorized document access | All reads/writes through `AccessService`; ids are unguessable UUIDs but never treated as secrets; per-endpoint role tests |
| Privilege escalation via crafted ops (Write) | Server validates every op against schema + role-specific op shapes (Write 03 §5) |
| Tampered sync client (Sheets) | Space role enforced by the sync engine (readOnly can't write). Protected ranges are advisory (documented). Server-side jobs (versions, triggers) treat synced data as untrusted input |
| XSS via document content (HTML export, link hrefs) | Markdown/HTML exporters escape; links restricted to `http(s)`, `mailto`, `wonky://`; `javascript:` and `data:` rejected at schema validation |
| SSRF (IMPORTDATA/IMAGE/UrlFetch/image-from-URL) | Server-side fetch proxy: DNS resolution then block private/link-local/metadata ranges, allowlisted ports 80/443, 10 s timeout, 10 MB cap, content-type checks, per-user quotas |
| Script sandbox escape | `dart_eval` default-deny permissions; no FS/process; network only via bridged proxy; isolate/worker kill on timeout; memory caps via value-count limits |
| MCP token theft | Tokens hashed (SHA-256), shown once, scoped, expirable, revocable, `lastUsedAt` displayed; rate limits |
| Prompt injection via document content into AI/MCP | AI tool layer enforces the user's permissions; AI cannot call sharing/permission tools; destructive bulk operations require confirmation; content from documents is placed in user-turn context, never system prompt |
| CSRF / DNS rebinding on `/mcp` | Bearer auth only (the web apps' auth cookie is ignored on `/mcp`), `allowedHosts`/`allowedOrigins` checks |
| File upload abuse | Type sniffing, size limits (images 20 MB, imports 100 MB), image re-encoding for thumbnails, private storage with signed URLs (15 min) |
| Brute-force login | Serverpod IDP rate limiting; generic error messages |
| Test-support endpoint left open (E2E verification codes, 15 §9) | `e2eSupport` refuses every call outside the `development`/`test` run modes and only serves `@example.test` addresses; a server test asserts the refusal in `staging`/`production` |
| Session token theft via XSS (web) | Cookie auth: tokens in an httpOnly, `secure`, `SameSite=lax` cookie shared by both apps; `allowedOrigins` restricts credentialed cross-origin calls (01 §2.5) |

## 2. Privacy
- Data minimization in logs (no document content in logs; ids only).
- AI: opt-out per user and per deployment; notice in panel naming the provider. Provider API
  keys (server passwords `openaiApiKey`, `anthropicApiKey`, `geminiApiKey`, and users' own keys
  in `ai_user_key`) are server-side only. A user's own key is accepted only while the server has
  none, used only for that user's requests, never logged and never returned (the client sees the
  provider and the last four characters); the model is `serverOnly`. It is stored **unencrypted**
  in Postgres (there is no encryption helper): database access or a backup exposes it, so
  deployments that must avoid that set `ai.allowUserKeys: false` and configure a server key.
- Account deletion deletes owned items (or transfers on request), personal spaces, tokens,
  notifications; anonymizes authorship in shared items ("Deleted user").
- Export of all user data (*Settings › Account › Download your data*: zip of documents as
  Markdown, spreadsheets as XLSX, comments as JSON) — P1.

## 3. Operations
- **Deployment**: Serverpod Cloud (default) or Docker (existing `Dockerfile`); Postgres; Redis
  required for > 1 instance (§4); cloud storage (Serverpod Cloud storage or S3/GCS) for uploads,
  exports, version snapshots, script bytecode.
- **Web builds**: both Flutter web apps (`wonky_write`, `wonky_sheets`) built with `--wasm` by
  the server's `flutter_build` script into `wonky_server/web/write` and `wonky_server/web/sheets`
  (01 §2.4), served by `FlutterRoute` with WASM headers (`enableWasmHeaders: true`; COOP/COEP required for
  `SharedArrayBuffer`/OPFS performance). `sqlite3.wasm` + `db_worker.js` shipped in each app's
  `web/` folder (versions pinned to the `sqlite_async` version). Because both apps are served
  cross-origin-isolated (COOP `same-origin` + COEP `require-corp`, also needed for the Sheets
  script bridge's SharedArrayBuffer), every cross-origin subresource must send CORP/CORS headers:
  external images (Write image-by-URL, Sheets `IMAGE()`) are therefore loaded through the
  server's image proxy (`/files/proxy?url=…`, SSRF-protected, cached), never directly.
- **Script workers**: Sheets scripts (installable/time-driven triggers, MCP `run_function`) run
  on server instances started with the `sheets.scripts.worker: true` role, consuming a job queue
  with an isolate pool (Sheets 09); API instances don't execute scripts. One combined role is
  fine for small deployments.
- **Migrations**: Serverpod migrations; synced-schema changes batched into "sync schema
  releases" (lock-step, see 01 §7).
- **Backups**: Postgres PITR; cloud storage versioning for snapshots.
- **Scheduled jobs** (Serverpod FutureCalls): trash purge (daily), version capture & thinning
  (every 5 min scan / nightly thinning), op-log pruning (daily), ChangeLog pruning (daily),
  space active-set eviction (daily), email digests (15 min), script time-driven triggers
  (minute resolution), AI usage rollups (hourly), orphan file cleanup (weekly).
- **Feature flags**: config-driven flags (`features.*`) for AI, scripting, MCP UI bridge,
  experimental chart types — checked server-side and delivered to clients in `meta.getInfo()`.

## 4. Running several instances

The server runs as one instance or as several identical instances behind a load balancer
(no sticky sessions needed). Several instances **require Redis**: Postgres is the only shared
state besides Redis, and `session.messages` is global only with Redis.

**Enabling it.** `config/staging.yaml` and `production.yaml` ship with `redis: enabled: false`
(a single instance, which works wherever no Redis is provisioned). To scale out, enable Redis in the
config or with `SERVERPOD_REDIS_ENABLED=true`, `SERVERPOD_REDIS_HOST`, `SERVERPOD_REDIS_PORT`
and `SERVERPOD_REDIS_PASSWORD` (or `redis:` in `passwords.yaml`). Only enable it with a Redis
that is reachable: in `production` run mode Serverpod does not fall back when Redis is down,
and every message (also to sessions on the same instance) is then lost. In staging/production
the server prints a warning at start when Redis is disabled. Development and tests run
without Redis.

**How the pieces work across instances** (helpers in
`wonky_server/lib/src/platform/cluster/cluster.dart`: `Cluster.instanceId`,
`Cluster.distributed` = Redis enabled, `ClusterSignal`s on channel `wonky:cluster`,
`Cluster.withLock` = Postgres advisory lock):

| Area | Mechanism |
|------|-----------|
| Bus channels (`doc:`, `presence:`, `theme:`, drive, comments, notifications, `sheets:merged:`) | `session.messages` with the default `MessageScope.auto`: global via Redis. Listeners receive deserialized copies; delivery is best effort and unordered |
| Write OT commits | Postgres row lock + catch-up from the op log (Write 03 §2) — correct on any instance |
| Write in-memory `DocumentState` | Each instance keeps its own. Remote `op` messages make it catch up from the op log (coalesced), and `CursorUpdate`, `RequestOps` and `HashCheck` first catch up to the revision the client names, so gap fills and cursor transforms never use a stale head |
| Document and presence rosters | `hello`/`here`/`left` plus, with Redis, a `beat` every 30 s; participants not heard of for 90 s are dropped (crashed instance, lost `left`); a `beat` of an unknown participant adds it. MCP/AI agents get a session id derived from user + document + agent, so all instances show one participant, and re-announce while active |
| Editor limit (Write 03 §7) | Checked at Init and, with Redis, again 2 s later when the `here` replies of other instances arrived (editors that joined earlier count); an over-limit joiner is switched to viewer (`RoleChanged`) |
| MCP sessions (`Mcp-Session-Id`) | Registered in Redis (`wonky:mcp:session:<id>`, TTL = idle time, refreshed each minute of use). An instance that does not know a session resumes it (replays the stored `initialize`); `DELETE` and expiry apply everywhere; new sessions are marked ready by the server so `notifications/initialized` may land anywhere. The `GET` event stream only carries notifications of the instance serving it |
| MCP rate limit | Fixed one-minute window per token counted in Redis (`INCR`), so the limit is global (up to 2× at a window boundary); in-memory sliding window without Redis or when Redis fails |
| MCP UI bridge | Windows are registered on the instance serving their stream and listen on `uibridge:user:<userId>` and `uibridge:window:<id>`. `ui.list_sessions` merges local windows with replies collected for 300 ms; calls to a window elsewhere are relayed and answered on `uibridge:reply:<requestId>` |
| AI assistant `stop` / `confirm` | Unary calls handled locally when the run is here, else relayed as `ClusterSignal`s to the instance running the chat stream |
| Profile-id cache (`UserService`) | Account deletion invalidates it on all instances (`user.forget` signal) |
| Recurring jobs (FutureCalls) | Every instance reconciles the schedule at start under an advisory lock: existing jobs with the same cron are kept, missing ones added, changed or duplicated ones replaced. Serverpod claims each run, so it executes on one instance |
| Sheets change-log consumer | Exactly once per row via `sheets_change_log_receipt` (insert-or-skip) |

**Accepted per-instance limits** (soft limits; documented, not enforced globally):
AI concurrency per user (`ai.maxConcurrentRequests`, Suite 10) and export concurrency per user
are counted per instance; "one run per assistant thread" is checked per instance (the app
already prevents a second run); the maximum of 20 MCP sessions per user is per instance;
caches of signed/public URLs and the AI feature fallbacks are per instance. E2E verification
codes (`platform/e2e/`) are in memory and exist only in development/test, which run one
instance.

**Known framework caveat.** Serverpod's Redis controller keeps one callback per channel and
re-subscribing right after the last listener of a channel unsubscribed can lose that
subscription's messages until the next listener change; our streams subscribe after several
database round trips, which avoids the race in practice.

**Tests** simulate a cluster on one process: `Cluster.debugDistributed = true` turns on the
cluster code paths on the local bus, messages from "another instance" are posted with a
foreign `originInstance` or straight onto the channels, evicting `DocumentCache` gives a
connection the state another instance would have, and two `McpHttpHandler`s share an
`InMemoryMcpSessionDirectory`.

## 5. Legal pages

The web server serves a privacy policy (`/privacy`) and terms of service (`/terms`): static
HTML in `wonky_server/web/pages/` (`privacy.html`, `terms.html`), styled like the app (light and
dark, the Wonky Work icon). They name Serverpod AB (Sjöbjörnsvägen 46, 117 67 Stockholm, Sweden)
as the provider and data controller, and are linked from the sign-up screen (suite 04 §1.1).
Google sign-in requires both: the consent screen links `https://wonky.work/privacy` and
`https://wonky.work/terms` (04 §1.6). Keep them in step with the product (data collected, AI providers,
retention — trash is purged after 30 days, `DriveService.trashRetention`) and have changes
reviewed before publishing; material changes update the effective date and are announced.

