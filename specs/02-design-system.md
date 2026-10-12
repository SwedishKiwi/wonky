# 02 · Design System — `wonky_ui`

All UI is built with **`shad`** (Serverpod's high-fidelity shadcn/ui port, `shad: ^0.99.4`,
docs: <https://shad.serverpod.dev/>; the package ships an agent skill at
`skills/shad-overview/SKILL.md` — read it before building UI). Where shad lacks a component,
we build a **matching widget** in `packages/wonky_ui` that uses only shad tokens
(`ShadTheme.of(context)`), shad primitives (`ShadPortal`, `ShadPopover`, `ShadFocusable`,
`ShadRovingFocus`) and Lucide icons — so it is indistinguishable from native shad components and
follows light/dark automatically.

Material widgets are **not** used directly in feature code (shad derives a Material `ThemeData`
for interop only; `Scaffold`-free layouts are preferred). `wonky_ui` must not depend on Serverpod,
the client, or any feature package — pure presentation.

## 1. App setup

```dart
ShadApp.router(
  title: 'Wonky Write',
  theme: WonkyTheme.light(prefs),     // ShadThemeData
  darkTheme: WonkyTheme.dark(prefs),
  themeMode: prefs.themeMode,         // system | light | dark
  routerConfig: router,
  localizationsDelegates: [GlobalShadLocalizations.delegate, ...WonkyL10n.delegates],
)
```

- `WonkyTheme` builds `ShadThemeData` from: style tokens (`ShadStyleTokens.vega` default),
  color scheme (`ShadZincColorScheme` default; accent override from user prefs via
  `ShadColorScheme.fromName`), radius, density (`ShadSpacing` scale: comfortable / compact), and
  **custom tokens** (below).
- Themes are cached and compared by value: `ShadThemeData` inequality triggers a 200 ms lerp
  on every rebuild, so `WonkyTheme` memoizes per (brightness, accent, density) key.
  Don't `copyWith(radius:)` — rebuild the theme instead (component themes are not re-derived).
- App theme mode switch: `shell.appearance.setTheme(system|light|dark)` command; the top bar
  toggle cycles them. Switching animates via `ShadAnimatedTheme` (honours *Reduce motion*).

## 2. Tokens

Use shad tokens: `background`, `foreground`, `card`, `popover`, `primary`, `secondary`, `muted`,
`accent`, `destructive`, `border`, `input`, `ring`, `selection`, `chart1–5`, `sidebar*`,
`ShadRadii`, `ShadTextTheme` (`h1…h4`, `p`, `large`, `small`, `muted`), spacing steps
(`ShadPadding`, `ShadGap`).

Custom tokens (registered via `ShadColorScheme.custom`, read through a `WonkyColors` extension
on `ShadColorScheme`), each defined for light and dark:

