# Slides 03 · Editor Canvas and Objects

The slide canvas is where slides are designed: selecting, moving, resizing, rotating, snapping,
aligning, and editing every element kind. This spec defines the canvas, the selection model, the
transform tools, smart guides, each element kind's editing, element groups, lock/hide/z-order,
the format painter, the keyboard map, the clipboard, find & replace, spell check, accessibility
and performance budgets.

Storage of everything here is [02-data-model.md](02-data-model.md). Menus, toolbar, inspector,
navigator and dialogs are [04-screens-menus-toolbar.md](04-screens-menus-toolbar.md) (the canonical
menu command registry). Code elements' editing is [07-code-blocks.md](07-code-blocks.md); chart
elements' editing [08-charts-from-sheets.md](08-charts-from-sheets.md); builds and Magic Move
[06-animations-and-transitions.md](06-animations-and-transitions.md).

Owned folders: `wonky_slides/lib/features/{canvas,selection,snapping,elements/**,text_editing,
layers,clipboard,find,spellcheck,accessibility}/`, `wonky_slides_core/lib/src/{scene,layout,text,
geometry,connectors,clipboard}/`.

---

## 1. Architecture

### 1.1 Runtime objects (one set per open deck)

| Object | Package | Responsibility |
|--------|---------|----------------|
| `DeckSession` | app `features/sync` (contract in [12 §5.3](12-implementation-plan.md)) | `DeckModel`, `execute(op)`, `applyChanges`, remote batches, load state, role |
| `DeckEditorController` (`DocumentController`) | app `features/editor_screen` | Current slide, view mode, active tool, panels; implements shell hooks (cut/copy/paste, selection snapshot, comment anchors, presence cursor JSON) |
| `CanvasController` | app `features/canvas` | Zoom, fit, scroll offset, su ↔ screen mapping, hit testing, viewport rect |
| `SelectionController` | app `features/selection` | Selected element ids, focus (canvas/text/table/crop), group entry path, marquee |
| `TransformSession` | app `features/selection` | Live drag/resize/rotate state, ghost frames, writes one plan on drop |
| `SnapEngine` | core `geometry/snapping.dart` (pure Dart) | Snap targets and results for a moving box; equal-spacing detection |
| `ElementKindRegistry` | app `features/elements` | Per-kind `ElementKindHandler` (§1.3) |
| `SlideTextEditor` | app `features/text_editing` | The single active rich-text editor (super_editor) for the body being edited |
| `SlideStage` | app `features/stage` (owned by 06 §12.1) | Paints `SlideScene` (02 §11) in the **edit frame** (06 §9.6) with per-element `RepaintBoundary`s; shared by canvas, thumbnails and presenting |

### 1.2 Keyboard scopes (suite 08 §1.2)

| Scope | Active when | Examples |
|-------|-------------|----------|
| `slidesCanvas` | Canvas has focus, no text editing | arrows nudge, Delete, Mod+D, Mod+G, Enter edits text |
| `slidesText` | A text body is being edited | Mod+B, Tab indents list, Esc exits editing |
| `slidesTable` | Table cell range selected (not editing text) | arrows move cell selection, Enter edits cell |
| `slidesCrop` | Image crop mode | Enter commits, Esc cancels |
| `slidesNavigator` | Slide navigator focused (04 §5) | Mod+G groups slides, Mod+↑/↓ move slides |
| `slidesNotes` | Speaker notes editor focused | Mod+B, Esc returns to canvas |
| `present` | Presenting (10 §14) | arrows, Space, B/W |

More specific scopes win; contextual bindings (suite 08 §1.2) let one chord mean different
commands per scope (e.g. Mod+G).

### 1.3 Element kind handler API (contract, [12 §5.4](12-implementation-plan.md))

```dart
abstract class ElementKindHandler {
  SlideElementKind get kind;
  /// Scene node for a resolved element (pure, used by canvas, thumbnails, present, PDF via core).
  SceneNode buildScene(ResolvedElement e, SceneContext ctx);          // implemented in core
  /// Precise hit test in element-local coordinates (su).
  bool hitTest(ResolvedElement e, Offset localSu, {required double tolerancePx});
  /// Extra handles beyond the 8 resize + rotation handles (adjust, line endpoints, crop…).
  List<HandleSpec> extraHandles(ResolvedElement e);
  /// Snap points offered to the SnapEngine (edges, centers, connection sites).
  List<SnapPoint> snapPoints(ResolvedElement e);
  /// What double-click / Enter does (edit text, enter group, crop, open chart editor…).
  ElementActivation activation(ResolvedElement e);
  /// Inspector sections for the Format tab (04 §7.2).
  List<InspectorSectionSpec> inspectorSections(BuildContext context, ElementSelection sel);
  /// Overlay widget while the element is being edited (text editor, code editor, crop UI…).
  Widget? editingOverlay(BuildContext context, EditingTarget target);
}
```

Handlers are registered by each `elements/<kind>/` folder; the canvas never switches on kind.

---

## 2. Canvas

### 2.1 Layout

```
┌──────────────────────── canvas viewport (token `canvas`) ───────────────────────┐
│   pasteboard (objects may sit off-slide; drawn at 40 % opacity outside)          │
│        ┌──────────────────────── slide ────────────────────────┐                 │
│        │  background, master/layout elements, slide elements    │  shadow (token  │
│        │  selection chrome, guides, remote selections (09)      │  `slideShadow`) │
│        └────────────────────────────────────────────────────────┘                 │
│                                                    [ − 100 % + ]  [Fit]  (status bar) │
└─────────────────────────────────────────────────────────────────────────────────┘
```

- The slide is centered with a margin of 48 px (Fit) on a pasteboard that extends **one slide
  width/height** beyond each edge (objects can be parked off-slide; they are clipped when
  presenting and in PDF/thumbnails).
- Background of the viewport: app token `canvas` (follows light/dark). The slide renders as
  designed in the deck's **appearance** (05 §2.4), independent of the app theme (suite 02 §8: like
  Sheets cell colors, deck colors are absolute).
- Rulers (P1, §5.6) occupy 20 px at top/left when shown.

### 2.2 Zoom and fit

| Action | Command | Shortcut (mac / win-linux) |
|--------|---------|----------------------------|
| Fit slide to window (default; re-fits on resize) | `slides.view.zoomFit` | ⌥⌘0 / Ctrl+Alt+0 |
| Zoom to 100 % (1 su = 1 logical px) | `slides.view.zoom {percent: 100}` | ⌘0 (desktop) / Ctrl+0 (desktop) |
| Zoom in / out (steps 10, 25, 33, 50, 67, 75, 100, 125, 150, 200, 300, 400 %) | `slides.view.zoomIn` / `zoomOut` | ⌥⌘= / ⌥⌘− ; Ctrl+Alt+= / Ctrl+Alt+− |
| Zoom to selection | `slides.view.zoomToSelection` | — |
| Pinch / Mod+wheel | continuous zoom around the pointer | trackpad / Mod+wheel |

"Fit" is a mode: while active, window resizes keep the slide fitted; any explicit zoom leaves it.
Zoom and scroll are per-user view state (`LocalViewState`, not undoable, suite 08 §2).

### 2.3 Scrolling and panning

