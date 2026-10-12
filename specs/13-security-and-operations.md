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
- AI: opt-out per user and per deployment; notice in panel; Anthropic API key server-side only.
- Account deletion deletes owned items (or transfers on request), personal spaces, tokens,
  notifications; anonymizes authorship in shared items ("Deleted user").
- Export of all user data (*Settings › Account › Download your data*: zip of documents as
  Markdown, spreadsheets as XLSX, comments as JSON) — P1.

## 3. Operations
- **Deployment**: Serverpod Cloud (default) or Docker (existing `Dockerfile`); Postgres; Redis
  required for > 1 instance; cloud storage (Serverpod Cloud storage or S3/GCS) for uploads,
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
