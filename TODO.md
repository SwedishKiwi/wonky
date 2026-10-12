# Wonky Work — TODO

The first iteration delivers **Wonky Write**: sign-in, drive, sharing, a real-time
collaborative editor, comments, suggestions, history, themes, import and export. The
specs in `specs/` remain the source of truth. This file lists what is not done yet.

**Wonky Sheets is paused.** Its state and how to resume it are in
[specs/wonky_sheets/STATUS.md](specs/wonky_sheets/STATUS.md).

Status legend: ☐ open · ◐ in progress · ☑ done (done items are removed once they are
committed and verified).

## Wonky Write — deferred features (in planned order)

1. ☐ **Theme editor UI** (Write 06 §5).
   - The server `writeTheme` endpoints already support it: create, update with version conflicts, revisions, duplicate and usage.
   - The core `WriteThemeData`, validator, resolver and contrast checker already exist.
2. ☑ **Import/export formats** (Write 07): DOCX, ODT, RTF and EPUB exporters plus DOCX, ODT and RTF importers in `wonky_write_core`. Exporting and re-importing our own files gives back the same document for all 8 themes, except that RTF brings heading numbers back as text. Server `writeExport.export` covers all 10 formats, with bundled fonts in `web/fonts` and images read from storage; `drive.import` and `convertForInsert` accept HTML, DOCX, ODT and RTF. In the app, File › Download lists every format, and File › Import / Insert from file accept them; the import banner shows on first open. Still open:
   - the server export cache and the isolate pool; large documents still export on the client;
   - SVG images in DOCX/ODT/RTF/EPUB (rendered as placeholders);
   - comments in DOCX/ODT exports and embedded DOCX fonts (both P2);
   - LibreOffice and epubcheck validation in CI.
3. ☑ **MCP** (suite 09, Write 09) — `/mcp` Streamable HTTP route on the web server (custom
   `mcp_dart` transport; MCP 2026-07-28 stateless + initialize-era sessions), PAT bearer auth
   with scopes, host/origin checks and rate limits; `ToolExecutor` with `drive.*`, `write.*`
   (23 tools), `comments.*`, `versions.*`, `changes.revert`, resources and prompts; UI bridge
   (`uiBridge.connect` + `UiBridgeHub`, client bridge with shared `ui.*` and `ui.write.*`
   tools, control pill with Stop); `wonky_mcp_stdio`; Settings › Developer (tokens with
   scopes/expiry, connection snippets, bridge status). Remaining:
   - resource subscriptions (`notifications/resources/updated`) and MCP 2026
     `subscriptions/listen`; OAuth 2.1;
   - `write.compare_versions`, `write.get_theme`, `write.create_theme`/`update_theme`
     (with the theme editor), the `write.search` regex timeout;
   - the UI-bridge hub is per server instance (no cross-instance relay yet);
   - `ui.write.get_layout_info` does not report the visible Delta range yet.

4. ☐ **AI assistant** (suite 10, Write 09): the server `AnthropicClient` and assistant service, the assistant panel, inline AI (selection ✨ menu, `/ai`, Mod+J), and "Suggest" apply mode.
5. ☐ **Offline persistence** (suite 12 §1):
   - SQLite `LocalDocument` / `LocalPendingOp` / `LocalUndoStack` / `LocalPendingUpload`;
   - offline document creation, and "Make available offline";
   - the offline drive cache and pending drive-op queue.

   The outbox is in memory today.
6. ☐ **Spellcheck** (Write 04, P1): a pure-Dart Hunspell-style checker and the editor hook.
7. ☐ **Editor extras:**
   - SE-4 in-place table cell editing (tables are edited through the table dialog today);
   - drag and drop of text, files and blocks (block-handle drag);
   - emoji picker and special characters;
   - image lightbox;
   - focus mode and typewriter scrolling.
8. ☐ **Notifications**: email digests (no mail provider is configured; the job only logs), mention emails, and the activity dashboard (07 §6).
9. ☐ **Quality**:
   - i18n beyond English (pseudo-locales);
   - golden tests on CI;
   - E2E `integration_test` journeys (11 §1.1);
   - extending CI to every package plus the dependency-rule check (01 §2.1);
   - a performance suite.
10. ☐ **Deployment**:
    - verify production builds served by the server at `/write/` and `/sheets/` (`serverpod run flutter_build`), with WASM and cross-origin-isolation headers;
    - the sign-in is shared on the single origin; in development the two `flutter run` origins (8101 and 8102) don't share it.
11. ☐ **Desktop** packaging (macOS first): native menubar, keychain sharing between apps, `wonkysheets://` / `wonkywrite://` URL schemes.

## Known issues

- Version restore uses the shell's server-side restore; undoing it restores the restore point (Write 08 §4.5).
- When a role is downgraded while editing, pending ops that are no longer allowed are discarded through a resync, not converted into suggestions.
- Recurring server jobs are re-registered on every server start under fixed identifiers.
- Search uses no full-text GIN index yet.
- shad tooltips and popovers swallow Esc; the toolbar works around this with `ToolbarEscapeScope`.
- PDF exports (client and server) cover Latin, Greek and Cyrillic with the bundled TTFs; CJK, Arabic and emoji fall back to placeholders until the fallback fonts are added.