- Wheel/trackpad scroll pans the pasteboard (when the slide doesn't fit); at Fit, vertical wheel
  over the canvas **switches slides** (P1, setting *Scroll to change slides*, default off — Google
  behavior is to scroll within the page).
- **Space+drag** (or middle-mouse drag) pans; the cursor shows a hand.
- Scrollbars: `WonkyScrollArea` thin auto-hide.

### 2.4 Rendering

- The current slide is painted from its `SlideScene` (02 §11): one `RepaintBoundary` per
  top-level element, a background layer, a master/layout layer (cached picture, invalidated by
  layout revision), an **overlay layer** for selection chrome, guides, remote selections and
  comment pins (repaints without touching content).
- Text is laid out by the Flutter `TextLayoutEngine` (same metrics as thumbnails/presenting);
  fonts load on demand (05 §3.3); until loaded, fallback metrics then re-layout (max 1.5 s).
- During a drag, only the moving elements' boundaries repaint (transform layer), never relayout.
- Off-slide content is drawn at 40 % opacity; hidden elements are not drawn (§8.2).
- Empty placeholders draw a dashed outline (token `placeholderBorder`) and their prompt text
  (§6.2) — only in the editor (never thumbnails, presenting or PDF).

---

## 3. Selection model

### 3.1 States

| State | Visual | Keyboard |
|-------|--------|----------|
| **None** (slide focused) | — | arrows: nothing; Tab selects the first element in reading order; Enter: nothing |
| **Element(s) selected** | 1.5 px `slidesSelection` outline per element; **one** bounding box with 8 resize handles + rotation handle when one element (or a multi-selection — box of the union); dimensions badge while transforming | arrows nudge, Delete, Mod+D, Mod+C/X, Tab/Shift+Tab next/previous element, Enter activates (§3.4), Esc clears |
| **Inside group** | Group's outline dashed; selected child outlined | Esc → selects the group |
| **Text editing** | Box outline thin dashed, caret, text selection | `slidesText` scope; Esc → element selected |
| **Table cells** | Cell range highlight | `slidesTable` scope |
| **Crop** | Crop frame + dimmed outside area | `slidesCrop` scope |
| **Line endpoints** | Lines show endpoint handles instead of a box | drag endpoints |

Selection is **per slide**: changing the current slide clears it (restored when returning in the
same session). Selection is view state, never undoable, but restored by undo/redo (suite 08).

### 3.2 Pointer rules

| Gesture | Result |
|---------|--------|
| Click on an element | Select it alone (the **topmost hit**, by z-order, among unlocked, visible elements; transparent areas of shapes without fill hit only within 4 px of the stroke unless the shape has text) |
| Click on an element inside a group (group not entered) | Selects the **group** |
| Double-click on a group | Enters the group and selects the hit child |
| Click on empty slide / pasteboard | Clears the selection (slide focused) |
| Shift+click | Toggle element in the selection (Mod+click too) |
| Mod+click on a child inside a group (not entered) | Selects the child directly ("deep select") |
| Drag from empty area | **Marquee**: selects elements fully inside the rectangle; with Alt (Option): elements touching it; Shift adds to the selection |
| Drag on a selected element | Moves the selection (§4.1) |
| Drag on an unselected element | Selects it and moves it in one gesture |
| Click on a locked element | Nothing is selected (click goes through to elements below); Layers panel can select it (§8.1) |
| Right-click | Selects the hit element if not selected, then the context menu (04 §11.2) |
| Double-click / Enter | Activation (§3.4) |

Hit tolerance: 4 logical px for strokes and line elements (8 px for lines thinner than 4 px).

### 3.3 Keyboard selection

- **Tab / Shift+Tab** cycles elements of the current slide in **reading order** (§17.2),
  including placeholders; inside an entered group, cycles its children.
- **Mod+A** (`shell.edit.selectAll`): canvas → all unlocked, visible elements of the slide; text
  editing → all text of the body; table → all cells.
- **Esc**: text editing → element selected; inside group → group selected; element(s) → none.
- `slides.select.sameKind` (P2): selects every element of the same kind on the slide.

### 3.4 Activation (double-click / Enter)

| Kind | Activation |
|------|------------|
| text, shape, placeholder with text | Enter text editing (caret at click position; Enter key: caret at end) |
| group | Enter group |
| table | Edit the clicked cell's text (Enter: first cell) |
| image | Enter crop mode (§6.5.4) |
| picture placeholder (empty) | Open *Insert image* (§6.5.1) |
| line/connector | Edit the line label (P2); otherwise nothing |
| code | Enter code editing ([07](07-code-blocks.md)) |
| chart | Open the chart inspector section ([08](08-charts-from-sheets.md)) |
| icon | Open the icon picker to replace the icon |

**Typing** a printable character with exactly one text-capable element selected enters text
editing with the caret at the end and inserts the character (Google behavior). Typing with an
empty placeholder selected replaces its prompt.

---

## 4. Transforms

### 4.1 Move

- Drag starts after a 3 px threshold. A **live ghost** (the elements themselves, moved on the
  transform layer) follows the pointer; snapping (§5) applies continuously; a badge shows `x, y`
  in su.
- **Shift** constrains to horizontal/vertical/45°. **Alt (Option)** at drop *duplicates* instead
  of moving (Keynote/Figma); the cursor shows `+`. **Mod** held disables snapping temporarily.
- On drop the move is written **once** as `slides.element.move {ids, dx, dy}` →
  `UpdateFrames` naming `x,y` (02 P4). One undo step "Move".
- Dragging off the slide parks elements on the pasteboard; dragging onto the navigator moves
  (Alt: copies) them to the hovered slide (P1, drop indicator on the thumbnail).
- Auto-scroll when the pointer is within 24 px of the viewport edge (zoomed in).

### 4.2 Resize

- 8 handles (corners + edges, 8 px squares, `slidesSelection` stroke, `background` fill; 16 px
  touch targets). Corner drag resizes both dimensions; **Shift** keeps aspect ratio (default *on*
  for images, icons and groups — Shift then frees it); **Alt** resizes from the center.
- Multi-selection resize scales every element's frame relative to the selection box (font sizes
  are **not** scaled unless *Scale text* is checked in the inspector's Arrange section, P1).
- Text boxes with `autofit: resize`: dragging the top/bottom handles sets the minimum height;
  `wrap: false` boxes resize width only by dragging the left/right handles (switching to
  `wrap: true` on drag).
- Minimum 1 su (lines: 0 in one dimension). Negative drags flip (`flipH`/`flipV` toggled) like
  Keynote.
- Written once on release: `slides.element.resize {ids, frames}` naming `x,y,width,height`
  (+ `flipH/flipV` if changed). One undo step "Resize".

### 4.3 Rotate

- Rotation handle 24 px above the top edge (below when near the viewport top). Drag rotates about
  the box center; **Shift** snaps to 15°; angle badge shows degrees. Near 0/90/180/270° it snaps
  within 3° (Mod disables).
- Multi-selection rotates every element about the selection center (each element's `x,y` and
  `rotation` written).
- Commands: `slides.arrange.rotate {degrees: 90|-90}`, `slides.arrange.flip {axis: h|v}`.
- Numeric rotation in the inspector (Arrange section, `WonkyNumberStepper`, −360…360).

### 4.4 Nudge

Arrow = 1 su, Shift+arrow = 10 su (Mod+arrow: 1 screen pixel at the current zoom, P2). A burst of
nudges within 1000 ms coalesces into one undo step "Nudge" (`UndoService.replaceLast`).
`slides.element.nudge {dx, dy}`.

### 4.5 Numeric frame

Inspector › Arrange (04 §7.2): X, Y, W, H (su; also in in/cm per Settings › Slides › Units, P1),
lock-aspect toggle, rotation, flip buttons. Each committed field is one undo step.

### 4.6 Remote and permissions

- Collaborators see the result on drop (sync) and, while dragging, a **transient outline** of the
  moving frame in the mover's presence color (presence `transform` hint, 09 §2.4, P1).
- Viewers/commenters can select (to copy if allowed, read alt text, comment) but not transform:
  handles are hidden and the cursor shows the default arrow.

---

## 5. Smart guides, snapping, alignment, rulers and guides

### 5.1 Snap targets

`SnapEngine.snap(movingBox, targets, thresholdSu)` (pure Dart) with targets (in priority order):

1. Slide edges and center lines (horizontal and vertical).
2. User guides (§5.6).
3. Edges and centers of other **visible** elements on the slide (including master/layout
   decorations and placeholders), and of the selection's own siblings inside an entered group.
4. **Equal spacing**: gaps equal to existing gaps between neighbors in the same row/column.
5. **Equal size** (resize only): widths/heights equal to other elements'.
6. Grid (P2: optional 8 su grid, View › Snap to grid).

Threshold: 6 screen px converted to su at the current zoom. Snapping applies to the moving
selection's left/center/right and top/middle/bottom. Lines snap their endpoints to targets and to
**connection sites** (§6.4).

### 5.2 Visuals

- Alignment guides: 1 px lines in token `slidesGuide` (magenta-ish `#E5389B` light / `#F472B6`
  dark) spanning between the aligned objects, with small × markers at aligned points.
- Equal spacing: pink bars with the distance label ("48") between each pair of equal gaps.
- Slide center: dashed guide across the whole slide.
- Distance labels (P1): holding **Alt** while an element is selected and the pointer hovers
  another element (or the slide) shows distances in su (Figma).

### 5.3 Preferences

View › Snap ▸ *Smart guides* (`slides.view.toggleSmartGuides`, default on), *Snap to objects*
(`slides.view.toggleSnapObjects`, on), *Snap to guides* (on), *Snap to grid* (P2, off). Per-user
(`UserPreferences.slidesDefaults`), not undoable.

### 5.4 Keyboard

While dragging: Shift constrain, Alt duplicate, Mod no-snap. While resizing: Shift aspect, Alt
center.

### 5.5 Align and distribute

| Command | Effect | Shortcut |
|---------|--------|----------|
| `slides.arrange.align {edge: left\|centerH\|right\|top\|middle\|bottom}` | ≥ 2 selected: align to the **selection bounds** (or to the *key object* if one was clicked last with Alt, P2); 1 selected: align to the **slide** | ⌥⌘← ⌥⌘→ ⌥⌘↑ ⌥⌘↓ for left/right/top/bottom (canvas scope) · Ctrl+Alt+arrows |
| `slides.arrange.distribute {axis: horizontal\|vertical}` | ≥ 3 selected: equal gaps between first and last | — |
| `slides.arrange.centerOnSlide {axis: horizontal\|vertical\|both}` | Center the selection box on the slide | — |
| `slides.arrange.matchSize {dimension: width\|height\|both}` (P1) | Set to the key (first-selected) element's size | — |
| `slides.arrange.tidy` (P2) | Figma "tidy up": snap a near-grid to an even grid | — |

Each is one undo step naming `x,y` (and `width,height` for match size).

### 5.6 Rulers and guides (P1)

- View › Show › *Rulers* (`slides.view.toggleRulers`, ⌥⇧⌘R / Ctrl+Alt+Shift+R — ⇧⌘R reloads the page in browsers): su scale with
  selection extent highlighted.
- **Drag from a ruler** creates a guide (vertical from the left ruler, horizontal from the top);
  drag a guide off the slide to delete; double-click a guide → position input. Guides are stored
  per deck in `Deck.guidesJson` (§20) — a whole-value JSON (`[{"axis":"v","at":960}]`), one undo
  step per change, commands `slides.guides.add {axis, at}`, `slides.guides.move`,
  `slides.guides.delete`, `slides.guides.clear`. Guides are drawn in token `slidesUserGuide`
  (teal) and hidden when presenting/printing.
- Master/layout guides (P2): guides of the slide's layout are shown dashed.

---

## 6. Element kinds

### 6.1 Text

**Create**: Insert › Text box (`slides.insert.textBox`, key **T** in the canvas scope). The next
click on the slide creates an auto-width box (`wrap: false`) at that point with the caret inside;
a drag creates a fixed-width box (`wrap: true`) of the dragged width. Keyboard creation: the
command with no pointer inserts a 960 × 120 su box at the slide center. Default style: theme
`shapeStyle.text` (05 §2.7), `autofit: resize`. An empty text box that loses editing is **deleted**
(part of the same undo step as its creation).

**Editing engine**: one `SlideTextEditor` at a time — the vendored `super_editor` configured as a
shrink-wrapped, non-scrolling editor whose document maps 1:1 to the Slides Delta schema (02 §4.1)
through a `SlidesDeltaMapper` (paragraphs, list items, tasks; attributions for every inline
attribute). It sits as an overlay exactly over the element's text rectangle (rotation and flip
applied via a transform), so the caret and selection align with the static rendering. Static text
(non-edited bodies, thumbnails, presenting) is painted by the scene painter from the same resolved
styles; golden tests assert identical line breaks between both (§22).