| Token | Use |
|-------|-----|
| `canvas` | Area behind document pages (Write) / outside grid |
| `page` | Write page surface (follows the Write theme's page color, default white / #1e1e1e) |
| `gridLine`, `gridHeaderBg`, `gridHeaderFg`, `gridHeaderSelectedBg` | Sheets grid |
| `selectionFill`, `selectionBorder` | Sheets range selection |
| `fillHandle` | Sheets fill handle |
| `commentHighlight`, `commentHighlightActive` | Anchored comments |
| `suggestionInsert`, `suggestionDelete` | Write suggestion mode |
| `findMatch`, `findMatchActive` | Find & replace highlights |
| `presence1…presence12` | Collaborator colors (cursor, selection, avatar ring); assigned by hash of user id |
| `success`, `warning`, `info` | Status badges, toasts |
| `offline` | Offline banner |

Typography: shad bundles **Inter**, **Geist** and **GeistMono**. App chrome uses Geist (UI) and
GeistMono (formulas, code, shortcuts). Document fonts (Write themes, Sheets cell fonts) come from
a curated font list (see each app spec) loaded via bundled assets (no runtime Google Fonts on
web for privacy/offline; `google_fonts` is used only at build-time to fetch files into assets).

Icons: `LucideIcons.*` only. Icon size 16 in toolbars/menus, 20 in sidebars, 24 in empty states.

## 3. shad components we use (mapping)

| Need | shad component |
|------|----------------|
| Menu bar (File/Edit/View…) | `ShadMenubar` + `ShadMenubarItem` + `ShadContextMenuItem` (submenus via `items:`) |
| Context menus | `ShadContextMenuRegion` |
| Dropdown menus (toolbar dropdowns, ⋮ menus) | `ShadContextMenu` with controller + anchor, wrapped as `WonkyDropdownMenu` |
| Buttons, toggles | `ShadButton.*`, `ShadIconButton`, `ShadToggle`, `ShadToggleGroup` |
| Selects / combobox | `ShadSelect`, `ShadSelect.withSearch` |
| Text fields | `ShadInput`, `ShadTextarea`, `ShadInputOTP` |
| Forms | `ShadForm` + `Shad*FormField` |
| Dialogs | `ShadDialog`, `ShadDialog.alert`, `showShadDialog` |
| Side sheets (mobile-ish / narrow) | `ShadSheet` |
| Popovers / tooltips | `ShadPopover`, `ShadTooltip` |
| Toasts | `ShadSonner` (stacked), `ShadToast.destructive` for errors |
| Tabs | `ShadTabs` |
| Accordions | `ShadAccordion` (side panels, CF rules list) |
| Resizable side panels | `ShadResizablePanelGroup` / `ShadResizablePanel` |
| App sidebar | `ShadSidebarScaffold`, `ShadSidebarMenu…` |
| Command palette | `ShadCommand`, `ShadCommandGroup`, `ShadCommandItem` in a `ShadDialog` |
| Tables (drive list, settings tables, version list) | `ShadTable` / `ShadDataTable` |
| Calendar / date picker | `ShadCalendar`, `ShadDatePicker` (DV date picker, version filters) |
| Avatars, badges, cards, alerts, kbd, empty, skeleton, spinner, progress | `ShadAvatar`, `ShadBadge`, `ShadCard`, `ShadAlert`, `ShadKbd`, `ShadEmpty`, `ShadSkeleton`, `ShadSpinner`, `ShadProgress` |
| Checkbox, switch, radio, slider | `ShadCheckbox`, `ShadSwitch`, `ShadRadioGroup`, `ShadSlider` |
| Breadcrumbs | `ShadBreadcrumb` |

## 4. Custom widgets in `wonky_ui` (matching shad)

Each custom widget gets: a `previews.dart` widget preview (light + dark), a widget test, and a
theme slot (`WonkyThemeExtension`) for overrides. Spec for each:

### 4.1 `WonkyToolbar`
Horizontal formatting toolbar with **overflow handling**: children are `ToolbarItem`s with a
priority; when width is insufficient, lowest-priority items move into a trailing "⋯" overflow
dropdown (preserving groups). Supports `ToolbarGroup` (separated by `ShadSeparator.vertical`),
`ToolbarToggleButton` (wraps `ShadToggle`, 28×28, tooltip with title + `ShadKbd` shortcut),
`ToolbarDropdownButton` (label + chevron, opens `WonkyDropdownMenu`), `ToolbarSplitButton`
(action + chevron, e.g. text color / borders), `ToolbarNumberField` (font size: − / input / +),
`ToolbarSelect` (zoom, styles). Keyboard: `Alt+/` (or `Mod+Alt+.`) focuses toolbar, arrows move
(`ShadRovingFocus`), Esc returns focus to the editor. Height 40 px (compact 36).

### 4.2 `WonkyDropdownMenu` and menu item variants
Thin wrapper over `ShadContextMenu` (controller + anchor) adding:
- `MenuItem.command(commandId)` — title/icon/shortcut/enabled/checked from the command registry.
- `MenuCheckItem` (✓ leading when checked), `MenuRadioItem` (● leading), `MenuSubmenu`,
  `MenuSeparator`, `MenuLabel` (section header), `MenuCustom` (e.g. color grid, table-size grid).
- Trailing shortcut rendered with `ShadKbd` (platform glyphs: ⌘ ⌥ ⇧ ⌃ on macOS; Ctrl+Alt+Shift
  elsewhere).
- Type-ahead: typing letters jumps to items.
- Used both in `ShadMenubar` items and standalone dropdowns.

### 4.3 `WonkyMenubar`
`ShadMenubar` whose items are built from a declarative `MenuSpec` tree
(`MenuSpec.command`, `.submenu`, `.separator`, `.custom`) so that the **same spec** generates the
menubar, the command-palette menu paths and the MCP `ui.get_menu_tree` output. `Alt` (Win/Linux)
or `Ctrl+F2`-style focus shortcut (`Alt+F` opens File etc. on Win/Linux; on macOS, `Ctrl+Alt+F`)
to avoid conflicts. Also includes a **menu search** item ("Search the menus (Alt+/)") as in
Google Docs, which opens the command palette filtered to menu commands.

### 4.4 `WonkyColorPicker`
Popover content used for text color (Sheets), fill color, border color, tab color, chart colors,
theme colors:
- Header row: **Reset** (`Automatic`/`None`) button.
- Grid of 10×8 swatches (Google-like palette) + **Theme colors** row (document/theme palette) +
  **Recent/custom colors** row (stored per user).
- **Custom…** opens an inline panel: saturation/value square, hue slider, alpha slider (when
  allowed), hex input, RGB inputs, eyedropper (desktop only, where supported).
- Keyboard: arrows over grid, Enter selects. Each swatch has an accessible name ("light red 2").
- Returns `WonkyColor` (`{hex, themeRef?}`), so theme-referenced colors can update when the theme
  changes.

### 4.5 `WonkySplitView` / side panel host
A right-side **panel host** used by both apps: hosts Outline, Comments, Version history,
Assistant, Find & replace (Sheets uses a dialog), Script editor sidebar, Named ranges, Data
validation, Conditional formatting, Chart editor, Pivot editor, etc. Built on
`ShadResizablePanelGroup`. Behaviors: one active panel at a time (tabs header with icons when >1
recently open), width persisted per panel id, collapse to icon rail, Esc closes, `Mod+Alt+Shift+[` / `Mod+Alt+Shift+]`
cycle panels (`Mod+Alt+Shift+0–9` is reserved for Sheets macros). Panels declare `id`, `title`, `icon`, `minWidth`, `defaultWidth`, `builder`.

### 4.6 `WonkyTreeView`
Lazy tree (drive folder tree, document outline, script file tree): expand/collapse, keyboard
navigation (arrows, Home/End, `*` expand all), drag-and-drop reordering with drop indicators,
inline rename, virtualized for > 1000 nodes.

### 4.7 `PresenceAvatarStack`
Overlapping avatars of collaborators currently in the file (max 4 + "+N" chip), ring in
presence color, tooltip with name + "Editing"/"Viewing"/"Idle"; click avatar → jump to their
cursor; click "+N" → popover list.

### 4.8 `RemoteCursorOverlay` primitives
Shared painters for remote carets (2 px bar + name flag in presence color, flag fades after 3 s
of inactivity and on hover reappears) and remote selection fills (presence color at 20% alpha).
Used by Write (text layer) and Sheets (cell rect).

### 4.9 `WonkyNumberStepper`
`ShadInput` with −/+ buttons, min/max/step, scroll-to-change, arrow keys, validation. Used for
font size, decimal places, row counts, page margins.

### 4.10 `WonkyTableSizePicker`
Grid (max 10×10, grows to 20×20 on hover) to pick rows×columns for "Insert table" (Write) —
custom menu content.

### 4.11 `FontPicker`
`ShadSelect.withSearch` variant showing each font rendered in its own face, sections "Recent",
"Theme fonts", "All fonts".

### 4.12 `WonkyScrollArea`
Styled scrollbars (thin, auto-hide, shad colors) used around the editor canvas and panels.
Includes "scroll shadow" top/bottom edges.

### 4.13 `StatusBar`
Bottom bar (24 px) slot used by both apps: left (word count / sum-avg-count of selection),
center (sync status), right (zoom, view toggles).

### 4.14 `SyncStatusIndicator`
Icon + label: *Saved*, *Saving…*, *Offline — changes saved on this device*, *Sync error*
(clickable → details dialog with retry & log). Lives in each app's title row.

### 4.15 `DocumentTitleField`
Inline-editable title in the editor header: looks like text, becomes `ShadInput` on click,
Enter/blur commits via a rename command (undoable), Esc reverts; auto-width up to 400 px.

### 4.16 `KeyboardShortcutRecorder`
Captures a key chord for the keyboard settings page; displays with `ShadKbd`.

### 4.17 `EmptyStateIllustration`
Light/dark-aware SVG illustrations (`flutter_svg`, via shad dep) for empty states.

### 4.18 `LoadingShimmer` patterns
Skeleton layouts for drive list, document page, grid (built from `ShadSkeleton`).

## 5. Layout, responsiveness, motion

- Breakpoints: shad `ShadBreakpoints`. Desktop-first. At `< MD` the sidebar collapses to a drawer
  (`ShadSheet`), side panels open as sheets over content, toolbars overflow aggressively. Nothing
  may overflow at 360 px width.
- Motion: 150–200 ms ease-out for popovers/panels; disabled when *Reduce motion* is on or
  `MediaQuery.disableAnimations`.
- Focus: visible focus ring (`ring` token) on all interactive elements; never remove outlines.

## 6. Accessibility

- All interactive widgets have semantics labels; icons-only buttons have tooltips.
- Contrast ≥ 4.5:1 for text in both themes (verify custom tokens).
- Full keyboard operability: menus, toolbars, dialogs, grid, editor, panels.
- Screen-reader announcements (`SemanticsService.announce`) for: undo/redo labels, cell
  navigation (Sheets: "B4, 42, formula =SUM(…)"), remote join/leave, sync errors.

## 7. Theming the document vs. the app

- **App theme** (light/dark) affects the chrome **and** the default rendering of document
  surfaces (dark page, light text) unless a Write theme explicitly defines dark colors.
- Write themes define both `light` and `dark` variants (see Write theme spec); Sheets cell
  colors are absolute, but the grid chrome, default text color (when "automatic") and default
  fill follow the app theme. Exports/prints always use the light variant unless the user picks
  "Export with dark theme".
