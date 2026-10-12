# 00 · Product Overview — Wonky Work

## 1. Vision

**Wonky Work** is a collaborative office suite built with Flutter (web + desktop) and a single
Serverpod backend. It contains two applications:

| App | Purpose | Closest analogue | Core tech |
|-----|---------|------------------|-----------|
| **Wonky Write** (`wonky_write`) | Collaborative Markdown-first word processor | Google Docs | `super_editor`, Quill Delta OT over Serverpod streams |
| **Wonky Sheets** (`wonky_sheets`) | Collaborative, offline-first spreadsheet | Google Sheets | Serverpod offline-first sync (`database: sync`), formula engine, Dart scripting (`dart_eval`) |

Both apps are served by the same server from one origin (`/write/`, `/sheets/`) and share one
account system and sign-in session, one file system (**Wonky Drive**), one sharing model, one
design system, one command/undo architecture and one MCP (Model Context Protocol) surface.

Guiding principles:

1. **Everything is a command.** Every user-visible action (menu item, toolbar button, keyboard
   shortcut, context-menu entry, MCP tool, AI action) goes through a single command registry. This
   gives us undo/redo for everything and full MCP controllability "for free".
2. **Everything is undoable.** Content edits, formatting, structural changes, renames, moves,
   theme edits, sheet settings — if it changes state the user cares about, it can be undone
   (see [08-commands-and-undo.md](08-commands-and-undo.md)).
3. **Single window.** The app never opens new browser tabs or OS windows. Navigation, dialogs,
   side panels and document switching happen inside one window (see
   [03-app-shell-and-navigation.md](03-app-shell-and-navigation.md)).
4. **Offline is normal.** Sheets is offline-first through the sync engine; Write queues edits
   locally and rebases on reconnect (see [12-offline-and-sync.md](12-offline-and-sync.md)).
5. **Markdown is the truth for Write.** No styling that Markdown (GFM) can't express. Visual
   appearance is controlled only through **themes**.
6. **Agents are first-class users.** The MCP server can do anything a human can, with the same
   permissions and the same undo history.
7. **Light and dark.** Every screen, widget, editor theme, chart and export preview works in both.

## 2. Users and personas

| Persona | Needs |
|---------|-------|
| **Writer** | Distraction-free writing, outline, comments, version history, beautiful exports (PDF/DOCX/EPUB). |
| **Analyst** | Large sheets, formulas, pivot tables, charts, filters, import/export XLSX/CSV. |
| **Team lead** | Sharing, permissions, comments with @mentions, activity, version restore. |
| **Power user / developer** | Keyboard-driven, command palette, scripting in Dart, MCP access with personal access tokens. |
| **AI agent** | MCP tools for headless document/sheet access, plus live UI control of an open app session. |

## 3. Scope

### In scope (v1 "complete")

- Email/password accounts (Serverpod IDP), profiles, avatars, preferences.
- Wonky Drive: folders, recent, starred, shared-with-me, trash, search, templates, upload/import.
- Sharing: per-user roles (Owner, Editor, Commenter, Viewer), link sharing, transfer ownership.
- Real-time collaboration: presence, remote cursors/selections, live edits.
- Comments: threaded, anchored, @mentions, resolve/reopen, notifications.
- Version history: automatic + named versions, browse, compare (Write), restore, copy-from-version.
- Write: all `super_editor`-supported GFM features, theme editor, outline, find/replace, word
  count, page setup, export (Markdown, PDF, HTML, DOCX, ODT, RTF, EPUB, TXT), import (MD, TXT,
  HTML, DOCX best-effort), suggestion mode (tracked changes).
- Sheets: multi-sheet spreadsheets up to ~10M cells, full formula engine (~400 functions),
  formatting, conditional formatting, data validation, sort/filter/filter views, pivot tables,
  charts, named/protected ranges, find/replace, freeze, group, merge, import/export (XLSX, CSV,
  TSV, ODS, PDF), printing, Dart scripting (macros, custom functions, triggers).
- Undo/redo for everything.
- MCP: server-side headless tools + in-app UI bridge.
- AI assistant panel in both apps (Claude, server-side).
- Light/dark/system theme, keyboard shortcuts, command palette, accessibility, i18n-ready.

### Non-goals (v1)

- Mobile phone layouts (the app must not break on narrow widths, but mobile UX is not designed).
- Presentation app (slides), forms app.
- Third-party sign-in providers (Google/Apple/etc.) — email + password only for now; the auth
  layer must not preclude adding them.
- Arbitrary text styling in Write (fonts, colors, sizes per run) — only themes.
- Public internet publishing/hosting of documents (beyond "anyone with the link").
- Real-time co-editing of scripts (script files use last-write-wins with conflict warning).

## 4. Glossary

| Term | Meaning |
|------|---------|
| **Drive item** | A folder, document (Write) or spreadsheet (Sheets) in Wonky Drive. |
| **Document** | A Wonky Write file. Content is a Quill Delta whose attributes map 1:1 to GFM. |
| **Spreadsheet** | A Wonky Sheets file. Contains one or more **sheets** (tabs). |
| **Space** | Offline-sync ownership/sharing unit. **One spreadsheet = one space** (see Sheets data model). |
| **Command** | A named, typed, invocable action (`write.format.bold`, `sheets.rows.insertAbove`). |
| **Undo transaction** | A group of state changes that undo/redo as one step. |
| **Revision** | Monotonic version number of a Write document's operation log. |
| **Presence** | Ephemeral real-time info about who is viewing/editing and where. |
| **MCP** | Model Context Protocol — the tool interface for AI agents. |
| **UI bridge** | The channel through which MCP tools drive a live, open app session. |
| **Theme (Write)** | A named style sheet mapping Markdown elements to visual styles. |
| **App theme** | Light/dark/system appearance of the app chrome (not to be confused with Write themes). |

## 5. Document map

Suite-level specs live in `/specs`. App specs live in [`/specs/wonky_write`](wonky_write/README.md)
and [`/specs/wonky_sheets`](wonky_sheets/README.md). See [README.md](README.md) for the full
index and reading order.
