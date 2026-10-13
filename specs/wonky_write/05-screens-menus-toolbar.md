# Write 05 · Screens, Menus, Toolbar, Panels and Dialogs

Defines every Wonky Write screen and every piece of chrome around the editor: header, menubar
(every item), toolbar (every control), floating toolbars, context menus, slash/block menus,
popovers, side panels, comment margin, word count bar, dialogs, empty/loading/error states,
view modes, Pages vs Pageless rendering, responsive behaviour and light/dark rules.

Editing behaviour behind each control is in [04-editor.md](04-editor.md) (command ids are
defined there, §40). Shared shell structure is in
[suite 03](../03-app-shell-and-navigation.md); components in
[suite 02](../02-design-system.md). **No widget may call business logic directly** —
every control is a `CommandButton`/`CommandMenuItem` bound to a command id (suite 08 §1.1).

## 1. Conventions

- Shortcut columns: *macOS* / *Win-Linux*; `—` = no default binding.
- "Enabled when" uses these predicates: `editable` = mode Editing or Suggesting and role ≥
  commenter (C*) or editor (E) as the command requires; `selText` = non-empty text selection;
  `caretText` = caret/selection in a text block that is not a code block; `inCode`,
  `inTable`(table block selected), `onImage`, `onLink`, `inList`, `inTask`; `copyAllowed`
  (role ≥ editor or owner setting allows); `aiOn` (server + user AI enabled); `online`.
- Ids of commands owned by the shell are prefixed `shell.`; where the suite specs don't name
  them yet, the id here is the proposed name (listed in §23).
- Every menu, toolbar and context-menu tree is declared once as a `MenuSpec`
  (`lib/config/write_menus.dart`: the shell's shared menus extended with Write items plus the
  Insert and Format menus), which also feeds the command palette menu paths, the macOS native
  menubar (`PlatformMenuBar`) and MCP `ui.get_menu_tree`. Context, block and code-language menus
  are built from the same commands in `lib/features/screen/document_menus.dart`.

## 2. Screen inventory

| Screen | Route | Owner spec | Notes |
|--------|-------|-----------|-------|
| Home / Drive views | `/`, `/drive/:uuid`, `/shared`, `/starred`, `/recent`, `/offline`, `/trash`, `/search` | suite 05 | Filtered to documents by default; Write template strip |
| Template gallery | `/templates` | suite 05 §3.1 | Built-in document templates, each with its own Write theme: Meeting notes, Project brief, Letter, Weekly report, Lecture notes, To-do list, Recipe, Story draft (plus Blank) |
| **Document editor** | `/d/:uuid` (`?heading=`, `?comment=`, `?suggestion=`, `?version=`) | **this spec §3–§19** | Main screen |
| Version history | `/d/:uuid/history` | [08](08-comments-suggestions-history.md), suite 07 §5 | Full-screen compare; read-only `SuperReader` |
| Print / PDF preview | `/d/:uuid/print` | [07](07-import-export-print.md) | Full-screen in-app preview |
| Theme editor | `/themes/:themeUuid?doc=<itemUuid>` (`/themes` opens the last edited theme) | [06](06-themes.md) §10 | Full-screen; live preview of a sample or the open document |
| Settings › Write | `/settings/write` | suite 04 §4 + §13.3 here | Default theme, page setup, editor prefs |
| No access / Not found | `/d/:uuid` (state) | suite 03 §2 | *Request access*, *Switch account* |
| Auth screens | `/signin` … | suite 04 | |

## 3. Document editor screen

### 3.1 Layout (desktop ≥ xl, Pages mode, comments margin visible)

```
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ [W] Q3 planning ☆ 📁 ✓ Saved        (A)(B)(C)+2  💬3  🕘  ✨  [🔒 Share]  (me)   │ Title row 48
│ File  Edit  View  Insert  Format  Tools  Help                                                │ Menubar 32
│ ↶ ↷ 🖨 │ 100% ▾ │ Normal text ▾ │ B I S <> │ 🔗 💬 🖼▾ ⊞▾ │ • 1. ☑ ⇤ ⇥ │ ❝ {} │ T̸ │ ⋯ ✎Editing▾│ Toolbar 40
├──────────────────────────────────────────────────────────────────────┬───────────────────────┤
│ canvas ░░░░░░░░░░░░░░░░░░░░░░░░░░░░ [ Open | For you ] ░░░░░░░░░░░░░ │ Side panel (optional) │
│ ░░  ┌──────────────── page ────────────────┐   ┌ comment card ┐    │ Outline | Find |      │
│ ░░  │ header: Q3 planning           p. 1   │   │ (B) Bo  2m   │    │ History | Assistant   │
│ ░⋮⋮ │ # Q3 planning                        │───│ Shorter?     │    │                       │
│ ░░  │ Body text with a [comment anchor]…   │   │ [Reply…]  ✓  │    │                       │
│ ░░  │ • bullet          ▏Anna              │   └──────────────┘    │                       │
│ ░░  └──────────────────────────────────────┘                       │                       │
│ ░░  ┌──────────────── page 2 ──────────────┐                       │                       │
├──────────────────────────────────────────────────────────────────────┴───────────────────────┤
│ 1,234 words                                                                                  │ Word count bar 24 (optional)
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```

Region structure (top to bottom): `EditorHeader` (title row, menubar, toolbar — always shown)
→ `ShadResizablePanelGroup` [ `DocumentCanvas` with the comment margin | `WonkySplitView` side
panel host ] → `StatusBar`, shown only when *Display word count while typing* is on (§11).
Write passes `commentsInPanel: false` to `EditorScaffold` and sets `WriteViewPrefs` as the
shell's `CommentsHost` (suite 07 §2.3): comments and suggestions are shown only in the margin.
Overlays (dialogs, palette, toasts, offline banner, MCP pill) per suite 03 §3.

### 3.2 Title row (48 px)

| Element | Widget | Behaviour |
|---------|--------|-----------|
| App icon | `ShadIconButton` (Write product icon, suite 02 §5) | → Home (`shell.nav.home`). Badge dot when offline changes are pending |
| Title | `DocumentTitleField` | Rename via `shell.drive.rename {uuid, name}` (undoable, domain `drive`). Placeholder "Untitled document". Empty commit reverts. Viewers: plain text |
| Star | `ShadToggle` (star icon) | `shell.drive.setStarred` |
| Move | `ShadIconButton` (folder) | `shell.drive.move` → Move dialog (suite 05) |
| Sync status | `SyncStatusIndicator` | Saved / Saving… / Offline — changes saved on this device / Sync error (click → details) |
| — spacer — | | |
| Presence | `PresenceAvatarStack` | Click avatar → `write.nav.goToCollaborator`; ⋮ → Follow (`write.nav.follow`) |
| Comments | `ShadButton.ghost` (message-square) + badge (open threads) | `shell.comments.togglePanel`: shows/hides the comment margin (comments and suggestions, §10) |
| Version history | `ShadIconButton` (history) | `shell.versions.togglePanel` (panel; panel has "Open full history") |
| Assistant | `ShadIconButton` (sparkles) | `shell.ai.togglePanel` (`Mod+J` outside editor scope); hidden when `!aiOn` |
| Share | `ShadButton` primary (lock / globe / users icon by link state) | `shell.sharing.open` |
| Account | `ShadAvatar` menu | suite 04 |

### 3.3 Menubar row (32 px)
`WonkyMenubar` with menus File, Edit, View, Insert, Format, Tools, Help (full content §7). On
macOS desktop with native menus enabled, the row is hidden and `PlatformMenuBar` is generated
from the same `MenuSpec`. The menubar and the toolbar are always shown (no compact mode or full
screen). Only one menu is open at a time (suite 02 §4.2). Every Write command without an
explicit menu icon gets one from the shared `commandIcons` table
(`lib/commands/command_icons.dart`), so menus show icons consistently (e.g. *Insert › Image ›
Upload from computer*).

### 3.4 Canvas
`DocumentCanvas` = `WonkyScrollArea` containing a `CustomScrollView` whose sliver child is the
`SuperEditor`/`SuperReader` (it wraps itself in a `SliverToBoxAdapter`), plus left gutter (block
handles), right margin (comment cards / suggestion cards, §10) and page chrome underlay. Background
`canvas` token (Pages) or `page` token (Pageless). Details §16.

## 4. Toolbar

`WonkyToolbar` (40 px; compact density 36 px) in the shell's rounded toolbar container (margin
6 px above, 8 px below). Items in order; **Prio** = overflow priority
(1 never overflows, larger numbers overflow first into the trailing `⋯` menu, which preserves
groups). Toggle items show checked state from `isChecked`; all show tooltip = title + `ShadKbd`
shortcut.

