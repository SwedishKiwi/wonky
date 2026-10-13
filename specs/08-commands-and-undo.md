# 08 · Commands, Keyboard Shortcuts and Undo/Redo

This is the single most important cross-cutting architecture in Wonky Work. **Every** state change
that a user (human or agent) can trigger is a **command**. Commands are what menus, toolbars,
context menus, keyboard shortcuts, the command palette, the MCP UI bridge and the AI assistant
invoke. Undo/redo is built on top of commands.

Package ownership:

| Piece | Package |
|-------|---------|
| `CommandId`, `CommandArgs` schema types, `UndoEntry` abstractions (pure Dart) | `wonky_core` |
| `CommandRegistry`, `CommandDispatcher`, `KeymapService`, `UndoService`, Command Palette widget | `wonky_app` |
| App-specific commands | `wonky_write/lib/commands/…`, `wonky_sheets/lib/commands/…` |

---

## 1. Command model

```dart
/// Stable, dot-separated id. Never rename once shipped (MCP clients depend on it).
/// Convention: <app|shell>.<area>.<action>, e.g. "write.format.bold",
/// "sheets.rows.insertAbove", "shell.drive.newFolder".
extension type const CommandId(String value) {}

abstract class Command<A extends CommandArgs> {
  CommandId get id;

  /// Human title, localized. Used in menus, palette, tooltips, undo labels ("Undo Bold").
  String title(BuildContext context);

  /// Optional longer description; shown in palette and exposed to MCP as tool description.
  String? description(BuildContext context) => null;

  /// Icon (Lucide icon data from shad).
  IconData? get icon => null;

  /// JSON-schema of the arguments, used by MCP (`ui.invoke_command`) and the AI assistant.
  JsonSchema get argsSchema;
  A parseArgs(Map<String, Object?> json);

  /// Default key bindings (platform-aware). Users can override in Settings → Keyboard.
  List<KeyBinding> get defaultBindings => const [];

  /// Whether the command can currently run (drives disabled state everywhere).
  bool isEnabled(CommandContext ctx, A args) => true;

  /// For toggle commands (bold, show gridlines…): current checked state.
  bool? isChecked(CommandContext ctx) => null;

  /// Minimum role required; checked by the dispatcher before execute.
  Role get requiredRole => Role.editor;

  /// Whether this command mutates undoable state. Non-mutating commands (navigation,
  /// zoom, open dialog) return false and never create undo entries.
  bool get isUndoable => true;

  /// Executes. May be async (e.g. dialogs, server calls). Returns a result that is serialized
  /// back to MCP callers.
  Future<CommandResult> execute(CommandContext ctx, A args);
}
```

`CommandContext` exposes: the active app (`write`/`sheets`), the active document controller (if
any), the current selection, the user's role on the document, the `UndoService`, the
`BuildContext` (for dialogs; null when headless), and an `InvocationSource` enum
(`menu`, `toolbar`, `shortcut`, `contextMenu`, `palette`, `mcp`, `ai`, `script`).

### 1.1 Registry and dispatch

- `CommandRegistry` is populated at app start. Shell commands are registered by `wonky_app`;
  each app registers its own. Registration is static — no dynamic commands except **script
  macros** in Sheets (`sheets.macro.<macroId>`), registered when a spreadsheet loads.
- `CommandDispatcher.invoke(id, args, source)`:
  1. Looks up command; throws `UnknownCommand` if missing.
  2. Validates args against schema.
  3. Checks role ≥ `requiredRole` (viewers can't run mutating commands; commenters can only run
     comment commands).
  4. Checks `isEnabled`.
  5. Opens an **undo transaction** if `isUndoable` (see §3), runs `execute`, commits the
     transaction (or rolls back on exception).
  6. Emits a `CommandInvoked` event (used for analytics/debug log and the MCP `ui.events` stream).
- Menus/toolbars use `CommandButton(id: …)`, `CommandMenuItem(id: …)` widgets from `wonky_app`
  that read title/icon/shortcut/enabled/checked from the registry and rebuild on relevant changes.
  **No menu or toolbar may call business logic directly.**

### 1.2 Keyboard shortcuts