**Decided (v2 review, Q20): super_editor overlay.** The vendored super_editor
(IME/selection/clipboard proven in Write, spellcheck integration exists) is the text editor of
text boxes, confirmed by a timeboxed spike at the start of M9 (Slides 12 work package SL-4)
measuring open-editor latency (< 50 ms target) and the line-break equality test. Only if the
spike fails both does the fallback — a custom `EditableText`-based rich editor (lighter, but IME,
multi-paragraph selection, lists and RTL rebuilt) — get a decision record.

**Behavior**:

| Feature | Behavior | Command |
|---------|----------|---------|
| Bold / italic / underline / strike | Toggle on selection; collapsed caret sets typing attributes | `slides.format.bold` ⌘B, `…italic` ⌘I, `…underline` ⌘U, `…strikethrough` ⇧⌘X |
| Font, size, color, highlight | Toolbar/inspector; size steps 8 10 12 14 18 24 28 32 36 40 48 56 64 72 96 120 144 200 | `slides.format.font {family}`, `…fontSize {size}`, `…increaseFontSize` ⇧⌘. / `…decreaseFontSize` ⇧⌘, , `…textColor {color}`, `…highlight {color}` |
| Superscript / subscript | | `slides.format.script {value: super\|sub\|none}` ⌘. / ⌘, |
| Capitalization | All caps, Small caps, Title case, None | `slides.format.caps {value}` |
| Letter spacing, line spacing, space before/after | Inspector › Text | `slides.format.letterSpacing`, `…lineHeight`, `…paragraphSpacing {before?, after?}` |
| Alignment | Left/center/right/justify | `slides.format.align {value}` ⇧⌘L / ⇧⌘E / ⇧⌘R / ⇧⌘J |
| Vertical anchor | Top/middle/bottom | `slides.format.anchor {value}` |
| Lists | Bulleted ⇧⌘8, numbered ⇧⌘7, checklist ⇧⌘9; Tab / Shift+Tab indent/outdent list items (and plain paragraphs, levels 0–8); list style picker (bullets glyphs, numbering styles, start number) | `slides.format.list {type}`, `…indent`, `…outdent`, `…listStyle {style}`, `…listStart {n}` |
| Autoformat | `- `, `* ` → bullet; `1. ` → numbered; `[ ] ` → checklist; `--` → em dash (P1); smart quotes (P1, Settings › Slides) | — (typing) |
| Paragraph style | Apply a theme text style (Title, Subtitle, Heading, Body, Body 2, Caption, Quote, Attribution, Big number, Label) | `slides.format.textStyle {key}` ⌥⌘1…⌥⌘9 in that order (Label has none) |
| Links | Mod+K opens the link popover: URL, or **Slide in this deck** (searchable list), *Remove* | `slides.insert.link {url? \| slideId?}`, `slides.text.removeLink` |
| Auto-fit | Do not autofit / Shrink text on overflow / Resize shape to fit text | `slides.format.autofit {mode}` |
| Text insets | Inspector › Text › Insets | `slides.format.insets {t,r,b,l}` |
| Clear formatting | Removes inline attributes (keeps paragraph lists) | `slides.format.clear` ⌘\ |
| Soft line break | Shift+Enter inserts U+2028 | — |
| Exit editing | Esc (selects the box), clicking outside, Mod+Enter (P1: same) | `slides.text.exitEditing` |

Applying a format command with **element(s) selected but not editing** applies it to **all text**
of every selected text-capable element (one undo step; bodies soft-locked by others are skipped
with a toast "Skipped 1 text box Anna is editing").

**Overflow**: with `autofit: none`, text that overflows is drawn beyond the box; in the editor a
small red `+` badge marks overflow (P1). **Shrink**: derived scale (02 §5.1), shown in the
inspector as "Text shrunk to 85 %". **Resize**: effective height grows; the selection box follows.

**Undo**: typing bursts coalesce (suite 08 §3.1 rule 4) and are persisted after 300 ms idle and on
exit (02 §4.4) — one step "Typing" per burst; formatting commands are one step each.

### 6.2 Placeholders

- Instances inherit frame and style from their layout placeholder until changed; the inspector
  shows "From layout: Title" with **Reset to layout** (`slides.element.resetPlaceholder`).
- Empty text placeholders show **prompt text** (from the layout placeholder's prompt, default
  "Click to add title" / "Click to add text" / "Click to add subtitle"); never presented,
  thumbnailed or exported.
- Picture/chart/table/code placeholders show an icon button in the center: click opens the
  matching insert flow; the inserted element takes the placeholder's frame and becomes the
  placeholder's instance (`placeholderOf`), so a later layout change moves it with the layout.
- Deleting a placeholder instance's content leaves the empty placeholder; deleting the
  (selected) empty placeholder removes it from the slide (it can be restored with *Reset slide*).

### 6.3 Shapes

**Library** (`Insert › Shape ▸`, toolbar shape menu; `slides.insert.shape {geometry}`; key **S**
repeats the last shape, P1):