| # | Group | Control | Type | Command | Prio | Enabled when / state |
|---|-------|---------|------|---------|------|----------------------|
| 1 | History | Undo | `ToolbarToggleButton` (icon undo-2) — **press-and-hold 500 ms or right-click** opens Undo history popover | `shell.edit.undo` | 1 | stack non-empty; tooltip "Undo Typing (⌘Z)" |
| 2 | | Redo | button (redo-2) | `shell.edit.redo` | 1 | redo stack non-empty |
| 4 | | Print | button (printer) | `write.file.print` | 4 | `copyAllowed` |
| 5 | | Spelling | button (spell-check) (P1) | `write.spell.openDialog` | 6 | spellcheck available |
| 6 | Zoom | Zoom | `ToolbarSelect` (`ShadSelect`): 50…200 %, Fit width, Fit page; editable value | `write.view.zoomSet` / `zoomFit` | 3 | always |
| 7 | Style | Paragraph style | `ToolbarDropdownButton` (min 128 px) — §4.1 | `write.format.blockType` | 1 | `caretText` or code; label = current style or blank when mixed |
| 8 | Inline | Bold | toggle (bold) | `write.format.bold` | 1 | `editable && !inCode` |
| 9 | | Italic | toggle (italic) | `write.format.italic` | 1 | same |
| 10 | | Strikethrough | toggle (strikethrough) | `write.format.strikethrough` | 2 | same |
| 11 | | Inline code | toggle (code) | `write.format.inlineCode` | 2 | same |
| 12 | Insert | Link | toggle (link; checked when caret in link) | `write.link.insert` | 1 | `editable && !inCode` |
| 13 | | Comment | button (message-square-plus) | `shell.comments.create` | 2 | role ≥ commenter, selection or caret in text |
| 14 | | Image | `ToolbarSplitButton` (image ▾): click = Upload, ▾ = Upload from computer / By URL… | `write.insert.image` / `write.insert.imageFromUrl` | 2 | `editable && !inCode` |
| 15 | | Table | `ToolbarDropdownButton` (table) → `WonkyTableSizePicker` + "Custom size…" | `write.insert.table` | 3 | editor & Editing & `!inCode` |
| 16 | | Divider | button (minus) | `write.insert.divider` | 6 | `editable` |
| 17 | Lists | Bulleted list | toggle (list) | `write.list.toggleBulleted` | 1 | `editable`; checked when all selected blocks are bullets |
| 18 | | Numbered list | toggle (list-ordered) | `write.list.toggleNumbered` | 1 | same |
| 19 | | Checklist | toggle (list-checks) | `write.list.toggleChecklist` | 2 | same |
| 20 | | Decrease indent | button (indent-decrease) | `write.list.outdent` | 3 | `inList \|\| inTask` |
| 21 | | Increase indent | button (indent-increase) | `write.list.indent` | 3 | can indent |
| 22 | Blocks | Quote | toggle (quote) | `write.format.blockType {quote}` | 4 | `editable && caretText` |
| 23 | | Code block | toggle (square-code) | `write.format.blockType {codeBlock}` | 4 | `editable` |
| 24 | | Clear formatting | button (remove-formatting) | `write.format.clearFormatting` | 4 | `editable` |
| 25 | Theme | Theme | button (palette) → theme picker popover | `write.theme.openPicker` ([06](06-themes.md)) | 5 | role ≥ editor |
| — | (right, pinned) | `⋯` overflow | dropdown | — | — | shown only when items overflow |
| — | (right, pinned) | Mode switcher | §15 | `write.mode.set` | 1 | per role |

(Item 3, *Search the menus*, and the *Collapse header* chevron were removed with menu search and
compact mode; there is no suggestions toggle — suggestions are in the margin, §10.)

In **Viewing** mode the toolbar shows only items 1–6 (undo/redo disabled) and the mode
switcher. In **Suggesting** mode Table (15) and Theme (25) are disabled, while
Image (14), Divider (16) and all formatting/list/block controls stay enabled and produce
suggestions (see 04 §32.1 for non-suggestable actions; disabled tooltips explain why).

Keyboard: `Alt+F10` (and `Mod+Alt+.`) focuses the toolbar (suite 02 §4.1); arrows move;
Enter/Space activate; Esc returns to the editor.

### 4.1 Paragraph style dropdown
`WonkyDropdownMenu` with `MenuRadioItem`s, each rendered in the active theme's style (font,
weight; size clamped 13–22 px), shortcut on the right:

| Item | Command | Shortcut |
|------|---------|----------|
| Normal text | `write.format.blockType {paragraph}` | ⌘⌥0 / Ctrl+Alt+0 |
| Heading 1 … Heading 6 | `{heading1…6}` | ⌘⌥1…6 / Ctrl+Alt+1…6 |
| Quote | `{quote}` | ⌘⇧. / Ctrl+Shift+. |
| Code block | `{codeBlock}` | ⌘⌥C / Ctrl+Alt+C |
| — separator — | | |
| Customize heading styles… | `write.theme.openEditor {element: headings}` ([06](06-themes.md)) | — |

### 4.2 Undo history popover
`ShadPopover` from the Undo button: last 50 steps (label, relative time, source icon for
MCP/AI); hover highlights the steps that will be undone; click → `shell.edit.undoTo {stepId}`
(suite 08 §3.5).

## 5. Floating toolbars

All built on **`WonkyFloatingToolbar`** (new `wonky_ui` widget, §21): a compact shad-styled
toolbar in a `ShadPopover`-like surface, anchored with `Follower.withAligner` to
`SelectionLayerLinks.expandedSelectionBoundsLink` (selection) or a block's layer link
(image/table/code), flipping below when there's no room above, never covering the caret line.
Focus with `Alt+F10` while visible; Esc hides until the selection changes.

### 5.1 Selection toolbar (text selection)
Appears 250 ms after a mouse/touch selection ends, or 600 ms after a keyboard selection settles;
hidden while dragging, typing, scrolling fast, when a popover/menu is open, or if the user
disabled it (Tools › Preferences › *Show toolbar on selection*, `write.prefs.setSelectionToolbar`).

| Control | Command | Notes |
|---------|---------|-------|
| Paragraph style (compact: "H1 H2 H3 ¶" segmented) | `write.format.blockType` | Hidden when selection spans > 1 block type group |
| Bold / Italic / Strike / Code | `write.format.*` | toggles |
| Link | `write.link.insert` | |
| Comment | `shell.comments.create` | role ≥ commenter |
| ✨ AI ▾ | `write.ai.rewriteSelection {mode}` items: Improve writing, Fix spelling & grammar, Make shorter, Make longer, Change tone ▸ (Professional, Casual, Friendly, Confident), Summarize, Translate ▸ (document languages list), Explain, Custom… (`write.ai.inline`) | `aiOn`, role ≥ editor (commenters: results arrive as suggestions) |
| ⋯ | Copy as Markdown, Clear formatting, Emoji (P1), Search in document (`write.find.open` with query) | |

Commenters / Suggesting mode: same controls; formatting creates suggestions. Viewing mode:
only Comment (if allowed), Copy, Search in document, ✨ Explain/Summarize (read-only AI).

### 5.2 Image toolbar (image selected)
Alt text (`write.image.editAlt`) · Replace ▾ (Upload / By URL) · Download · View full size ·
Comment · Delete (`write.block.delete`). Upload states add Retry/Cancel (`write.image.retryUpload`
/ `cancelUpload`).

### 5.3 Table toolbar (table selected)
Edit table (`write.table.edit`, primary) · Insert row below · Insert column right ·
Copy as TSV · Comment · Delete table.

### 5.4 Code block chrome (caret in / hover over code block)
Not floating: rendered inside the top-right corner of the block's box (04 §15.1) by
`WonkyParagraphComponentBuilder`: language chip (`CodeLanguagePicker`, §9.4: Plain text + the 15
highlighted languages) and Copy button (`write.code.copy`). The chrome shows on hover; it is not
a hit target while hidden, and its hover region is not opaque, so taps in the block reach the
editor.

## 6. Context menus

`ShadContextMenuRegion` over the canvas; content depends on the hit target (right-click moves
the caret unless inside the selection). Sections separated by `MenuSeparator`; disabled items
shown greyed with reason tooltip.

| Hit target | Menu items (in order) |
|------------|----------------------|
| **Spelling error** (prepended section) | up to 5 suggestions (`write.spell.replace`) · Ignore (`write.spell.ignore`) · Add to dictionary (`write.spell.addToDictionary`) · ─ |
| **Suggestion** (prepended, Editors) | Accept suggestion (`write.suggestions.accept {id}`) · Reject suggestion (`write.suggestions.reject {id}`) · ─ |
| **Text, selection** | Cut · Copy · Copy as ▸ (Markdown, Plain text, HTML) · Paste · Paste without formatting · ─ · Comment (⌘⌥M) · Insert link (⌘K) · ✨ AI ▸ (same as §5.1) · ─ · Bold/Italic/Strike/Code (`MenuCheckItem`s) · Clear formatting · Turn into ▸ · ─ · Search document for "…" (`write.find.open {query}`) |
| **Text, caret only** | Paste · Paste without formatting · ─ · Insert link · Comment · ─ · Turn into ▸ · Insert ▸ (Image, Table, Divider, Code block, Emoji, Special characters) · ─ · Select all |
| **Link** (prepended) | Open link (`write.link.open`) · Copy link (`write.link.copy`) · Edit link (`write.link.edit`) · Remove link (`write.link.remove`) · ─ |
| **Mention** | Copy email · Remove mention (`write.block.delete` range) · ─ + text items |
| **Image** | Alt text… · Replace ▸ · Download · Copy image (P1) · View full size · ─ · Comment · Cut · Copy · Delete · ─ · Move up / Move down |
| **Table** | Edit table · Insert row above / below · Insert column left / right · Delete row / column (submenu by hovered cell when determinable, else first/last) · ─ · Copy (Markdown) · Copy as TSV · Comment · Delete table |
| **Code block** | Language ▸ (recent + "More…") · Copy code · Exit code block · ─ · standard text items (Cut/Copy/Paste) |
| **Divider** | Cut · Copy · Delete · Move up / down |
| **Comment highlight** (prepended) | Open comment (`shell.comments.activate {threadUuid}`) · ─ |
| **Block handle** (left-click/right-click) | Block menu (§8.2) |
| **Page header/footer area** (Pages) | Edit header & footer… (`write.doc.pageSetup {tab: headerFooter}`) · Page setup… |
| **Viewing mode** | Copy · Copy as ▸ · Comment (if allowed) · Search document · Open link (on links) |