- `KeymapService` maps `KeyBinding` → `CommandId` (+ fixed args). Platform-aware: `Mod` = ⌘ on
  macOS, Ctrl elsewhere. On web, browser-reserved shortcuts (⌘W, ⌘T, ⌘N, ⌘L) are never bound.
- Scopes: `global` (app shell), `editor` (Write editor focused), `grid` (Sheets grid focused),
  `cellEditor` (Sheets cell editing), `dialog`. More specific scopes win.
- **Contextual bindings**: a key binding may map to an ordered list of commands within a scope;
  the dispatcher runs the first one whose `isEnabled` is true (e.g. `Tab` = indent list item →
  insert spaces in code block → move focus; `Mod+J` = inline AI prompt when the caret is in an
  empty paragraph → toggle assistant panel otherwise). Conflict detection in the settings
  screen treats such lists as one binding.
- Shared edit commands have fixed ids: `shell.edit.undo`, `shell.edit.redo`, `shell.edit.cut`,
  `shell.edit.copy`, `shell.edit.paste`, `shell.edit.pasteWithoutFormatting`,
  `shell.edit.selectAll`, `shell.edit.undoHistory`; apps contribute the actual behavior through
  the active document controller.
- User overrides are stored in `UserPreferences.keymapOverrides` (JSON) and synced via server.
- **Settings → Keyboard shortcuts** screen: searchable table of all commands with bindings;
  click to record a new binding; conflict detection with "Replace"/"Cancel"; reset per row and
  "Reset all".
- **Keyboard shortcuts help** dialog (`Mod+/`): categorized read-only list, searchable.

### 1.3 Command palette

- Opened with `Mod+Shift+P` (`Mod+K` is reserved for *Insert link* in both apps, as in Google
  Docs/Sheets). Built from shad `ShadDialog` + custom
  `CommandPalette` list (see design system).
- Fuzzy search over title, description, aliases and menu path ("Format › Text › Bold"). This is
  also how menu commands are searched (there is no separate "Search the menus" mode).
- Rows for files show the file's kind icon (`PaletteRow.leading`, `DriveKindIcon`, suite 02 §5).
- Shows shortcut on the right, disabled commands greyed (with reason tooltip).
- Sections: *Recent*, *Suggested* (context-dependent), *All commands*. Additional providers:
  "Go to document…" (drive search), "Go to sheet/heading…", "Ask AI: <query>".
- Commands that need args show an inline arg form (e.g. "Insert rows… → count").

---

## 2. What counts as undoable

