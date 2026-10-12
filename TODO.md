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
2. ☐ **More export formats**: DOCX, ODT, RTF and EPUB (Write 07).
   - **DOCX import:** a draft exists in `wonky_write_core/lib/src/import/docx/` but is not exported. `WonkyImporters` refuses DOCX, ODT and RTF.
   - **Server-side PDF/HTML export** needs a file-system `FontProvider`. Today `writeExport.export` supports only md and txt.
   - **Server-side HTML/DOCX import.**
3. ☐ **MCP** (suite 09, Write 09):
   - the `/mcp` Streamable HTTP route, `ToolExecutor`, and the `drive.*` / `write.*` / `comments.*` / `versions.*` tools;
   - the UI bridge hub, the client bridge, and the `ui.*` / `ui.write.*` tools;
   - the `wonky_mcp_stdio` shim;
   - personal access token UI polish.

   The core `DocumentEdits` / `DocumentReader` / `AddressResolver` already cover the headless editing logic.
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
- PDF export renders non-Latin-1 text only with the bundled TTF fonts.