Keyboard: Shift+F10 / context-menu key opens the menu for the caret/selection target.

## 7. Menubar

Each table: **Item** · **Command** · **macOS** · **Win/Linux** · **Enabled when**. Submenus
are indented with `▸`. Items marked *(shell)* are the shared shell items (suite 03 §3.2) with
Write behaviour noted.

### 7.1 File

| Item | Command | macOS | Win/Linux | Enabled when |
|------|---------|-------|-----------|--------------|
| New ▸ Document *(shell)* | `shell.file.new {kind: document}` | — | — (⌘⌥N in Drive only) | `online` or offline-capable |
| New ▸ Spreadsheet *(shell)* | `shell.file.new {kind: spreadsheet}` | — | — | (navigates to Sheets) |
| New ▸ From template… *(shell)* | `shell.file.newFromTemplate` | — | — | always |
| Open… *(shell)* | `shell.file.open` (quick switcher) | ⌘O | Ctrl+O | always |
| Import into new document… *(shell)* | `shell.file.import {kind: document}` | — | — | `online` |
| Insert from file… | `write.insert.fromFile` (P1; imports MD/TXT/HTML/DOCX at caret, 04 §24) | — | — | `editable` |
| Make a copy… *(shell)* | `shell.drive.copy` | — | — | role ≥ viewer & `copyAllowed` |
| ─ | | | | |
| Share ▸ Share with others *(shell)* | `shell.sharing.open` | — | — | always (role decides dialog content) |
| Share ▸ Copy link *(shell)* | `shell.sharing.copyLink` | — | — | always |
| Download ▸ Markdown (.md) | `write.file.download {format: md}` | — | — | `copyAllowed` |
| Download ▸ Markdown with images (.zip) | `{format: mdZip}` | — | — | same |
| Download ▸ PDF (.pdf) | `{format: pdf}` | — | — | same |
| Download ▸ Web page (.html) | `{format: html}` | — | — | same |
| Download ▸ Plain text (.txt) | `{format: txt}` | — | — | same |
| Download ▸ Word (.docx) (P1) | `{format: docx}` | — | — | same |
| Download ▸ OpenDocument (.odt) (P1) | `{format: odt}` | — | — | same |
| Download ▸ Rich Text (.rtf) (P1) | `{format: rtf}` | — | — | same |
| Download ▸ EPUB (.epub) (P1) | `{format: epub}` | — | — | same |
| Download ▸ Options… | `write.file.exportOptions` (dialog: suggestions accepted/original, theme light/dark, include comments as footnotes (P2)) — [07](07-import-export-print.md) | — | — | same |
| ─ | | | | |
| Rename *(shell)* | `shell.drive.rename` (focuses `DocumentTitleField`) | — | — | role ≥ editor |
| Move… *(shell)* | `shell.drive.move` | — | — | role ≥ editor |
| Add shortcut to Drive *(shell)* | `shell.drive.addShortcut` | — | — | shared item |
| Move to trash *(shell)* | `shell.drive.trash` | — | — | role ≥ editor |
| ─ | | | | |
| Version history ▸ Name current version *(shell)* | `shell.versions.nameCurrent` | — | — | role ≥ editor, `online` |
| Version history ▸ See version history *(shell)* | `shell.versions.open` (route `/d/:uuid/history`) | ⌘⌥⇧H | Ctrl+Alt+Shift+H | `online` |
| Make available offline *(shell, check)* | `shell.drive.togglePinnedOffline` | — | — | always |
| Details *(shell)* | `write.doc.properties` (dialog §12.8) | — | — | always |
| ─ | | | | |
| Language… | `write.doc.languageDialog` → `write.doc.setLanguage` | — | — | role ≥ editor |
| Page setup… | `write.doc.pageSetup` (dialog §12.6) | — | — | role ≥ editor (viewers: read-only view) |
| Print *(shell)* | `write.file.print` (→ `/d/:uuid/print`) | ⌘P | Ctrl+P | `copyAllowed` |

### 7.2 Edit

| Item | Command | macOS | Win/Linux | Enabled when |
|------|---------|-------|-----------|--------------|
| Undo *label* | `shell.edit.undo` | ⌘Z | Ctrl+Z | undo stack non-empty |
| Redo *label* | `shell.edit.redo` | ⌘⇧Z | Ctrl+Y, Ctrl+Shift+Z | redo stack non-empty |
| Undo history… | `shell.edit.undoHistory` | — | — | stack non-empty |
| ─ | | | | |
| Cut | `write.edit.cut` | ⌘X | Ctrl+X | `selText && editable && copyAllowed` |
| Copy | `write.edit.copy` | ⌘C | Ctrl+C | selection & `copyAllowed` |
| Copy as ▸ Markdown / Plain text / HTML | `write.edit.copyAsMarkdown` / `copyAsPlainText` / `copyAsHtml` | — | — | same |
| Paste | `write.edit.paste` | ⌘V | Ctrl+V | `editable` |
| Paste without formatting | `write.edit.pasteWithoutFormatting` | ⌘⇧V | Ctrl+Shift+V | `editable` |
| Paste special ▸ Paste as Markdown (P1) | `write.edit.pasteAsMarkdown` | — | — | `editable` |
| ─ | | | | |
| Select all | `write.edit.selectAll` | ⌘A | Ctrl+A | always |
| Delete | `write.edit.delete` | ⌫/⌦ | Del | `selText && editable` |
| ─ | | | | |
| Find | `write.find.open` | ⌘F | Ctrl+F | always |
| Find and replace | `write.find.openReplace` | ⌘⇧H | Ctrl+H | always (replace row disabled unless `editable`) |
| Find next / previous | `write.find.next` / `previous` | ⌘G / ⌘⇧G | Ctrl+G, F3 / Ctrl+Shift+G, Shift+F3 | query set |
| Go to heading… | `write.nav.goToHeading` | ⌘⌥G | Ctrl+Alt+G | outline non-empty |

### 7.3 View

| Item | Command | macOS | Win/Linux | Enabled when |
|------|---------|-------|-----------|--------------|
| Mode ▸ Editing (radio) | `write.mode.set {editing}` | ⌘⌥⇧Z | Ctrl+Alt+Shift+Z | role ≥ editor |
| Mode ▸ Suggesting (radio) | `write.mode.set {suggesting}` | ⌘⌥⇧X | Ctrl+Alt+Shift+X | role ≥ commenter |
| Mode ▸ Viewing (radio) | `write.mode.set {viewing}` | ⌘⌥⇧C | Ctrl+Alt+Shift+C | always |
| Page layout ▸ Pages / Pageless (radio) | `write.doc.setLayout {pages\|pageless}` | — | — | role ≥ editor (others: disabled, shows current) |
| Suggestions ▸ Show suggestions / Preview accepted / Preview original (radio) | `write.view.suggestionPreview {mode}` | — | — | always |
| ─ | | | | |
| Zoom ▸ Zoom in / Zoom out | `write.view.zoomIn` / `zoomOut` | ⌘⌥= / ⌘⌥- (desktop also ⌘= / ⌘-) | Ctrl+Alt+= / Ctrl+Alt+- (desktop also Ctrl+= / Ctrl+-) | not at bound |
| Zoom ▸ 50 % … 200 % (radio) | `write.view.zoomSet {percent}` | — | — | always |
| Zoom ▸ Fit width / Fit page | `write.view.zoomFit {width\|page}` | — | — | Fit page: Pages mode |
| Zoom ▸ Reset to 100 % | `write.view.zoomReset` | desktop ⌘0 | desktop Ctrl+0 | zoom ≠ 100 |
| ─ | | | | |
| Panels ▸ Outline (check) | `write.view.toggleOutline` | ⌘⌥⇧O | Ctrl+Alt+Shift+O | always |
| Panels ▸ Find and replace (check) | `write.find.open` / `close` | ⌘F | Ctrl+F | always |
| Panels ▸ Version history (check) | `shell.versions.togglePanel` | — | — | `online` |
| Panels ▸ Assistant (check) | `shell.ai.togglePanel` | ⌘J (outside editor) | Ctrl+J | `aiOn` |
| Comments and suggestions (check) | `shell.comments.togglePanel` (shows/hides the comment margin, §10) | — | — | role allows seeing comments |
| App theme ▸ System / Light / Dark (radio) *(shell)* | `shell.appearance.setTheme {mode}` | — | — | always |

