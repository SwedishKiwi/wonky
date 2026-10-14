# Wonky Works v2 — open questions for review

The v2 specs add **Wonky Drive** ([wonky_drive/](wonky_drive/README.md)), **Wonky Slides**
([wonky_slides/](wonky_slides/README.md)) and suite changes (unified drive, 50 MB quota, settings
split, *Report a bug*, shared packages; suite specs marked "(v2)"). Nothing of v2 is implemented.
Each question below is marked **Open question (for review)** in the linked spec with a
recommendation; answering here (or in the spec) unblocks implementation. Milestones: M8 Drive +
suite changes → M9 Slides MVP → M10 Slides motion & content → M11 Slides collaboration, MCP & AI
([14-roadmap.md](14-roadmap.md)).

## Suite and Drive

| # | Question | Recommendation | Spec |
|---|----------|----------------|------|
| 1 | Suite name in the UI: "Wonky Works" vs "Wonky Work" | Pick one everywhere | [00](00-product-overview.md) |
| 2 | `/` always opens Drive, or the last-used app | Always Drive | [01](01-architecture.md) |
| 3 | Split `wonky_code` into pure-Dart + Flutter packages | Split (`wonky_code`, `wonky_code_flutter`) | [01](01-architecture.md) |
| 4 | Slides rich text: extract `wonky_rich_text` instead of importing `wonky_write_core` | Extract | [01](01-architecture.md) |
| 5 | Presenter view: single-window exception (second window) vs second device only | Presenting-only exception + device fallback (see 29) | [03](03-app-shell-and-navigation.md) |
| 6 | Replace Help › *Report a problem* with *Report a bug* | Yes | [03](03-app-shell-and-navigation.md) |
| 7 | Folders in app homes | Only folders containing the app's kind (`kindMask`) | [03](03-app-shell-and-navigation.md), [05](05-drive-and-files.md) |
| 8 | *Report a bug* target | Prefilled "new issue" link (app, version, platform — no user content) | [03](03-app-shell-and-navigation.md) |
| 9 | Desktop: one combined binary vs four apps | Four | [03](03-app-shell-and-navigation.md) |
| 10 | Where *Keyboard shortcuts* settings live | Wonky Works settings, split shared/app | [04](04-auth-and-accounts.md) |
| 11 | Malware scanning of uploads | Not in M8 | [13](13-security-and-operations.md) |
| 12 | Chunked resumable uploads | Whole-file retry first | [Drive 02](wonky_drive/02-files-uploads-previews.md) |
| 13 | Convert uploads (CSV/DOCX…) by default | No; a setting | [Drive 02](wonky_drive/02-files-uploads-previews.md) |
| 14 | Do previous file versions count against the quota | Yes | [Drive 02](wonky_drive/02-files-uploads-previews.md) |
| 15 | Grace period for users already over 50 MB | None (non-destructive over-quota state + notice) | [Drive 03](wonky_drive/03-storage-quota.md) |
| 16 | Restore from trash when over quota | Never blocked (trash already counts) | [Drive 03](wonky_drive/03-storage-quota.md) |
| 17 | Code tokenization in exports differs from the editor | Accept until the shared tokenizer lands (see 25) | [Write 04 §15.5](wonky_write/04-editor.md) |

## Slides

| # | Question | Recommendation | Spec |
|---|----------|----------------|------|
| 18 | Concurrent text edits in one text box | Soft lock + last-writer-wins per text body in v1; 3-way merge on receive P2 | [02 §4.5](wonky_slides/02-data-model.md) |
| 19 | Every replica downloads every space kind (decks + spreadsheets) | Vendored offline-sync patch OS-8: space filter per sync endpoint | [02 §9.2](wonky_slides/02-data-model.md), [suite 12 §2.6](12-offline-and-sync.md) |
| 20 | Text editor for text boxes | super_editor overlay on the edited box; decided by a week-1 spike | [03 §6.1](wonky_slides/03-editor-canvas-and-objects.md) |
| 22 | Nested slide groups | One level in v1 | [04 §5.12](wonky_slides/04-screens-menus-toolbar.md) |
| 23 | Shared package names (`wonky_sync_kit`, `wonky_fonts`, shared spell engine) | As proposed | [12 §8](wonky_slides/12-implementation-plan.md) |
| 24 | What a printed/thumbnail slide shows when it has builds | Authored layout with all content; P1 option: final animation state | [06 §9.6](wonky_slides/06-animations-and-transitions.md) |
| 25 | Write exports switch to the shared TextMate tokenizer | Yes (only token colors change) | [07 §2.2](wonky_slides/07-code-blocks.md) |
| 26 | TextMate engine: copy into `wonky_code` vs upstream split | Copy now, propose upstream later | [07 §2.2](wonky_slides/07-code-blocks.md) |
| 27 | Number formats for charts outside Sheets | Extract `wonky_numfmt` | [08 §2.5](wonky_slides/08-charts-from-sheets.md) |
| 28 | Linked chart auto-update | Client-side in M10; server reverse index in M11 if needed | [08 §5.5](wonky_slides/08-charts-from-sheets.md) |
| 29 | Presenter view windows | Second local window by default + audience on another device as fallback, one state model | [10 §5.2](wonky_slides/10-presenting-and-pdf.md) |
| 30 | Desktop multi-window | Spike Flutter's multi-window API; fallback `desktop_multi_window` | [10 §5.4](wonky_slides/10-presenting-and-pdf.md) |

(21 — where the Animate UI lives — is resolved: the inspector's Animate tab, `slides.panel.animate`
as an alias.)