| Category | Shapes (geometry keys) | Pri |
|----------|------------------------|-----|
| Basic | rect, roundRect, ellipse, triangle, rightTriangle, diamond, pentagon, hexagon, octagon, parallelogram, trapezoid, donut, arc, blockArc, pie, chord, frame, halfFrame, plus, cross, cylinder, cube, can, heart, cloud, moon, sun, lightning | P0 (first 12), P1 rest |
| Arrows | arrowRight, arrowLeft, arrowUp, arrowDown, arrowLeftRight, arrowUpDown, chevron, homePlate, notchedArrow, curvedArrow, circularArrow, uTurn | P0 (first 6), P1 |
| Stars & badges | star4, star5, star6, star8, star12, burst, ribbon, wave, seal | P1 |
| Callouts | speech, speechRound, thought, calloutRect, calloutLine, banner | P0 (speech, calloutRect), P1 |
| Flowchart | process, decision, terminator, document, data, manualInput, predefinedProcess, connector, offPage, delay, storage | P1 |
| Brackets | brace, bracket, doubleBrace | P1 |
| Custom | `custom` (SVG path; created by pasting SVG paths, P2 edit points) | P2 |

**Drawing**: after choosing a shape the cursor becomes a crosshair; click inserts at 240 × 240 su
(arrows 320 × 160), drag sizes it (Shift = 1:1, Alt from center). Esc cancels the tool. One undo
step "Insert shape". Default style: theme `shapeStyle.shape` (accent1 fill, no stroke).

**Adjust handles**: yellow diamonds (`slidesAdjustHandle`) for geometry parameters (corner radius,
arrow head size, star inner radius…); dragging writes `dataJson.adjust` on release.

**Change shape** (`slides.shape.change {geometry}`): keeps frame, text, style, builds, matchKey.

**Quick styles** (P1): a row of 8 theme-based styles (solid accent fills 1–6, outline, soft tint)
in the toolbar fill menu (`slides.shape.applyQuickStyle {index}`).

Text in shapes: double-click/Enter/typing edits; defaults `anchor: middle`, `align: center`,
`autofit: shrink`.

### 6.4 Lines, arrows and connectors

- Tools: **Line** (L), **Arrow**, **Elbow connector**, **Curved connector** (P1), all under
  Insert › Line ▸ (`slides.insert.line {routing, arrow}`). Drag from start to end; Shift snaps to
  45°. Click without drag inserts a 400 su horizontal line.
- **Connection sites**: hovering a shape with a line tool (or dragging an endpoint) shows its sites
  as small circles (top, right, bottom, left, center + geometry-specific); dropping on a site
  **glues** the endpoint (`connect: {elementId, site}`), on the shape body glues to the nearest
  site. Glued endpoints follow the shape when it moves (derived routing, 02 §6.3); selection shows
  glued endpoints as filled green dots, free ones as hollow.
- **Elbow routing**: orthogonal path avoiding the two connected shapes' boxes with 24 su clearance;
  a midpoint handle per segment moves it (stored as `waypoints`).
- Endpoint handles replace the resize box for single lines; rotation handle hidden (angle comes
  from endpoints).
- Arrowheads, width, dash, color, cap in toolbar/inspector (`slides.line.setArrow {end, style}`,
  `slides.format.stroke {…}`).
- Deleting a connected shape leaves its connectors with the last stored endpoint.

### 6.5 Images

#### 6.5.1 Insert