There is no *View › Show* submenu, compact mode, full screen, focus mode, typewriter scrolling
or theme preview: the chrome is always shown and collaborator cursors are always drawn. The word
count bar is turned on in the word count dialog (§12.5), the selection toolbar in *Tools ›
Preferences*, spelling underlines in *Tools › Spelling*.

### 7.4 Insert

| Item | Command | macOS | Win/Linux | Enabled when |
|------|---------|-------|-----------|--------------|
| Image ▸ Upload from computer… | `write.insert.image` | — | — | `editable && !inCode` |
| Image ▸ By URL… | `write.insert.imageFromUrl` | — | — | same |
| Table ▸ *(custom: `WonkyTableSizePicker`)* | `write.insert.table {rows, cols}` | — | — | role ≥ editor, Editing, `!inCode` |
| Table ▸ Custom size… | `write.insert.tableDialog` (dialog §12.3) | — | — | same |
| Divider (horizontal line) | `write.insert.divider` | — | — | `editable && !inCode` |
| Code block | `write.format.blockType {codeBlock}` | ⌘⌥C | Ctrl+Alt+C | `editable` |
| Quote | `write.format.blockType {quote}` | ⌘⇧. | Ctrl+Shift+. | `editable && caretText` |
| Checklist | `write.list.toggleChecklist` | ⌘⇧9 | Ctrl+Shift+9 | `editable` |
| ─ | | | | |
| Link… | `write.link.insert` | ⌘K | Ctrl+K | `editable && !inCode` |
| Mention a person | `write.insert.mentionTrigger` (inserts `@` + opens picker) | — | — | `editable && !inCode` |
| Emoji… (P1) | `write.insert.emoji` | — | — | `editable` |
| Special characters… (P1) | `write.insert.specialCharacter` | — | — | `editable` |
| Date (P2) | `write.insert.date` | — | — | `editable` |
| Table of contents (P2) | `write.insert.tableOfContents` | — | — | role ≥ editor |
| ─ | | | | |
| Comment | `shell.comments.create` | ⌘⌥M | Ctrl+Alt+M | role ≥ commenter, selection/caret in text |
| From file… (P1) | `write.insert.fromFile` | — | — | `editable` |

### 7.5 Format

| Item | Command | macOS | Win/Linux | Enabled when |
|------|---------|-------|-----------|--------------|
| Text ▸ Bold (check) | `write.format.bold` | ⌘B | Ctrl+B | `editable && !inCode` |
| Text ▸ Italic (check) | `write.format.italic` | ⌘I | Ctrl+I | same |
| Text ▸ Strikethrough (check) | `write.format.strikethrough` | ⌘⇧X | Ctrl+Shift+X | same |
| Text ▸ Code (check) | `write.format.inlineCode` | ⌘E | Ctrl+E | same |
| Paragraph styles ▸ Normal text, Heading 1–6, Quote, Code block (radio, theme-rendered as §4.1) | `write.format.blockType {type}` | ⌘⌥0–6, ⌘⇧., ⌘⌥C | Ctrl+Alt+0–6, Ctrl+Shift+., Ctrl+Alt+C | `editable` |
| Paragraph styles ▸ Customize styles… | `write.theme.openEditor {element: body}` | — | — | role ≥ editor |
| Bullets & numbering ▸ Bulleted list / Numbered list / Checklist (check) | `write.list.toggle*` | ⌘⇧8/7/9 | Ctrl+Shift+8/7/9 | `editable` |
| Bullets & numbering ▸ Increase indent / Decrease indent | `write.list.indent` / `outdent` | Tab / ⇧Tab | Tab / Shift+Tab | list/task selected |
| Bullets & numbering ▸ Mark as done / not done | `write.list.toggleChecked` | ⌘Enter | Ctrl+Enter | `inTask` |
| Link ▸ Insert/Edit link… | `write.link.insert` / `edit` | ⌘K | Ctrl+K | `editable` |
| Link ▸ Remove link | `write.link.remove` | — | — | `onLink && editable` |
| Clear formatting | `write.format.clearFormatting` | ⌘\ | Ctrl+\ | `editable` |
| ─ | | | | |
| Table ▸ Edit table… | `write.table.edit` | Enter (table selected) | Enter | `inTable`, role ≥ editor, Editing |
| Table ▸ Insert row above / below | `write.table.insertRow {position}` | — | — | same |
| Table ▸ Insert column left / right | `write.table.insertColumn {position}` | — | — | same |
| Table ▸ Delete row / Delete column | `write.table.deleteRow` / `deleteColumn` | — | — | same (body rows only for row) |
| Table ▸ Column alignment ▸ None / Left / Center / Right | `write.table.setColumnAlignment` | — | — | same |
| Table ▸ Delete table | `write.table.delete` | — | — | same |
| Image ▸ Alt text… / Replace ▸ / Download | `write.image.editAlt` / `replace` / `download` | — | — | `onImage` |
| Code block ▸ Language… / Copy code / Exit code block | `write.code.setLanguage` (picker) / `copy` / `exit` | — / — / ⌘Enter | — / — / Ctrl+Enter | `inCode` |
| ─ | | | | |
| Theme ▸ *built-in themes* (radio) | `write.theme.apply {themeId}` | — | — | role ≥ editor |
| Theme ▸ Use my default theme (radio) | `write.theme.useDefault` | — | — | role ≥ editor |
| Theme ▸ More themes… | `write.theme.openPicker` (grid incl. my themes, *New theme*, *Customize…*) | — | — | always (viewers: read-only grid) |
| Theme ▸ Customize theme… | `write.theme.openEditor` | — | — | always |
| Theme ▸ Manage themes… | `write.theme.openManager` | — | — | always |
| Theme ▸ Save as my default theme | `write.theme.setUserDefault` | — | — | always |

### 7.6 Tools

| Item | Command | macOS | Win/Linux | Enabled when |
|------|---------|-------|-----------|--------------|
| Spelling ▸ Check spelling… (P1) | `write.spell.openDialog` | ⌘⌥X | Ctrl+Alt+X | dictionary available |
| Spelling ▸ Underline errors (check) | `write.spell.toggle` | — | — | same |
| Spelling ▸ Next error | `write.spell.nextError` | ⌘' | Ctrl+' | errors exist |
| Spelling ▸ Personal dictionary… | `write.spell.personalDictionary` (dialog §12.11) | — | — | always |
| Word count | `write.tools.wordCount` | ⌘⇧C | Ctrl+Shift+C | always |
| Language… | `write.doc.languageDialog` | — | — | role ≥ editor |
| ─ | | | | |
| Assistant *(shell)* | `shell.ai.togglePanel` | ⌘J | Ctrl+J | `aiOn` |
| AI ▸ Summarize document | `write.ai.summarizeDocument` | — | — | `aiOn` |
| AI ▸ Generate outline | `write.ai.generateOutline` | — | — | `aiOn`, role ≥ editor |
| AI ▸ Proofread document | `write.ai.proofread` | — | — | `aiOn` |
| ─ | | | | |
| Preferences ▸ Markdown shortcuts (check) | `write.prefs.setMarkdownShortcuts` | — | — | always |
| Preferences ▸ Smart quotes and dashes (check, P1) | `write.prefs.setSmartTypography` | — | — | always |
| Preferences ▸ Auto-pair brackets (check, P1) | `write.prefs.setAutoPair` | — | — | always |
| Preferences ▸ Automatically detect links (check) | `write.prefs.setAutolink` | — | — | always |
| Preferences ▸ Copy plain text as Markdown (check) | `write.prefs.setCopyAsMarkdown` | — | — | always |
| Preferences ▸ Show toolbar on selection (check) | `write.prefs.setSelectionToolbar` | — | — | always |
| Preferences ▸ All preferences… *(shell)* | `shell.settings.open {section: write}` | ⌘, (desktop) | Ctrl+, (desktop) | always |
| Accessibility ▸ Screen reader support (check) | `write.a11y.toggleScreenReaderMode` | ⌘⌥Z | Ctrl+Alt+Z | always |
| Accessibility ▸ Announce formatting | `write.a11y.announceFormatting` | ⌘⌥A | Ctrl+Alt+A | screen-reader mode |
| Accessibility ▸ Settings… *(shell)* | `shell.settings.open {section: appearance}` | — | — | always |
| Keyboard shortcuts *(shell)* | `shell.help.shortcuts` | ⌘/ | Ctrl+/ | always |

### 7.7 Help *(shell + Write items)*
Keyboard shortcuts (⌘/ / Ctrl+/) · **Markdown guide** (`write.help.markdownGuide`, dialog) · ─ ·
Report a problem (`shell.help.feedback`) · What's new (`shell.help.whatsNew`) · About
(`shell.help.about`). (No help center, no menu search; the Markdown guide is only in Help.)

