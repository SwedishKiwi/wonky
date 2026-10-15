# Wonky Drive

Every file of Wonky Work in one place: the unified drive with all kinds
(documents, spreadsheets, presentations, folders and uploaded files), file
uploads and previews, and the storage page. Web only (specs/01-architecture.md
A13).

- Specs: `specs/wonky_drive/` (start with `01-overview.md`; build plan
  `05-implementation-plan.md`, status `STATUS.md`).
- Served at `/drive/` by `wonky_server`; in development `serverpod start`
  launches it from `lib/driver.dart` on port 8100 (`flutter_apps: drive`).
- Release build for the server:
  `flutter build web --wasm --base-href /drive/ --output ../wonky_server/web/drive`.