| Source | Flow | Command |
|--------|------|---------|
| Upload | `file_picker` (png, jpg, jpeg, gif, webp, svg, bmp) → upload | `slides.insert.image {source: upload}` |
| Drag & drop | From the OS onto the canvas (web drop zone; `desktop_drop` deferred with desktop, suite 01 A13); several files insert cascaded | — |
| Paste | Image data from the OS clipboard (§12.5) | `shell.edit.paste` |
| Wonky Drive | Drive picker filtered to images (D2 `file` kind) → server copies the file into the deck | `slides.insert.image {source: drive, fileItemUuid}` |
| By URL | URL dialog; fetched through the server image proxy (`files.fetchImage`, generalized from Sheets' `sheets.fetchImage`; SSRF rules of suite 13) and stored as an upload | `slides.insert.image {source: url, url}` |
| Placeholder | Picture placeholder button or drop onto a picture placeholder (fills and crops to cover) | — |

- Uploads go through `FileEndpoint` with a client-generated `fileUuid` (suite 12 §1.1);
  `src = wonky-file://<fileUuid>`. Offline: bytes in `LocalPendingUpload` (render from local bytes,
  upload with backoff). Quota (D3) is checked before upload: over quota →
  *"You're out of storage — free up space in Wonky Drive"* dialog, nothing inserted.
- Size: natural size at 1 px = 1 su, scaled down to fit 80 % of the slide; placed centered (or at
  the drop point). Images > 40 MP are downscaled client-side to 40 MP (JPEG q 0.9 / PNG); SVG is
  rasterized at 2× its intrinsic size (max 4096 px) and the SVG kept as the original (P2: vector
  SVG rendering); BMP → PNG; animated GIFs animate in the editor and presenting (first frame in
  PDF/thumbnails).
- Unsupported/corrupt file → toast "Couldn't insert 'x.heic' — this image type isn't supported."

#### 6.5.2 Replace and reset

- *Replace image* (`slides.image.replace {source}`) keeps frame, crop proportions (re-fit to cover
  the same frame), mask, adjustments, builds and matchKey.
- *Reset image* (`slides.image.reset`) clears crop, mask and adjustments and restores natural
  aspect (keeps width).

#### 6.5.3 Mask

*Mask with shape ▸* (`slides.image.mask {geometry}`): any basic shape; adjust handles of the shape
apply. `mask: null` removes. Masking draws the image clipped to the geometry inside the frame.

#### 6.5.4 Crop mode

Double-click (or `slides.image.crop`, Enter on a selected image): the full image appears dimmed
outside the crop rectangle; drag the **crop handles** to change the visible area, drag the image
to reposition it inside the frame, aspect presets in a floating bar (Free, Original, 1:1, 4:3,
16:9, 3:2, 9:16), **Fill** / **Fit** buttons. Enter or clicking outside commits (one undo step
"Crop image", writes `dataJson.crop` and frame); Esc cancels.

#### 6.5.5 Adjustments (P1)

Inspector › Image: sliders Brightness, Contrast, Saturation, Temperature (−100…100), Blur (0…40),
toggles Grayscale/Sepia/Invert; *Reset adjustments*. Live preview while dragging; written on
release (`slides.image.adjust {…}`); applied with a `ColorFilter` matrix on screen and baked into
PDF images by the core renderer (same matrix math, 10).

#### 6.5.6 Other

Alt text (§17.1), transparency (`opacity`), shadow/border via common style, *Download original*
(`slides.image.downloadOriginal`, needs download permission).

### 6.6 Tables

- **Insert**: Insert › Table ▸ `WonkyTableSizePicker` (suite 02 §4.10; up to 20 × 20; larger tables up to 50 rows × 20 columns through the command's arguments in the palette) →
  `slides.insert.table {rows, cols}`; default width 80 % of the slide, row height from the theme
  body size; style `theme`.
- **Cell selection**: click into a cell edits its text; drag across cells or Shift+arrows (from
  `slidesTable` scope) selects a cell range (highlight `slidesTableSelection`). Esc from editing
  selects the cell; Esc again selects the table.
- **Keyboard**: Tab / Shift+Tab next/previous cell (Tab in the last cell adds a row,
  `slides.table.insertRow {below}`), arrows at text edges move between cells, Enter in range
  selection edits the active cell.
- **Structure** (context menu, inspector, `slides.table.*`): insert row above/below
  (`insertRow {above|below, count}`), insert column left/right, delete rows/columns, delete
  table, **merge cells** / unmerge (P1), distribute rows/columns evenly, resize by dragging inner
  borders (writes axis `size`, one step), header row / first column / banded rows / banded
  columns / total row toggles (`slides.table.setOptions {…}`).
- **Cell formatting**: fill (`slides.table.setCellFill`), borders (`TableBorderPicker`: all,
  outer, inner, horizontal, vertical, top, bottom, left, right, none + width/style/color →
  `slides.table.setBorders`), vertical align, padding; text formatting applies to selected cells'
  whole text (like §6.1 element-level formatting).
- **Paste**: TSV/HTML tables or Sheets cells into a selected cell range fill cells from the
  active cell, adding rows/columns up to the limit (§12.4).
- Rows grow to fit text (derived); the table's frame height is the minimum (02 §6.5).

### 6.7 Icons and emoji

- **Icon picker** (`slides.insert.icon` → dialog, 04 §13.6): search over the Lucide set (~1,600
  icons, names + tags), categories, recently used, stroke width (1–3), color (theme colors). Insert
  as a 160 × 160 su `icon` element (aspect locked), stroke color `theme:text1` by default.
- **Emoji** (P1): emoji picker (shared widget, extracted from Write's emoji feature to
  `wonky_ui`, suite agent) → `slides.insert.emoji {char}` as an `icon` element with `set: emoji`
  (240 su). Emoji typed inside text stay text.
- Double-click an icon → picker to replace (keeps frame, color, builds).

### 6.8 Code and charts (object behavior)

Code and chart elements select, move, resize, rotate (code: rotation allowed but discouraged —
the inspector warns), group, lock and z-order like other elements. Content editing: code →
[07](07-code-blocks.md) (`slides.code.*`), charts → [08](08-charts-from-sheets.md)
(`slides.chart.*`). Insert commands: `slides.insert.code {language?}` (placement per 07 §3.4),
`slides.insert.chartFromSheets` and `slides.insert.chart {type}` (native, P1).

### 6.9 Element links and actions

Inspector › Link (or Mod+K with an element selected): *URL*, *Slide* (picker), *Next slide*,
*Previous slide*, *First/Last slide*, *End show* → `linkJson`
(`slides.element.setLink {…}` / `removeLink`). Presenting: clicking the element follows the link
(external URLs use the external-link confirm of suite 03 §1 — not in an audience view: they
open on the presenter's screen, 10). The editor shows a small link badge on hover.

---

## 7. Element groups

- **Group** (`slides.arrange.group`, ⌥⌘G / Ctrl+Alt+G, and contextual **Mod+G** in the canvas
  scope with ≥ 2 elements selected): creates a `group` element at the max zKey of the members,
  with `childBounds` = the members' union box; children keep their visual position (frames
  converted to child space — identity at creation). One undo step "Group".
- **Ungroup** (`slides.arrange.ungroup`, ⌥⇧⌘G / Ctrl+Alt+Shift+G, and **Mod+Shift+G** in the
  canvas scope): bakes the group transform into each child, inserts the children at the group's
  z position (keeping their relative order), deletes the group. Builds targeting the group are
  **deleted** with a toast "Ungrouping removed 2 animations" (one undo step restores everything).
- Groups nest (depth ≤ 8). Placeholders cannot be grouped (command disabled with reason).
- Transforms apply to the group frame; children keep relative layout. Group opacity multiplies.
- Selecting inside a group (§3.2) and editing children (text, style) writes only the child.
- Magic Move matches groups by `matchKey` as one unit; children with their own `matchKey`s match
  individually only when both slides contain the same group (06).

---

## 8. Lock, hide, z-order, Layers panel

### 8.1 Layers panel (P1; `slides.panel.layers`)

Side panel listing the current slide's elements as a tree (front-most at the top), each row:
kind icon, name (double-click to rename → `slides.element.rename`), eye (hide) and lock toggles.
Rows are drag-reorderable (`slides.arrange.setZ {id, before|after}`), nested under groups
(dragging into/out of a group regroups, one step). Clicking selects (also locked/hidden
elements). A collapsed section *From layout* lists layout/master elements read-only with
*Edit layout* link. A tab **Reading order** (P1) shows the reading order list (§17.2).

### 8.2 Lock and hide

- `slides.element.lock` / `unlock` (⌥⇧⌘L / Ctrl+Alt+Shift+L toggles), `slides.element.unlockAll`
  (Arrange menu). Locked: not hit by clicks/marquee on the canvas, cannot be moved/resized/deleted
  from the canvas; selectable from the Layers panel (then properties are editable but transform
  handles show a lock badge instead). Locked state is shared (synced), like Google/PowerPoint
  lock behaviors in team templates.
- `slides.element.hide` / `show`: hidden elements are not drawn (editor, present, PDF,
  thumbnails) and not hit; visible only as rows in the Layers panel (dimmed). Builds of hidden
  elements are skipped.

### 8.3 Z-order

| Command | Effect | Shortcut |
|---------|--------|----------|
| `slides.arrange.order {op: bringToFront}` | `zKey = after(max sibling)` | ⌥⇧⌘↑ / Ctrl+Alt+Shift+↑ |
| `… {op: bringForward}` | Move above the next **overlapping** sibling above (`between` its key and the next) | ⇧⌘↑ / Ctrl+Shift+↑ (canvas scope) |
| `… {op: sendBackward}` | Below the next overlapping sibling below | ⇧⌘↓ / Ctrl+Shift+↓ |
| `… {op: sendToBack}` | `zKey = before(min sibling)` | ⌥⇧⌘↓ / Ctrl+Alt+Shift+↓ |

Multi-selection keeps relative order (`nBetween`). Master/layout elements are always behind slide
elements (layers are separate); placeholders participate in slide z-order like other elements.
Each is one undo step writing only `zKey`.

> Shortcut note: Align uses ⌥⌘+arrows (§5.5), order uses ⇧⌘+arrows and ⌥⇧⌘+arrows, nudge uses
> plain/Shift arrows. Slide reordering (⌘↑/⌘↓) is only bound in the navigator scope (04 §5.9).

---

## 9. Format painter and copy/paste style

- **Paint format** (`slides.format.paintFormat {sticky}`, toolbar brush; double-click = sticky):
  copies the style of the selected element (or of the text at the caret) and applies it to the
  next clicked element or selected text. Sticky stays armed until Esc or clicking the brush.
- What is copied, by target:

| Source → target | Copied |
|-----------------|--------|
| Element → element (any kinds) | `fillJson`, `strokeJson`, `effectsJson`, `opacity`; for text-capable targets also `textStyleJson` (including insets and auto-fit) and the dominant run + paragraph attributes applied to all text |
| Text selection → text selection | Inline attributes (font, size, weight, color, highlight, bold/italic/underline/strike, caps, letter spacing) and, when whole paragraphs are selected, paragraph attributes (style, align, list, spacing) |
| Image → image | Mask, adjustments, stroke, effects, opacity (not crop) |
| Table cell(s) → cells | Fill, borders, padding, vertical align, text attributes |
| Line → line | Stroke incl. arrowheads |

- **Copy style / Paste style** (`slides.format.copyStyle` ⌥⌘C, `slides.format.pasteStyle` ⌥⌘V,
  Keynote): same payload kept in an in-app style clipboard (not the system clipboard); paste
  applies to every selected element. Each application is one undo step "Paste style".

---

## 10. Keyboard map (canvas, text, table)

macOS / Windows-Linux. Browser-reserved chords are never bound (suite 08 §1.2). Navigator and
presenting keys: [04 §5.9](04-screens-menus-toolbar.md), [10](10-presenting-and-pdf.md).

| Action | macOS | Win/Linux | Scope | Command |
|--------|-------|-----------|-------|---------|
| Undo / Redo | ⌘Z / ⇧⌘Z | Ctrl+Z / Ctrl+Y, Ctrl+Shift+Z | global | `shell.edit.undo` / `redo` |
| Cut / Copy / Paste | ⌘X / ⌘C / ⌘V | Ctrl+X / C / V | canvas, text, table | `shell.edit.*` |
| Paste without formatting | ⇧⌘V | Ctrl+Shift+V | canvas, text | `shell.edit.pasteWithoutFormatting` |
| Duplicate | ⌘D | Ctrl+D | canvas | `slides.edit.duplicate` |
| Delete | ⌫ / ⌦ | Backspace / Delete | canvas | `slides.edit.delete` |
| Select all | ⌘A | Ctrl+A | canvas, text, table | `shell.edit.selectAll` |
| Next / previous element | Tab / ⇧Tab | Tab / Shift+Tab | canvas | `slides.select.next` / `previous` |
| Activate (edit text, enter group, crop) | Enter | Enter | canvas | `slides.element.activate` |
| Exit / deselect | Esc | Esc | all | `slides.select.escape` |
| Nudge 1 / 10 su | arrows / ⇧arrows | arrows / Shift+arrows | canvas | `slides.element.nudge` |
| Group / ungroup elements | ⌘G or ⌥⌘G / ⇧⌘G or ⌥⇧⌘G | Ctrl+G or Ctrl+Alt+G / Ctrl+Shift+G or Ctrl+Alt+Shift+G | canvas | `slides.arrange.group` / `ungroup` |
| Bring forward / send backward | ⇧⌘↑ / ⇧⌘↓ | Ctrl+Shift+↑ / ↓ | canvas | `slides.arrange.order` |
| Bring to front / send to back | ⌥⇧⌘↑ / ⌥⇧⌘↓ | Ctrl+Alt+Shift+↑ / ↓ | canvas | `slides.arrange.order` |
| Align left/right/top/bottom | ⌥⌘← → ↑ ↓ | Ctrl+Alt+arrows | canvas | `slides.arrange.align` |
| Lock / unlock | ⌥⇧⌘L | Ctrl+Alt+Shift+L | canvas | `slides.element.toggleLock` |
| Text box / shape / line tools | T / S (last shape) / L | same | canvas | `slides.insert.textBox` / `shape` / `line` |
| Insert link | ⌘K | Ctrl+K | canvas, text | `slides.insert.link` |
| Comment | ⌥⌘M | Ctrl+Alt+M | canvas, text | `shell.comments.create` |
| Alt text | ⌥⌘Y | Ctrl+Alt+Y | canvas | `slides.element.editAltText` |
| Paint format / copy style / paste style | — / ⌥⌘C / ⌥⌘V | — / Ctrl+Alt+C / Ctrl+Alt+V | canvas, text | `slides.format.paintFormat` / `copyStyle` / `pasteStyle` |
| Bold / italic / underline / strikethrough | ⌘B / ⌘I / ⌘U / ⇧⌘X | Ctrl+B / I / U / Alt+Shift+5 | canvas, text, table | `slides.format.*` |
| Font size bigger / smaller | ⇧⌘. / ⇧⌘, | Ctrl+Shift+. / , | canvas, text | `slides.format.increaseFontSize` / `decrease…` |
| Superscript / subscript | ⌘. / ⌘, | Ctrl+. / Ctrl+, | text | `slides.format.script` |
| Align text left / center / right / justify | ⇧⌘L / E / R / J | Ctrl+Shift+L / E / R / J | canvas, text | `slides.format.align` |
| Bulleted / numbered / checklist | ⇧⌘8 / ⇧⌘7 / ⇧⌘9 | Ctrl+Shift+8 / 7 / 9 | canvas, text | `slides.format.list` |
| Indent / outdent | Tab / ⇧Tab (lists), ⌘] / ⌘[ | Tab / Shift+Tab, Ctrl+] / Ctrl+[ | text | `slides.format.indent` / `outdent` |
| Text style 1–9 | ⌥⌘1…9 | Ctrl+Alt+1…9 | text, canvas | `slides.format.textStyle` |
| Clear formatting | ⌘\ | Ctrl+\ | canvas, text | `slides.format.clear` |
| Zoom fit / in / out | ⌥⌘0 / ⌥⌘= / ⌥⌘− | Ctrl+Alt+0 / = / − | global | `slides.view.zoom*` |
| Find / find and replace | ⌘F / ⇧⌘H | Ctrl+F / Ctrl+H | global | `slides.find.open` / `openReplace` |
| Present / from start | ⌘Enter / ⇧⌘Enter | Ctrl+Enter / Ctrl+Shift+Enter | canvas, navigator | `slides.present.fromCurrent` / `fromStart` (10) |
| New slide | ⌃M (⌘M minimizes the window on macOS) | Ctrl+M | global | `slides.slide.new` |
| Previous / next slide | PgUp / PgDn (canvas), ↑/↓ (navigator) | same | canvas, navigator | `slides.nav.previousSlide` / `nextSlide` |
| Pan | Space+drag | Space+drag | canvas | — |
| Command palette | ⇧⌘P | Ctrl+Shift+P | global | `shell.nav.commandPalette` |

---

## 11. Edit commands (non-menu details)

- `slides.edit.delete`: canvas → delete selected elements (and their builds, cascade); text →
  delete selection; navigator → delete slides (04 §5.7). One step.
- `slides.edit.duplicate`: elements → copies offset +32 su (or by the last duplicate's offset if
  the user moved the previous duplicate — Keynote "smart duplicate", P1); navigator → duplicate
  slides/groups (04).
- `matchKey` rules (06 §8.2): duplicating elements **on the same slide** regenerates their
  `matchKey`; duplicating slides and copying/pasting elements **to another slide** keeps it, so
  Magic Move matches them across slides.

---

## 12. Clipboard

### 12.1 Representations written on copy

| Format | Content | When |
|--------|---------|------|
| `application/x-wonky-slides` (JSON, §12.2) | Lossless payload | Always (in-app store on web + text marker; custom format on desktop via `super_clipboard`) |
| `text/plain` | Text of the selection (elements: their text in reading order; slides: titles and body text as an outline) | Always |
| `text/html` | Rich text (text selections, tables as `<table>`) | P1 |
| `image/png` | Selection rendered at 2× (elements) / the slide (slides, first one) | Copy of elements/slides when the platform supports image clipboard (web Clipboard API, macOS) |
| `text/markdown` marker | Slides outline as Markdown for Write (`# Title` + bullets) | Slides copies |

### 12.2 Payload `application/x-wonky-slides` v1

```jsonc
{
  "format": "wonky-slides-clipboard", "v": 1,
  "sourceDeckId": "…", "sourceItemUuid": "…", "sourceSlideId": "…",   // element copies
  "kind": "elements" | "slides" | "groups" | "text",
  "themes":   [ { /* DeckTheme row */ "masters": [ … ], "layouts": [ … ], "elements": [ … ] } ],  // only themes used by copied slides
  "groups":   [ { "id", "title", "color", "skipped", "slides": ["<slideId>", …] } ],
  "slides":   [ { /* Slide row */ } ],
  "elements": [ { /* SlideElement row */ } ],
  "tableAxes": [ … ], "tableCells": [ … ], "builds": [ … ], "codeStates": [ … ], "chartLinks": [ … ],
  "files":    [ { "fileUuid", "itemUuid", "mimeType", "size" } ],   // uploaded files referenced by src/fill
  "text":     { "delta": [ … ] }                                     // kind = text (text selection)
}
```

Built and parsed by `SlidesClipboardCodec` (core). Ids are remapped on paste by the same remapper
as `DeckCopier` (02 §9.3) — every paste produces fresh ids (and fresh deterministic ids);
`matchKey`s are kept, except when elements are pasted onto the slide they were copied from (then
regenerated, 06 §8.2).

### 12.3 Paste rules

| Target | Payload | Result |
|--------|---------|--------|
| Canvas (no text editing) | elements | Inserted on the current slide at the **same positions** if pasted onto another slide; offset +32 su on the same slide (repeated pastes cascade). Above all elements, selected. |
| Canvas | slides/groups | Inserted as slides **after the current slide** (same as navigator paste) |
| Navigator (slide/group selected or insertion point) | slides/groups | After the selection / at the insertion point (04 §5.8); groups arrive as groups (title, color, skip) with their slides |
| Navigator | elements | Disabled ("Paste objects on a slide") |
| Text editing | text / elements with text | Rich text inserted at the caret (schema-filtered); objects without text ignored |
| Table cell range | TSV/HTML/Sheets cells | Fills cells (§6.6) |

**Cross-deck paste** (source deck ≠ target deck):

- **Themes**: slides keep their layout by **mapping** to the target's default theme: same layout
  `key` → that layout; else best placeholder-signature match; else `titleBody`/`blank`
  ("**Use destination theme**", default). A floating **paste options chip** (bottom-right of the
  pasted range, 10 s) offers **Keep source formatting**: re-runs the paste (replacing the same undo
  step, `UndoService.replaceLast`) bringing the source theme copy (deterministic `themeCopyId`, so
  repeated pastes from one deck share one theme copy).
- Elements pasted cross-deck keep explicit colors; `theme:` color refs resolve against the target
  theme (that is the point of "use destination theme").
- **Files**: each referenced `wonky-file://` is re-homed into the target deck with
  `FileEndpoint.copyToItem(sourceFileUuid, newFileUuid, targetItemUuid)` (idempotent on
  `newFileUuid`, quota-checked — §20); `src` is rewritten to the new uuid immediately and the copy
  is queued offline (renders from the source URL meanwhile if cached). A quota failure removes the
  image with a toast.
- **Linked charts** stay linked (`ChartLink` copied with the new element id).
- **Comments** are never copied. **Builds** and **code states** are copied with their elements;
  builds whose element isn't copied are dropped.
- Permissions: copying from a deck whose owner disallowed copying for viewers is blocked at copy
  time (the copy command is disabled).

### 12.4 From Write and Sheets

| Source (clipboard format) | Paste on canvas | Paste into text editing |
|---------------------------|-----------------|-------------------------|
| Write text (`application/x-wonky-write` Delta, or `text/markdown`) | New text box: headings → `heading` style paragraphs (H1 → title-sized), lists keep nesting/checklists, bold/italic/strike/inline code/links mapped; **Write images** → image elements below the text box; **Write tables** → table element; **code blocks** → code element (language kept) | Inline attributes and lists mapped; headings → `heading` style; embeds ignored |
| Sheets cells (`application/x-wonky-sheets` or TSV/HTML) | **Table element** with values as displayed (formatted text), bold/italic/colors/fills/alignment mapped, merges kept; > 50 × 20 truncated with toast "Only the first 50 rows and 20 columns were pasted" | Tab-separated text |
| Sheets chart object (`application/x-wonky-sheets-objects` with spreadsheet item uuid + object id) | **Linked chart** (08) with *Paste unlinked* in the paste options chip | — |
| Sheets image object | Image element | — |

The Sheets object payload must carry `spreadsheetItemUuid` and `objectId` (addition to Sheets 08
§9.5, §20).

### 12.5 From the OS and other apps

| Format | Result |
|--------|--------|
| Image data / image files | Image element(s) (§6.5) |
| `text/html` (P1) | Rich text mapped to the schema (fonts dropped unless bundled, sizes converted px→su ×1.33, colors kept); `<table>` → table element; `<img>` with http(s) src → images via the proxy |
| `text/plain` | Text box (paragraphs per line; lines starting with `- `/`* `/`1. ` become lists) |
| SVG text (`<svg …`) | Image (rasterized; P2: shapes) |
| URL only | Text box with the link (P2: link card) |

*Paste without formatting* (⇧⌘V) pastes plain text into the editing body or a new text box with
the theme body style.

---

## 13. Find and replace

- `slides.find.open` (⌘F) opens a compact find bar at the top-right of the canvas;
  `slides.find.openReplace` (⇧⌘H) the full non-modal dialog (`WonkyDialogSpec`, MCP-operable):
  fields `find`, `replace`, `matchCase`, `wholeWords`, `useRegex`, `includeNotes` (default on),
  `includeSkipped` (default on), `scope` (All slides / Current slide / Selected slides); buttons
  [Previous] [Next] ("3 of 12"), [Replace], [Replace all], [Done].
- Searches every text body in presentation order: slide elements (reading order), table cells,
  code text (P1, off by default: `includeCode`), notes, group titles (P1). Master/layout text only
  in master editing mode.
- Matches highlight with `findMatch` / `findMatchActive` tokens on the canvas and in notes; Next
  navigates to the slide and selects the match (enters text editing on it).
- *Replace all* = one undo step "Replace all" (toast "Replaced 12 instances of 'x' with 'y'");
  bodies soft-locked by others are skipped and reported ("2 matches in text Anna is editing were
  skipped").

---

## 14. Spell check (P1)

- Uses the suite's shared spell engine (Write's Hunspell engine in the pure-Dart
  `wonky_spellcheck` package and the `SpellEngine` glue in `wonky_app`, extracted in M8, §20) with the
  same dictionaries and the user's personal dictionary (`UserPreferences`).
- Language: `Deck.language` ?? user locale; per-paragraph `lang` is not supported.
- Squiggles (token `spellingError`) under misspelled words in the **body being edited**, and on
  the canvas for visible text boxes of the current slide when *Tools › Spelling › Underline
  errors* is on (`slides.spelling.toggleUnderline`, default on).
- Context menu on a misspelling: up to 5 suggestions, *Ignore*, *Add to dictionary*.
- *Tools › Spelling › Check spelling* (`slides.spelling.check`): steps through errors deck-wide in
  a small dialog (Change / Change all / Ignore / Ignore all / Add) — one undo step per change.

---

## 15. Undo granularity summary

| Gesture | Steps |
|---------|-------|
| Drag move / resize / rotate (any number of elements) | 1 on drop |
| Nudge burst ≤ 1 s apart | 1 |
| Typing burst in one body | 1 per burst (suite rule) |
| Formatting command | 1 |
| Insert (incl. upload) | 1 (the upload completes later without another step) |
| Paste (any payload), paste-options switch | 1 (switch replaces it) |
| Crop session | 1 on commit |
| Table structure op / cell format | 1 each |
| Group / ungroup / align / distribute / z-order | 1 each |
| Format painter application | 1 per application |
| Find & replace all | 1 |
| Selection, zoom, scroll, panels | 0 (view state) |

---

## 16. View mode (viewers and commenters)

Canvas shows the slide; elements are selectable (no handles) for reading alt text, copying (if
allowed) and commenting (commenters); text can be selected and copied when copying is allowed;
links open with the external-link confirm. Mutating commands are disabled with the role reason.

---

## 17. Accessibility

### 17.1 Alt text

- *Alt text…* (`slides.element.editAltText`, ⌥⌘Y): dialog with `altText` (textarea, 1,000 chars),
  *Mark as decorative* checkbox (`decorative`), and **Generate with AI** (11, when AI is enabled).
  One undo step. Images, icons, charts (default: chart describer summary, 08), shapes without text
  and groups take alt text; text elements use their text.

### 17.2 Reading order

- Automatic order (when no element on the slide has `readingKey`): title placeholder, subtitle,
  then the remaining elements by **visual rows** (elements whose vertical centers are within
  10 % of the slide height form a row; rows top→bottom, left→right inside a row; RTL decks
  right→left), then slide number/footer/date last; decorative and hidden elements excluded.
- Override: Layers panel › *Reading order* tab (and the accessibility checker) — drag rows; the
  first drag writes `readingKey` for every element on the slide (`slides.a11y.setReadingOrder
  {ids}`, one step). *Reset to automatic* clears them.
- Used by: Tab cycling, the semantics tree, screen-reader presenting (10), PDF tagging (10),
  copying slides as text, MCP `slides.get_slide` text order.

### 17.3 Semantics and announcements

- The canvas exposes one semantics node per element in reading order: role (text, image, button
  for linked elements), label (`"Title: Q3 results"`, `"Image: <alt text>"`, `"Chart: <alt>"`,
  `"Table, 4 rows, 3 columns"`), value (text content, truncated 200 chars), state (selected,
  locked, hidden).
- Announcements (`SemanticsService.announce`): selection changes ("Rectangle 2 selected, 3 of 7
  objects"), moves after drop ("Moved to x 120, y 340"), slide change ("Slide 4 of 24, Intro
  group: Our mission"), soft-lock refusals.
- Keyboard-only creation: insert commands place elements at the slide center and select them; all
  transforms are reachable via nudge and the inspector's numeric fields.
- Focus: visible `ring` on the focused region (navigator, canvas, inspector, notes);
  `shell.focus.nextRegion` (F6) cycles toolbar → navigator → canvas → inspector → notes.

### 17.4 Accessibility checker (P1)

`slides.tools.accessibilityCheck` opens the side panel `slides.panel.accessibility` listing issues
by slide with *Fix* actions:

| Rule | Severity | Fix |
|------|----------|-----|
| Image/icon/chart without alt text (not decorative) | Error | Alt text dialog (Generate with AI) |
| Text contrast < 4.5:1 (< 3:1 for text ≥ 32 su bold / 40 su) against its resolved background (fill, else slide background; images: sampled average, warning only) | Error | Select element |
| Slide without a title (no title placeholder text and no `heading`-style paragraph) | Warning | Edit slide |
| Duplicate slide titles | Warning | — |
| Text smaller than 18 su | Warning | Select |
| Reading order differs strongly from visual order (custom order) | Info | Reading order tab |
| Table without header row | Warning | Toggle header row |

---

## 18. Performance budgets

| Scenario | Budget |
|----------|--------|
| Open a cached 200-slide deck to first slide painted | < 800 ms desktop, < 1.5 s web |
| Switch slide (navigator click) to painted | < 50 ms (p95) for slides ≤ 100 elements |
| Drag/resize 50 selected elements | 60 fps desktop, ≥ 45 fps web |
| Typing latency in a text box | < 16 ms p95 |
| Enter text editing (editor overlay ready) | < 50 ms |
| Thumbnail render (navigator, 240 px wide) | ≤ 8 ms each, off the critical path, cached by slide revision |
| Snap computation per pointer move (500 elements) | < 2 ms |
| Paste 50 slides cross-deck | < 1 s local apply (file copies async) |
| Remote change visible (other device) | < 300 ms via hints, < 3 s via sync |

---

## 19. Commands owned by this spec (not all are in menus)

| Area | Command ids |
|------|-------------|
| View/canvas | `slides.view.zoom {percent}`, `slides.view.zoomFit`, `slides.view.zoomIn`, `slides.view.zoomOut`, `slides.view.zoomToSelection`, `slides.view.toggleRulers`, `slides.view.toggleSmartGuides`, `slides.view.toggleSnapObjects`, `slides.view.toggleSnapGuides`, `slides.view.toggleSnapGrid` (P2) |
| Selection | `slides.select.elements {ids}`, `slides.select.next`, `slides.select.previous`, `slides.select.escape`, `slides.select.enterGroup`, `slides.select.sameKind` (P2), `slides.element.activate` |
| Elements | `slides.element.move`, `…resize`, `…nudge`, `…rename`, `…toggleLock`, `…lock`, `…unlock`, `…unlockAll`, `…hide`, `…show`, `…editAltText`, `…setLink`, `…removeLink`, `…resetPlaceholder`, `…setMatchKey` (06) |
| Arrange | `slides.arrange.align`, `…distribute`, `…centerOnSlide`, `…matchSize`, `…order`, `…setZ`, `…rotate`, `…flip`, `…group`, `…ungroup`, `…tidy` (P2) |
| Insert | `slides.insert.textBox`, `…shape`, `…line`, `…image`, `…table`, `…icon`, `…emoji`, `…code`, `…chart`, `…chartFromSheets`, `…link`, `…specialCharacter` |
| Text/format | `slides.format.bold`, `…italic`, `…underline`, `…strikethrough`, `…font`, `…fontSize`, `…increaseFontSize`, `…decreaseFontSize`, `…textColor`, `…highlight`, `…script`, `…caps`, `…letterSpacing`, `…lineHeight`, `…paragraphSpacing`, `…align`, `…anchor`, `…list`, `…listStyle`, `…listStart`, `…indent`, `…outdent`, `…textStyle`, `…autofit`, `…insets`, `…clear`, `…fill`, `…stroke`, `…effects`, `…opacity`, `…paintFormat`, `…copyStyle`, `…pasteStyle`; `slides.text.exitEditing`, `slides.text.removeLink` |
| Shapes/lines/images | `slides.shape.change`, `…applyQuickStyle`, `slides.line.setArrow`, `…setRouting`, `slides.image.replace`, `…reset`, `…mask`, `…crop`, `…adjust`, `…downloadOriginal` |
| Tables | `slides.table.insertRow`, `…insertColumn`, `…deleteRows`, `…deleteColumns`, `…mergeCells`, `…unmergeCells`, `…distributeRows`, `…distributeColumns`, `…setOptions`, `…setCellFill`, `…setBorders`, `…setCellAlign`, `…setCellPadding`, `…delete` |
| Guides | `slides.guides.add`, `…move`, `…delete`, `…clear` |
| Edit | `slides.edit.delete`, `slides.edit.duplicate`, `slides.edit.pasteSpecial {mode: keepSource\|useDestination\|unlinked}` |
| Find/spelling | `slides.find.open`, `…openReplace`, `…next`, `…previous`, `…replace`, `…replaceAll`; `slides.spelling.check`, `…toggleUnderline`, `…addToDictionary` |
| Accessibility | `slides.a11y.setReadingOrder`, `…resetReadingOrder`, `slides.tools.accessibilityCheck` |

---

## 20. Additions to 02-data-model and to suite specs

| # | Addition |
|---|----------|
| A-03-1 | `Deck.guidesJson: String?` — `[{"axis":"v"\|"h","at":<su>}]`, whole-value LWW (§5.6). |
| A-03-2 | Shape geometry keys of §6.3 are the `dataJson.geometry` enum (core `ShapeLibrary`, with geometry functions, adjust defaults and connection sites, shared by renderers and MCP). |
| A-03-3 | **Suite (files)**: `FileEndpoint.copyToItem(sourceFileUuid, newFileUuid, targetItemUuid)` idempotent on `newFileUuid`, quota-checked (D3); queued offline. Used by cross-deck paste, `DeckCopier`, *Insert image from Drive*. |
| A-03-4 | **Suite (files)**: generalize Sheets' image proxy `sheets.fetchImage` to `files.fetchImage(url) → fileUuid` for all apps. |
| A-03-5 | **Sheets 08 §9.5**: the objects clipboard payload carries `spreadsheetItemUuid` and `objectId` so Slides can paste a linked chart. |
| A-03-6 | **Shared packages** (decided, v2 review Q23): Write's Hunspell engine moves to the pure-Dart `wonky_spellcheck`; the Flutter glue (`SpellEngine`, dictionary loading, spelling dialogs) and the emoji picker move to `wonky_app`, so Slides doesn't import Write. |
| A-03-7 | Tokens (registered by `wonky_slides/lib/theme/slides_tokens.dart`, light/dark): `slidesSelection`, `slidesHandleFill`, `slidesAdjustHandle`, `slidesGuide`, `slidesUserGuide`, `slidesTableSelection`, `placeholderBorder`, `slideShadow`, `spellingError`. |

---

## 21. Acceptance criteria

1. Click, Shift/Mod-click, marquee (inside/touching), double-click into groups, Tab cycling and
   Esc behave per §3; locked elements are click-through; hidden elements are not drawn.
2. Moving 20 elements with smart guides shows alignment and equal-spacing guides, snaps within
   6 px, and writes one undo step naming only `x,y`; a concurrent recolor by another client
   survives (multi-client harness).
3. Resize with Shift keeps aspect; Alt resizes from center; group resize scales children without
   writing them; ungroup bakes frames exactly (golden comparison before/after).
4. Text editing: every §6.1 command works on selections and on whole elements; lists indent with
   Tab; auto-fit shrink/resize render identically in editor overlay, static canvas, thumbnail and
   PDF (line breaks equal in goldens).
5. Connectors glued to shapes follow moves without writing the connector row; elbow routes avoid
   both shapes.
6. Image insert works from upload, drop, paste, Drive and URL, offline (renders from local bytes,
   uploads later), and refuses over quota with the quota dialog; crop/mask/replace/reset per §6.5.
7. Tables: Tab navigation, add row on last Tab, merges, borders picker, paste of a 10 × 5 Sheets
   range into a new table and into a cell range.
8. Copy a group of 5 slides with images, a linked chart, builds and code states from deck A and
   paste into deck B: groups/slides/elements/builds/states arrive, images are re-homed (quota
   counted to B's owner), the chart stays linked, *Keep source formatting* brings A's theme once.
9. Paste from Write (headings, nested lists, table, image, code block) and from the OS (image,
   plain text) produce the elements of §12.4–12.5.
10. Find & replace all across slides and notes is one undo step and skips soft-locked bodies with
    the stated toast.
11. Keyboard map §10 complete (test iterates bindings vs. the registry); all transforms reachable
    without a pointer; screen reader announces selection and slide changes.
12. Budgets of §18 met on reference hardware (perf suite).

## 22. Tests

- **Core unit**: `SnapEngine` (targets, thresholds, equal spacing, rotation-aware boxes),
  geometry library (paths, adjust handles, connection sites), connector routing (straight, elbow
  avoiding boxes), group transform math (child space ⇄ slide space, bake on ungroup), auto-fit
  algorithm, text schema validator/normalizer, clipboard codec and id remapping, Write/Sheets/HTML
  paste mappers, reading-order algorithm, contrast checker.
- **Command tests**: every command in §19 executes → undo → redo with state + selection equality
  (`CommandTestHarness` on an in-memory `DeckSession`).
- **Widget tests**: selection gestures, marquee, handles, crop mode, table keyboard, text editor
  overlay alignment with rotation/flip, soft-lock refusal popover.
- **Goldens** (light/dark app chrome; slides in both appearances): selection chrome, smart guides,
  every shape geometry, lines/arrowheads, image crop/mask/adjustments, tables with merges/borders,
  text styles and lists, editor-overlay vs static text equality.
- **Multi-client harness**: concurrent move vs recolor, concurrent group/ungroup, text soft-lock
  and *Edit anyway* LWW + recovery offer, cross-device paste of the same payload.
- **Perf**: §18 scenarios with seeded decks (200 slides × 40 elements).