### 7.8 Native macOS menu mapping
The `MenuSpec` additionally yields: app menu (About, Preferences ⌘,, Hide ⌘H, Quit ⌘Q — OS
handled), Window menu (Minimize, Zoom — OS). Edit menu items use native selectors only where
Flutter requires; all others dispatch commands.

## 8. Slash menu and block menu (UI)

### 8.1 Slash menu (`SlashMenu`, app widget)
Popover (min 280 / max 360 px wide, max 400 px tall) anchored at the `/` tag rect: search
query echo row ("/hea"), grouped list (`MenuLabel` group headers: Basic blocks, Media, Insert,
AI), rows = icon (20 px box) + title + muted description ("Big section heading") + `ShadKbd`
shortcut; highlighted row uses `accent`. Footer hint "↑↓ to navigate · ↵ to select · esc to
dismiss". Empty state "No results" row (and space closes). Items/behaviour: 04 §21.

### 8.2 Block menu (`BlockMenu`, app widget)
`WonkyDropdownMenu` opened from the ⋮⋮ handle: header shows block type + mini preview; items per
04 §22.2: Turn into ▸ (icons per type, current type checked), Duplicate, Copy link to heading,
Copy as Markdown, Comment, ─, Move up (⌃⇧↑ / Alt+Shift+↑), Move down, ─, type-specific items,
─, Delete (destructive style). Keyboard type-ahead enabled.

## 9. Popovers

All popovers: `ShadPopover`-based, 150 ms fade/scale (none with reduce motion), Esc closes and
returns focus to the editor, implement `McpDescribableDialog` where they contain fields.

### 9.1 Link editor (`LinkEditorPopover`) — 04 §11.2
Width 360 px. Fields: **Text** (`ShadInput`, hidden for multi-block selections), **Link**
(`ShadInput` with leading link icon; results list below in sections "Headings in this document",
"Documents", "Link to a heading in another document…" (P1); each result row: icon, title,
secondary path/heading level). Validation message inline (destructive text). Buttons: **Apply**
(primary, disabled while invalid), **Remove link** (ghost, edit mode only). Enter = Apply,
↑↓ navigate results, Tab cycles fields. MCP dialog id `write.popover.link`.

### 9.2 Link hover card (`LinkHoverCard` on `WonkyHoverCard`) — 04 §11.5
Width 320 px, below the link: icon + title/domain, URL (truncated middle, monospace small),
icon buttons Open ↗, Copy, Edit ✎, Remove ⛓̸ (last two only if `editable`). Internal links show
doc title, path, and heading; "You don't have access" with *Request access* if forbidden.

### 9.3 Mention picker (`MentionPicker`) — 04 §19
Width 300 px, max 8 rows: avatar 24, name, email (muted), role badge (`ShadBadge.outline`);
section header "People in this document" / "Other people". Keyboard ↑↓ Enter Tab Esc. Loading
row with `ShadSpinner`; offline → only cached people with note "Offline — showing recent people".

### 9.4 Code language picker (`CodeLanguagePicker`)
`ShadSelect.withSearch` anchored to the chip: search field, *Plain text*, "Recent" group, "All
languages" group (the highlighted languages of 04 §15.4, display names); selected checked. Applies `write.code.setLanguage`.

### 9.5 Emoji picker (`WonkyEmojiPicker`, P1)
360×360 px: search, category tabs (icons), grid 8 columns (32 px cells), skin-tone selector,
footer preview with name. Arrow navigation, Enter inserts and closes (Shift+Enter inserts and
keeps open).

### 9.6 Table size picker (`WonkyTableSizePicker`, suite 02 §4.10)
Grid 10×10 growing to 20×20 on hover; label "4 × 3"; keyboard arrows + Enter; "Custom size…"
item below.

### 9.7 Theme picker popover
Owned by [06](06-themes.md): grid of theme cards (light+dark preview thumbnails), *Customize…*,
*Manage themes…*.

## 10. Side panels and the comment margin

Hosted by `WonkySplitView` (suite 02 §4.5) on the right; one active panel, shown or hidden (no
collapsed rail); the header always shows every panel as an icon tab — Outline, Find, History,
Assistant; width persisted per panel; `Mod+Alt+Shift+1…5` switches to the n-th tab;
Esc (with focus in panel) closes; below `md` panels open as `ShadSheet` from the right (90 %
width, max 420). MCP panel ids in parentheses. File › Details (`details`) also opens in the host
but is not a tab (`showAsTab: false`). There is **no comments panel and no suggestions panel**:
comments and suggestions are shown only in the comment margin (§10.2).

| Panel | id | Default / min width | Toggle |
|-------|----|---------------------|--------|
| Outline | `outline` | 280 / 220 | `write.view.toggleOutline` |
| Find and replace | `find` | 340 / 300 | `write.find.open` |
| Version history | `history` | 320 / 280 | `shell.versions.togglePanel` |
| Assistant | `assistant` | 400 / 360 (max 640) | `shell.ai.togglePanel` |

### 10.1 Outline panel (`OutlinePanel`)
- Header: title "Outline", ⋮ (Collapse all, Expand all, Show levels ▸ 1–6 (`write.outline.setMaxLevel`,
  view pref), Close).
- Body: `WonkyTreeView` of headings (indent 12 px per level relative to the minimum level
  present), text truncated with ellipsis, tooltip with full text; current heading highlighted
  (`accent` background + `primary` left bar 2 px); click → `write.nav.goToHeading {nodeId}`;
  keyboard: arrows move, Enter navigates, ←/→ collapse/expand; drag-to-reorder sections (P2).
- Footer: "Summarize with AI" ghost button (`write.ai.summarizeDocument`, `aiOn`).
- Empty state (§14).

### 10.2 Comment margin (comments and suggestions)
The only place comments and suggestions are shown (`CommentMargin`, layout in
[08](08-comments-suggestions-history.md) §3.2). `WriteViewPrefs` is the shell's `CommentsHost`
(suite 07 §2.3): the title-row 💬 button and *View › Comments and suggestions*
(`shell.comments.togglePanel`) show/hide the margin (local pref `write.view.commentMargin`,
default on); `shell.comments.create` and `shell.comments.activate` show it.
- **Filter** at the top of the margin: `CommentsFilterTabs` **Open** (default) / **For you**
  (open threads that mention or are assigned to me); pending suggestions show with *Open*.
  Resolved threads are not shown; there is no search.
- **Cards**: thread cards (`shell.comments.activate` on click) and suggestion cards with
  Accept/Reject (Editors) or Withdraw (author) plus the suggestion thread's replies and a reply
  box (08 §2.5). *Accept all / Reject all* stay available as commands
  (`write.suggestions.acceptAll` / `rejectAll`: palette, MCP).
- **New comment**: the composer is a card in the margin at its anchor.
- **Placement**: beside the page when the page (at the current zoom) still fits next to the
  margin column with gutters; otherwise the margin overlays the right edge of the canvas. Hidden
  below 600 px canvas width. Shown only when there are cards (anchored open threads, pending
  suggestions or a draft).

### 10.3 Version history panel
Compact list of versions (named first toggle "Only named versions"), each row: name or
timestamp, author avatars, ⋮ (Name this version, Restore, Make a copy, Download as ▸). Click a
row → full-screen route `/d/:uuid/history?version=<id>`. Header button **Open full history**.
Details in [08](08-comments-suggestions-history.md).

### 10.4 Assistant panel
Shared shell `AssistantPanel` (suite 10 §3) with Write context chips ("Selection: 2
paragraphs", "Heading: Budget"), quick prompts (Summarize, Improve selection, Generate outline,
Continue writing), apply-mode toggle (*Edit directly* / *Suggest*). Tool chips *Show* jump to
and flash-highlight the changed range in the editor (1.5 s `findMatchActive` pulse).

### 10.5 Find and replace panel (`FindPanel`) — 04 §25
```
┌ Find and replace ─────────────── ✕ ┐
│ [🔍 colour            ] 3 of 42 ↑ ↓ │
│ [Aa] [ab] [.*]  Search in: Doc ▾     │
│ [⇄  color             ]              │
│ [Replace]  [Replace all]             │
│ ── Results ──────────────────────── │
│ ¶ "…the colour of the…"   p.2        │  (P1 mini-list, click = jump)
└──────────────────────────────────────┘
```
- Find field: `WonkySearchField` (new `wonky_ui`, §21) with match count, prev/next buttons;
  option toggles `ShadToggle` small: Match case (`Aa`), Whole word (`ab` with underline),
  Regex (`.*`); invalid regex → destructive helper text.
- Replace row visible when opened via replace or toggled with the ⇄ chevron; disabled with
  tooltip when not `editable`.
- Buttons: Replace (`write.find.replace`), Replace all (`write.find.replaceAll`, shows toast
  "Replaced 42 occurrences · Undo").
- Keyboard: Enter / Shift+Enter next/prev, Mod+Alt+Enter replace all, Esc close, Tab order
  find → options → replace → buttons.

## 11. Status bar (word count)

`StatusBar` (24 px, suite 02 §4.13), shown only while **Display word count while typing** is on
(checkbox in the word count dialog §12.5, `write.view.toggleWordCount`, per-user local pref,
default **off**). It contains only the word count:

| Slot | Content | Interaction |
|------|---------|-------------|
| Left | Word count "1,234 words" / "56 of 1,234 words" | Click → word count dialog; tooltip shows characters & reading time |

Layout, zoom, mode, sync and upload status are not in the status bar: layout and zoom are in
the View menu and toolbar, the mode in the toolbar's mode switcher, the sync status in the title
row, the app theme in *View › App theme*.

## 12. Dialogs

All dialogs are `ShadDialog` built through `WonkyDialogSpec` (suite 09 §6.2) unless noted
custom (`McpDescribableDialog`); Esc = Cancel; Enter = primary when valid; focus first field;
below `md` they become full-height sheets. **Dialog id** is the MCP id.

| § | Dialog (id) | Opened by | Fields | Buttons / result |
|---|-------------|-----------|--------|------------------|
| 12.1 | **Insert image by URL** (`write.dialog.imageUrl`) | `write.insert.imageFromUrl` | Image URL (`ShadInput`, https only, validated on blur; live preview 240 px tall with spinner/error "Couldn't load image"), Alt text (`ShadTextarea`, 0–500, helper "Describe the image for people who can't see it") | **Insert** (enabled when preview loaded or user confirms "Insert anyway") · Cancel → `write.insert.imageFromUrl {url, alt}` |
| 12.2 | **Image alt text** (`write.dialog.imageAlt`) | `write.image.editAlt` | Alt text (textarea, counter), Title (input, optional, "Shown as a tooltip") | **Save** · Cancel → `write.image.setAlt` |
| 12.3 | **Custom table size** (`write.dialog.tableSize`) | Insert › Table › Custom size… | Rows (`WonkyNumberStepper` 2–2000, default 3, "including header row"), Columns (1–64, default 3) | **Insert** · Cancel → `write.insert.table` |
| 12.4 | **Special characters** (`write.dialog.specialChars`, custom, P1) | `write.insert.specialCharacter` | Category `ShadSelect`, search input, character grid (virtualized, 40 px cells), recent row, preview pane (glyph 64 px, name, U+code) | Click/Enter inserts (stays open) · **Close** |
| 12.5 | **Word count** (`write.dialog.wordCount`) | `write.tools.wordCount` | Read-only table: rows Pages, Words, Characters, Characters excluding spaces, Paragraphs, Reading time; columns Document / Selection (when selection); checkbox "Display word count while typing" (`write.view.toggleWordCount`) | **OK** |
| 12.6 | **Page setup** (`write.dialog.pageSetup`) | `write.doc.pageSetup` | Tabs: **Page** — Layout (radio Pages/Pageless), Paper size (`ShadSelect`: Letter, Legal, Tabloid, A3, A4, A5, B5, Executive, Statement, Custom → width/height), Orientation (Portrait/Landscape toggle group), Margins top/bottom/left/right (`WonkyNumberStepper`, unit select mm/in, presets Normal/Narrow/Wide); **Header & footer** — Header left/center/right inputs, Footer left/center/right inputs, "Insert ▾" token menu ({page}, {pages}, {title}, {date}, {author}), "Different first page" checkbox (+ first-page header/footer fields), "Show page numbers" quick preset; live thumbnail preview (light/dark aware). When a smaller margin (e.g. the Narrow preset) would leave the header/footer distance outside the margin, the distance moves inside it (half the margin). Validation errors are shown inline in the dialog and disable OK | **OK** (one undoable meta change `write.doc.setPageSetup {pageSetup}` — its args schema accepts the `PageSetup` JSON), **Set as default** (user default, `write.prefs.setDefaultPageSetup`), Cancel. Model & validation in [07](07-import-export-print.md) |
| 12.7 | **Document language** (`write.dialog.language`) | File/Tools › Language… | Language `ShadSelect.withSearch` (BCP-47 list with native names; dictionaries available marked ✓) | **OK** → `write.doc.setLanguage` · Cancel |
| 12.8 | **Document details** (`write.dialog.properties`) | File › Details | Read-only: title, location (breadcrumb, click → drive), owner, created, modified (by), size, word count, language, theme, revision; **Front matter** (`ShadTextarea` monospace YAML, validated YAML syntax; editors only) | **Save** (if front matter changed → `write.doc.setFrontMatter`, undoable meta) · Close |
| 12.9 | **Insert file contents** (`write.dialog.insertFile`, P1) | drop / Insert › From file… | File name, detected format, import warnings preview list | **Insert** · Cancel |
| 12.10 | **Check spelling** (`write.dialog.spelling`, custom, P1) | `write.spell.openDialog` | Context sentence with error highlighted, editable "Change to" field, suggestions list | **Change**, **Change all**, **Ignore**, **Ignore all**, **Add to dictionary**, **Close**; "No more errors" final state |
| 12.11 | **Personal dictionary** (`write.dialog.dictionary`) | Tools › Spelling › Personal dictionary… | Search, word list with remove (×), add field | **Done** (each add/remove = `write.spell.addToDictionary` / `removeFromDictionary`) |
| 12.12 | *(removed: Markdown source dialog, `write.tools.viewMarkdown`; use Edit › Copy as ▸ Markdown or Download ▸ Markdown)* | | | |
| 12.13 | **Discard table changes?** (`write.dialog.discardTable`, alert) | Esc in dirty table editor | message | **Discard** (destructive) · Keep editing |
| 12.14 | **Table editor** (`write.dialog.tableEditor`, custom) | `write.table.edit` | 04 §18.4 (popover ≥ md, dialog < md) | **Done** · Cancel |
| 12.15 | **Lightbox** (custom overlay, `write.dialog.lightbox`) | `write.image.preview` | image, zoom controls, alt caption | Close (Esc), Download |
| 12.16 | **Export options** (`write.dialog.exportOptions`) | Download ▸ Options… | [07](07-import-export-print.md) | |
| 12.17 | **Keep offline changes** (`write.dialog.rebaseTooOld`) | `RebaseTooOld` | message (suite 12 §1.2) | **Save as a copy**, **Download as Markdown**, **Discard** (destructive, confirm) |
| 12.18 | **Document reloaded** (toast, not dialog) | `OpRejected` / integrity mismatch | "We had to reload this document. Your recent changes are kept." | Details (opens sync log) |

Shell dialogs used from Write (specified elsewhere): Share (suite 06), Move / Rename / Make a
copy (suite 05), Name version / Restore confirm (suite 07, [08](08-comments-suggestions-history.md)),
External link confirm (suite 03), Keyboard shortcuts (suite 08), Theme editor (06), Command
palette (suite 08; Write providers: commands, "#" headings, "@" people → mention insert,
"Go to document").

## 13. Document settings

### 13.1 Document-level settings
There is no document settings dialog (*File › Settings…* / `write.doc.settings` was removed).
Each setting has its own entry point: language (File › Language…, §12.7), layout (View › Page
layout), theme (Format › Theme, [06](06-themes.md)), page setup (File › Page setup…, §12.6),
front matter (File › Details, §12.8), offline (File › Make available offline).

Document-level settings (language, layout, theme, page setup, front matter) are **meta**
changes: LWW via `updateMeta`, undoable in domain `write.meta`, broadcast as `MetaChanged`
(03 §6) — collaborators see a toast "Bo changed the page setup" (once per 30 s). Only editors
can change them; others see read-only values.

### 13.2 Per-user view preferences (local, not undoable, not synced)
Zoom, mode, panel visibility/width, word count bar shown (default off), comment margin shown
(default on), selection toolbar, suggestion preview mode — persisted per user (and per document
for zoom/mode) in local prefs. Collaborator cursors are always shown.

### 13.3 Settings › Write (user defaults, suite 04 §4.5)
Default theme, default page setup (and default layout), spellcheck on, personal dictionary,
Markdown shortcuts, smart typography, auto-pair, autolink, copy-as-Markdown, selection toolbar,
default export format, default view mode for shared docs (Editing/Suggesting/Viewing). Each is
a `write.prefs.*` / `shell.settings.*` command.

## 14. Empty, loading and error states

| State | Presentation |
|-------|--------------|
| **New blank document** | Title field focused with placeholder "Untitled document"; on Enter focus moves to the body; body shows hint (`WonkyHintComponentBuilder`) "Type **/** for commands, **@** to mention, or just start writing" in `muted` color |
| **Loading (no cache)** | Header rendered immediately (title from drive item), toolbar disabled, canvas shows `LoadingShimmer` document-page skeleton (title bar + 8 text lines + image block) in page card; after 5 s "Still loading… (large document)" with progress if known |
| **Loading (cached)** | Render cached snapshot instantly (read-only for ≤ 300 ms until `Init`), `SyncStatusIndicator` "Connecting…" |
| **Offline, doc not cached** | `ShadEmpty` with offline illustration: "This document isn't available offline" + *Go back* + hint "Use *Make available offline* next time" |
| **Offline, cached** | Normal editor + offline banner (suite 03 §4); remote cursors hidden; presence shows "Offline" |
| **Trashed document** | Read-only (Viewing) + banner "This document is in the trash." **Restore** (`shell.drive.restore`) |
| **No access / not found** | Shell page (suite 03 §2) |
| **Outline empty** | Icon list-tree 24 px, "Headings you add to the document will appear here", button *Learn about headings* (help) |
| **No comments or suggestions** | The comment margin is not shown (§10.2) |
| **Find: no results** | "No results for 'xyz'" muted; with regex error: destructive "Invalid regular expression" |
| **Version history: only current** | "No earlier versions yet. Versions are saved automatically as you edit." + *Name current version* |
| **Assistant empty** | Shell empty state + Write quick prompts |
| **Image failed / unavailable** | 04 §17.3 placeholders |
| **Fatal editor error** | Error card in canvas (suite 03 §4): "Something went wrong displaying this document" + **Reload document** + **Copy error details**; pending outbox preserved |
| **Server rejected role / view-only** | Toolbar view-only + mode switcher "Viewing" + *Request edit access* |