| Area | Undoable | Not undoable (by design) |
|------|----------|--------------------------|
| Write content | All text/structure/format edits, paste, find-replace-all, AI insertions | — |
| Write metadata | Title rename, theme assignment, theme edits, page setup, document language | Sharing changes |
| Sheets content | Cell values, formulas, formats, row/col ops, sheet ops, merges, CF/DV rules, filters, sorts, charts, pivots, named ranges, protected ranges | — |
| Sheets settings | Spreadsheet settings (locale, recalc, iterative calc), sheet properties (name, color, gridlines, frozen panes) | — |
| Drive | Move, rename, star, trash (undo = restore), create folder | Permanent delete, sharing changes, ownership transfer |
| View state | — | Zoom, scroll, panel visibility, selection (selection is *restored* on undo but isn't an undo step) |
| Comments | Creating/editing/deleting own comment, resolve/reopen | — |

Non-undoable actions that are destructive (permanent delete, unshare) always show a confirm
dialog instead.

---

## 3. Undo architecture

### 3.1 Principles

1. **Local, per-user, per-document undo** (like Google Docs/Sheets): undo only reverts *your*
   changes, never a collaborator's. Remote changes are never on your stack.
2. **Undo is a forward operation.** Undoing writes a new change that restores previous state.
   Collaborators see it as a normal edit. Nothing is ever "rewound" on the server.
3. **Transactions.** One user gesture = one undo step. Commands open a transaction; the
   transaction collects `UndoEntry`s from each affected domain and commits them atomically.
4. **Typing coalescing.** Consecutive character insertions/deletions in the same block within
   1000 ms and without caret jumps coalesce into one step (Write and Sheets cell editor).
5. **Selection restoration.** Each step records `selectionBefore` and `selectionAfter`; undo
   restores `selectionBefore`, redo restores `selectionAfter`.
6. **Redo is cleared** by any new local undoable change.
7. **Stack size**: 500 steps per document (configurable constant). Stacks are kept in memory and
   persisted to local storage per document so undo survives reload (best-effort; cleared when
   the local document state is discarded).
8. **Labels**: every step has a label ("Undo Typing", "Undo Insert row", "Undo Paste") shown in
   Edit menu and tooltips.

### 3.2 Core types (`wonky_core`)

```dart
abstract class UndoEntry {
  /// Domain key ("write.content", "write.meta", "sheets.cells", "drive"…). Used to
  /// route the entry to the right UndoHandler.
  String get domain;

  /// Called when a remote change arrives in this domain. Returns the rebased entry,
  /// or null if the entry is now a no-op (e.g. the edited text was deleted remotely).
  UndoEntry? rebase(RemoteChange change);
}

class UndoStep {
  final String label;
  final List<UndoEntry> entries;           // applied in reverse order on undo
  final SelectionSnapshot? selectionBefore;
  final SelectionSnapshot? selectionAfter;
  final DateTime createdAt;
  final InvocationSource source;           // so MCP/AI steps can be labelled ("Undo AI edit")
}

abstract class UndoHandler<E extends UndoEntry> {
  String get domain;
  /// Apply the inverse of [entry] as a new forward change; return the entry that would redo it.
  Future<E> undo(E entry);
  Future<E> redo(E entry);
}
```

`UndoService.replaceLast(step)` replaces the top undo step in place (used by follow-up
refinements of the last action, e.g. re-running *Split text to columns* with another
separator or changing a paste-special mode from the paste chip).

`UndoService` (in `wonky_app`) owns `undoStack`/`redoStack` per open document plus one
**shell stack** for drive operations, exposes `canUndo/canRedo/undoLabel/redoLabel` as
`ValueListenable`s, and exposes `beginTransaction(label)` / `commit()` / `rollback()`.

### 3.3 Domain strategies

| Domain | Entry content | Undo action | Rebase on remote change |
|--------|---------------|-------------|-------------------------|
| `write.content` | Inverse Quill Delta of the local change | Submit the inverse delta as a new local op | `inverse = remoteDelta.transform(inverse, priority)` (OT transform; see Write sync spec) |
| `write.meta` | `{field, before, after}` for title/theme/page setup | Write `before` via endpoint | If server value ≠ `after` (someone else changed it), entry is dropped (no-op) |
| `write.theme` | Theme JSON before/after | Save theme `before` | Same as `write.meta` |
| `sheets.rows` (generic sync rows) | List of `{table, rowId, op: insert/update/delete, columnsBefore, columnsAfter}` | Write inverse via sync DB transaction naming only those columns | Per column: if current value ≠ `after`, that column is skipped ("someone else changed it"). If all columns skipped, the entry is a no-op |
| `sheets.serverChange` | `{changeId}` of a change executed server-side on the user's behalf (version restore, server import, AI/MCP loops) | `SheetsEndpoint.revertChange(changeId)` (redo: `reapplyChange`) — server applies the per-column skip rule | Server-side, same rule as `sheets.rows` |
| `drive` | `{itemId, op, before, after}` | Call drive endpoint with `before` | Same as `write.meta` |
| `comments` | Comment snapshot | Restore/delete/edit via endpoint | Drop if the thread was deleted |

When an undo step becomes **partially** no-op due to remote changes, the UI shows a toast:
*"Some changes couldn't be undone because they were edited by someone else."*

### 3.4 MCP and AI integration

- MCP tool calls and AI actions run through the dispatcher, so their changes land on the
  **acting user's** undo stack, labelled with the source ("Undo AI: Rewrite paragraph").
- A single MCP tool call = one undo step, even if it touches many cells/blocks.
- MCP exposes `ui.undo`/`ui.redo` (live session) and the headless `write.undo`/`sheets.undo`
  are **not** offered (headless tools have no client stack). Instead headless tools return a
  `changeId`, and headless `*.revert_change(changeId)` reverts that change using the same
  inverse data recorded server-side for 24 hours.

### 3.5 Edit menu contract (both apps)

| Item | Shortcut | Notes |
|------|----------|-------|
| Undo *label* | Mod+Z | Disabled when stack empty |
| Redo *label* | Mod+Shift+Z, Mod+Y (Win/Linux) | |
| Cut / Copy / Paste | Mod+X / C / V | |
| Paste without formatting | Mod+Shift+V | |
| Select all | Mod+A | |
| Delete | Del | |
| Find and replace | Mod+H (Mod+Shift+H on macOS web) | |

A **History** popover (click-and-hold the Undo toolbar button, or *Edit › Undo history…*) lists
the last 50 steps with labels and timestamps; clicking a step undoes everything above it (one
undo per step, executed in order).

---

## 4. Testing requirements

- Every command has a unit test that runs `execute` then `undo` then `redo` and asserts state
  equality (structural equality of document/rows, and selection).
- Property test for Write: random local+remote op sequences; after undoing all local steps, the
  document equals "initial + remote ops only".
- Property test for Sheets: random edits from two simulated clients; undo of client A never
  modifies a column last written by client B.

---

## 5. Shell command catalog (shared by both apps)

Canonical ids for commands implemented in `wonky_app` (apps may only *contribute behavior*
through the active document controller, never re-register these ids):

| Area | Command ids |
|------|-------------|
| Navigation | `shell.nav.home`, `shell.nav.back`, `shell.nav.forward`, `shell.nav.quickSwitcher`, `shell.nav.commandPalette`, `shell.focus.nextRegion`, `shell.focus.previousRegion` |
| File | `shell.file.new {kind}`, `shell.file.newFromTemplate`, `shell.file.open`, `shell.file.import`, `shell.file.print`, `shell.file.download {format}`, `shell.file.details` |
| Drive | `shell.drive.newFolder`, `shell.drive.rename`, `shell.drive.move`, `shell.drive.copy`, `shell.drive.addShortcut`, `shell.drive.setStarred`, `shell.drive.togglePinnedOffline`, `shell.drive.trash`, `shell.drive.restore`, `shell.drive.deleteForever`, `shell.drive.emptyTrash`, `shell.drive.upload` |
| Sharing | `shell.sharing.open`, `shell.sharing.copyLink`, `shell.sharing.requestAccess` |
| Edit | `shell.edit.undo`, `shell.edit.redo`, `shell.edit.undoHistory`, `shell.edit.undoTo {stepIndex}`, `shell.edit.cut`, `shell.edit.copy`, `shell.edit.paste`, `shell.edit.pasteWithoutFormatting`, `shell.edit.selectAll` |
| Comments | `shell.comments.create`, `shell.comments.reply`, `shell.comments.resolve`, `shell.comments.reopen`, `shell.comments.delete`, `shell.comments.activate {threadUuid}`, `shell.comments.togglePanel` (show through the app's `CommentsHost` when set, else the comments side panel; suite 07 §2.3) |
| Versions | `shell.versions.open`, `shell.versions.togglePanel`, `shell.versions.nameCurrent`, `shell.versions.restore {versionId}` |
| Panels | `shell.panels.open {panelId}`, `shell.panels.close {panelId}`, `shell.panels.toggle {panelId}` (in the editors, closing collapses the panel to the icon rail, suite 02 §4.5) |
| MCP | `shell.mcp.copyConnectionInfo`, `shell.mcp.toggleUiBridge`, `shell.mcp.stopControl` |
| View | `shell.view.zoom {percent}` (the editor chrome is always shown: no compact mode, full screen or show/hide toggles for toolbar, menubar or status bar) |
| Appearance & settings | `shell.appearance.setTheme {mode}`, `shell.settings.open {section}` |
| AI | `shell.ai.togglePanel`, `shell.ai.newThread`, `shell.ai.send`, `shell.ai.stop` |
| Help | `shell.help.shortcuts`, `shell.help.feedback`, `shell.help.whatsNew`, `shell.help.about` (no help center or menu search) |
| Account | `shell.account.signOut`, `shell.account.switchApp {app}` |
