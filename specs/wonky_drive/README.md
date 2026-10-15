# Wonky Drive — Specifications

**Wonky Drive** is the suite's file home: one drive where all files live — documents (Write),
spreadsheets (Sheets), presentations (Slides) and arbitrary uploaded files — with folders,
sharing, search, trash, previews and a **50 MB per-user storage quota**. It is a Flutter app
(`wonky_drive`, web only in v2) on the shared shell `packages/wonky_app`, served at `/drive/`
and reachable from the left menu of every app home (the site root `/` opens Wonky Write's home,
v2 review Q2). Read the [suite specs](../README.md) first —
especially [05 · Drive & files](../05-drive-and-files.md) (the shared drive model and
endpoints) and [03 · App shell](../03-app-shell-and-navigation.md) (homes, left menu, settings
routes).

| # | Spec | Summary |
|---|------|---------|
| 01 | [Overview](01-overview.md) | Purpose, scope, prioritized features, how Drive relates to the app homes, limits, document map |
| 02 | [Files, uploads & previews](02-files-uploads-previews.md) | The `file` kind, upload flow (queue, offline, resumability), MIME sniffing, previews (images, text/code, audio; no PDF previews in v2), *Open with* conversions, downloads, upload versions (P2) |
| 03 | [Storage quota](03-storage-quota.md) | 50 MB per user: what counts, accounting tables, enforcement per endpoint, errors, UI (meters, banners, dialogs, Storage page), ownership transfer, trash, backfill migration |
| 04 | [Screens & menus](04-screens-menus.md) | Drive home (left menu, views, grid/list, details, multi-select, drag-and-drop, upload panel), preview screen, Storage page, Drive settings, commands, keyboard, light/dark |
| 05 | [Implementation plan](05-implementation-plan.md) | Milestone M8 as work packages D-1…D-18 in waves (owned folders, contracts, acceptance tests), spikes, journeys, risks |

Authority order when specs disagree: suite specs for cross-cutting rules (05 for the drive
model, 06 for sharing, 13 for upload security) → 03 here for anything that counts or blocks
storage → the other Drive specs. Fix the disagreement in the same change that finds it.

**Status:** specified for milestone **M8 · Drive + suite changes** (suite
[14](../14-roadmap.md)). Nothing in this folder is built yet; the drive UI it extends exists
today inside the shell (`packages/wonky_app/lib/src/drive/`) and is shown, filtered per app, in
the Write and Sheets homes.