## 15. View modes UI

**Mode switcher** (`ModeSwitcher`, app widget) pinned at the right of the toolbar:
`ShadButton.outline` with icon + label (label hidden < lg): Editing (pencil), Suggesting
(`message-square-diff`/pencil-line, label + button tinted with `success` token outline),
Viewing (eye). Opens a `WonkyDropdownMenu` with three rich rows (icon, title, description:
"Edit document directly" / "Edits become suggestions" / "Read or print final document") and
shortcuts; rows disabled by role with tooltip ("You need edit access — Request access").

| Aspect | Editing | Suggesting | Viewing |
|--------|---------|------------|---------|
| Editor widget | `SuperEditor` | `SuperEditor` + rewrite | `SuperReader` |
| Toolbar | full | full, non-suggestable items disabled | items 1–6 + switcher |
| Menus | all | non-suggestable items disabled with reason | editing items disabled |
| Block handles | yes | yes (Turn into, Comment; no move/duplicate) | no |
| Comment margin | yes | yes | if role allows |
| Canvas cue | none | thin 2 px `success` line under toolbar | none |
| Caret | visible | visible (author colour tinted) | selection only |

Switching modes is instant; announcements via `SemanticsService` ("Suggesting mode").

## 16. Pages vs Pageless rendering

| Property | Pages | Pageless |
|----------|-------|----------|
| Canvas background | `canvas` token | `page` token (theme page color) |
| Document surface | page cards: `page` color, radius 2, light: shadow `0 1px 3px rgba(0,0,0,.12), 0 1px 2px rgba(0,0,0,.08)`; dark: 1 px `border` token, no shadow | full width |
| Page size | page setup (mm/in → logical px at 96 dpi) × zoom | n/a |
| Gap between pages | 16 px × zoom (min 8) | n/a |
| Canvas padding | 24 px top, 48 px bottom, horizontal centering; if viewport narrower than page: horizontal scroll unless *Fit width* | content column centered, 48 px top padding |
| Content width | page width − margins | `min(theme pageless max width, viewport − 96)` |
| Header/footer | painted in margins: theme `pageChrome` text style (default: 10 pt, `muted` equivalent of theme text), tokens expanded; double-click → Page setup › Header & footer | none |
| Page number indicator | on scroll, a floating pill "Page 3 of 7" near the scrollbar thumb for 1 s | none |
| Block handles | in left margin (≥ 28 px), else overlaid on page edge | 28 px left of column |
| Comment margin | right of page if it fits beside it, else overlaying the canvas's right edge (§10.2) | same, relative to the column |
| Seam (oversized block) | dashed line + "page n" label in gutter (04 §29.3) | n/a |
| Print preview | same paginator as export, exact ([07](07-import-export-print.md)) | prints using page setup (pageless documents still print on pages) |

## 17. Responsive behaviour

Breakpoints = shad `ShadBreakpoints` (sm 640, md 768, lg 1024, xl 1280, 2xl 1536).

| Width | Header | Toolbar | Canvas | Panels |
|-------|--------|---------|--------|--------|
| ≥ xl | full title row | all items fit | comment margin beside the page | docked, resizable |
| lg–xl | full | prio ≥ 5 overflow | comment margin beside the page or overlaying the canvas's right edge | docked (squeezes canvas; Pages mode auto *Fit width* if the page no longer fits and user zoom was 100 %) |
| md–lg | star/move/history move into a ⋮ menu; avatars max 2 | prio ≥ 3 overflow; mode switcher icon-only | comment margin overlays the right edge | docked min width or overlay if canvas < 480 px |
| sm–md | title truncates; Share becomes icon button | prio ≥ 2 overflow | Pages rendered at fit-width zoom (indicator shows effective %); margin overlays (hidden below 600 px canvas) | `ShadSheet` overlay |
| < sm (≥ 360) | app icon, title, ⋮, Share icon | Undo/Redo, style, B, I, link, list, ⋯ | Pageless-like padding 16 px (Pages still drawn as scaled cards); no margin | full-width sheet |

The word count bar (§11), when on, is the same at every width.

Rules: nothing may overflow at 360 px (golden tests at 360, 768, 1024, 1440); dialogs become
full-height sheets below md; table editor becomes a full-screen dialog below md; floating
selection toolbar collapses to B, I, Link, Comment, ⋯; touch input is supported but not
designed (suite 00 non-goal).

## 18. Light and dark

| Region | Light | Dark |
|--------|-------|------|
| Chrome (header, menus, panels, dialogs) | shad tokens (`background`, `foreground`, `border`, `popover`, …) | same tokens, dark scheme |
| Canvas (Pages) | `canvas` (zinc-100-ish) | `canvas` (zinc-950-ish) |
| Page / document surface | theme `light` variant (`page` token default white) | theme `dark` variant if defined, else derived dark (`page` #1e1e1e, light text) — suite 02 §7 |
| Selection | `selection` | `selection` |
| Comment highlight | `commentHighlight(Active)` | dark values |
| Suggestions | `suggestionInsert/Delete` + presence colors | dark values (contrast-checked) |
| Find | `findMatch(Active)` | dark values |
| Remote cursors | `presence1…12` | dark variants |
| Code highlighting | theme code palette light | theme code palette dark |
| Images | unchanged; transparent PNG shown on page color (option P2: checkerboard) | same |
| Print preview / exports | always light variant unless "Export with dark theme" | — |

Theme switch (app theme) animates chrome via `ShadAnimatedTheme`; the editor stylesheet swaps
without animation (avoid re-layout per frame). Goldens for every widget in this spec in both
modes.

## 19. Focus regions and keyboard map (chrome)

- Regions in `F6` order: Title row → Menubar → Toolbar → Document → Side panel → Status bar
  (when shown) (`Shift+F6` reverse). `shell.focus.nextRegion` / `previousRegion`.
- Menubar access: `Alt+F/E/V/I/O/T/H` (Win/Linux) and `Ctrl+Alt+F…` (macOS web) open menus
  (suite 02 §4.3); menu commands are searched in the command palette.
- Toolbar: `Alt+F10` / `Mod+Alt+.`; floating toolbar: `Alt+F10` when visible (takes precedence).
- Panels: `Mod+Alt+Shift+1…5` switch; `Esc` closes and returns focus to the document.
- Title field: no dedicated shortcut (avoids conflicts); reachable via `F6` and *File › Rename*
  (which focuses `DocumentTitleField` with its text selected).

## 20. MCP exposure of the UI

- `ui.get_state` (suite 09 §6.2) for Write adds: `mode`, `layout`, `zoom`, `active_panel`,
  `open_dialog` (id), `selection` (`{anchor, head}` Delta offsets + 200-char excerpt + block
  types), `current_heading`, `word_count`, `page_count`, `find` (`{query, options, count,
  active}`), `participants` (session id, name, actor kind, cursor offsets), `role`, `pending_ops`,
  `pending_uploads`.
- Panels: ids `outline`, `history`, `assistant`, `find` (`ui.open_panel`); comments and
  suggestions are in the margin (`shell.comments.togglePanel`).
- Dialogs: ids from §12 via `ui.get_dialog` / `ui.fill_dialog` / `ui.press_dialog_button`;
  popovers with fields (`write.popover.link`, `write.popover.mention`) are describable too.
- `ui.get_menu_tree` returns §7 with enabled/checked; toolbar spec returned by
  `ui.write.get_toolbar` (ids, enabled, checked, overflowed).
- Proposed app-specific tools (authoritative list in [09](09-mcp-and-ai.md)):
  `ui.write.get_selection`, `ui.write.select_text {quote, occurrence?}`, `ui.write.select_range
  {start, length}`, `ui.write.scroll_to {offset | heading | comment}`,
  `ui.write.get_visible_range`, `ui.write.get_outline`, `ui.write.get_layout {pages, zoom,
  page_rects?}`, `ui.write.get_toolbar`.

## 21. Widget inventory (new)

| Widget | Package | Purpose / notes |
|--------|---------|-----------------|
| `WonkyFloatingToolbar` | **wonky_ui** | Anchored compact toolbar (roving focus, flip/shift positioning via a `LayerLink`); reusable by Sheets (e.g. chart toolbar) |
| `WonkyHoverCard` | **wonky_ui** | Delayed-open hover popover with grace period, keyboard-triggerable; used for links, mentions, presence |
| `WonkyEmojiPicker` | **wonky_ui** | Emoji grid + search + skin tones; also comment reactions |
| `WonkySearchField` | **wonky_ui** | Search input with count, prev/next, option toggles; also Sheets find |
| `WonkyLightbox` | **wonky_ui** | Full-screen in-app image viewer (zoom/pan/download) |
| `WonkyCharacterGrid` | **wonky_ui** | Virtualized glyph grid with keyboard nav (special chars, could serve emoji) |
| `ModeSwitcher` | app | §15 |
| `ParagraphStylePicker` | app | §4.1 (theme-rendered items) |
| `SlashMenu`, `BlockMenu` | app | §8 |
| `LinkEditorPopover`, `LinkHoverCard`, `MentionPicker`, `CodeLanguagePicker` | app | §9 |
| `ImageToolbar`, `TableToolbar`, `SelectionToolbar` | app | §5 (built on `WonkyFloatingToolbar`) |
| `TableEditorPopover` + `TableGridEditor` | app | 04 §18.4 |
| `DocumentCanvas`, `PageChrome` painter | app | §3.4, §16 |
| `CommentMargin` host (with `CommentsFilterTabs` and the composer card) | app | §10.2, 04 §33 |
| `FindPanel`, `OutlinePanel` | app | §10 |
| `WordCountDialog`, `PageSetupDialog`, `SpellingDialog`, `SpecialCharactersDialog`, `DocumentDetailsDialog`, Markdown guide dialog (`showMarkdownGuide`) | app | §12, §7.7 |
| `OffscreenPresenceIndicators` | app | 04 §34.2 |

Every widget gets a `previews.dart` preview (light + dark) and widget tests
(`flutter-add-widget-preview`, `flutter-add-widget-test` skills).

## 22. Acceptance criteria (chrome)

- **AC-05.1** Every menu item in §7 dispatches its command id (verified by a test that walks
  the `MenuSpec` and asserts each id is registered and `ui.get_menu_tree` matches).
- **AC-05.2** Every toolbar control shows the correct enabled/checked state for: caret in
  paragraph, in heading, in code block, in list, image selected, table selected, Viewing mode,
  Suggesting mode, Viewer role (widget test matrix).
- **AC-05.3** At 360 / 768 / 1024 / 1440 px widths, light and dark, no overflow errors and
  goldens match.
- **AC-05.4** Every dialog in §12 is operable via `ui.get_dialog` / `ui.fill_dialog` /
  `ui.press_dialog_button`.
- **AC-05.5** Keyboard-only: from document focus, F6 reaches every region; every popover and
  dialog can be completed without a pointer.
- **AC-05.6** Switching Pages ⇄ Pageless and changing zoom keep the caret block on screen.
- **AC-05.7** Mode switcher disables modes by role with explanatory tooltips; role downgrade
  switches mode live.

## 23. Shell command ids used here

The canonical catalog is [suite 08 §5](../08-commands-and-undo.md). Ids used by this spec:

`shell.nav.home`, `shell.drive.rename`, `shell.drive.setStarred`, `shell.drive.move`,
`shell.drive.copy`, `shell.drive.addShortcut`, `shell.drive.trash`, `shell.drive.restore`,
`shell.drive.togglePinnedOffline`, `shell.file.new`, `shell.file.newFromTemplate`,
`shell.file.open`, `shell.file.import`, `shell.sharing.open`, `shell.sharing.copyLink`,
`shell.sharing.requestAccess`, `shell.versions.open`, `shell.versions.togglePanel`,
`shell.versions.nameCurrent`, `shell.comments.create`, `shell.comments.togglePanel`,
`shell.comments.activate`, `shell.edit.undo`, `shell.edit.redo`, `shell.edit.undoHistory`,
`shell.edit.undoTo`, `shell.help.shortcuts`, `shell.help.feedback`, `shell.help.whatsNew`,
`shell.help.about`, `shell.settings.open`, `shell.focus.nextRegion`,
`shell.focus.previousRegion` (existing: `shell.ai.togglePanel`, `shell.appearance.setTheme`).

## 24. Chrome-level Write command index

Commands introduced by this spec (editing/content commands are in [04](04-editor.md) §40).
*U* = undo step (domain in parentheses). Role: V viewer, C commenter, E editor.

| Command | Args | Role | U | Notes |
|---------|------|------|---|-------|
| `write.file.download` | `format` (`md, mdZip, pdf, html, txt, docx, odt, rtf, epub`), `options?` (open object: the export options JSON) | V (`copyAllowed`) | — | [07](07-import-export-print.md); web: browser download in same tab; desktop: save dialog |
| `write.file.exportOptions` | — | V | — | Dialog 12.16 |
| `write.file.print` | — | V (`copyAllowed`) | — | Navigates to `/d/:uuid/print` |
| `write.insert.fromFile` (P1) | `fileUploadId?` | C* | ✓ (content) | Picker → dialog 12.9 |
| `write.insert.tableDialog` | — | E | — | Dialog 12.3 |
| `write.insert.mentionTrigger` | — | C* | — | Inserts `@`, opens picker |
| `write.doc.pageSetup` | `tab?` | V (edit: E) | — | Dialog 12.6 |
| `write.doc.setPageSetup` | `pageSetup` (the `PageSetup` JSON; the schema accepts its keys) | E | ✓ (write.meta) | |
| `write.doc.setLayout` | `layout` | E | ✓ (write.meta) | Also 04 §29.2 |
| `write.doc.languageDialog` | — | E | — | Dialog 12.7 |
| `write.doc.setLanguage` | `language` | E | ✓ (write.meta) | |
| `write.doc.setFrontMatter` | `text` | E | ✓ (write.meta) | YAML validated |
| `write.doc.properties` | — | V | — | Dialog 12.8 |
>>>

| `write.theme.openPicker` / `write.theme.edit {section?}` / `write.theme.apply {themeId}` / `write.theme.setUserDefault` | | E (apply/edit) | ✓ (write.meta / write.theme) | Owned by [06](06-themes.md) |
| `write.view.toggleWordCount` | — | V | — | Local pref (word count bar, §11; default off) |
| `write.outline.setMaxLevel` | `level` (1–6) | V | — | Local pref |
| `write.spell.openDialog` (P1) | — | V | — | Dialog 12.10 |
| `write.spell.personalDictionary` / `removeFromDictionary {word}` (P1) | | V | — | Dialog 12.11; user pref |
>>>

| `write.prefs.setSelectionToolbar` / `setDefaultMode {mode}` / `setDefaultPageSetup {pageSetup}` | | V | — | User prefs (`writeDefaults`) |
| `write.help.markdownGuide` | `section?` | V | — | Markdown guide dialog (Help menu only) |
| `write.ai.generateOutline` / `write.ai.proofread` | | E (proofread: V, results as suggestions require C) | ✓ when applied | suite 10 §4 |
| `write.suggestions.accept {id}` / `reject {id}` / `acceptAll` / `rejectAll` / `next` / `previous` | | E (navigation V) | ✓ | Owned by [08](08-comments-suggestions-history.md) |

All of these appear in `ui.list_commands` with their menu paths from §7.

## 25. Implementation notes (iteration 1)

- **Code layout**: screen `lib/features/screen/` (`WriteDocumentScreen`, `WriteToolbar`,
  `ModeSwitcher`, word count bar, selection toolbar, context menus, dialogs under `dialogs/`);
  `WriteDocumentController` (`features/screen/write_document_controller.dart`) is the shell's
  `DocumentController`, built on the sync workstream's `WriteDocumentSession`
  (`features/document/`). Commands: `lib/commands/` (`editor_commands.dart` wraps
  `editorCommandCatalog()`; `screen_commands.dart` holds the commands of §24 and 07 §12).
- **Mode shortcuts**: the per-mode commands `write.mode.editing` / `write.mode.suggesting` /
  `write.mode.viewing` carry the bindings of §7.3 (key bindings have no fixed args);
  `write.mode.set {mode}` stays the MCP/AI entry point.
- **Popovers opened by commands** (link editor) use an anchored modal route
  (`features/screen/anchored_popover.dart`) positioned at the selection rect; the theme picker,
  table editor and image dialogs are `ShadDialog`s.
- **Comment margin** (§10.2) is the only place for comments and suggestions; it is shown when
  the margin pref is on, there are cards (anchored open threads, pending suggestions or a
  draft) and the canvas is ≥ 600 px wide — beside the page when it fits, else overlaying the
  canvas's right edge.
- **Removed** (no longer part of the product): compact mode, full screen, View › Show, menu
  search, help center, File › Settings (document settings dialog), View › Preview theme, Format ›
  "What formatting is supported", Tools › View Markdown source, focus mode and typewriter
  scrolling, the comments and suggestions side panels, the activity dashboard.
- **Not built this iteration** (documented as TODO): spelling (§12.10–12.11), emoji/special
  characters (§9.5, §12.4), lightbox (§12.15), export options dialog (§12.16), floating
  image/table toolbars (§5.2–5.3; the context and block menus offer the same commands), drag &
  drop, AI items, native macOS menubar, compact-density goldens.

