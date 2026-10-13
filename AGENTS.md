# Wonky Work — Flutter & Serverpod project

**Wonky Work** is a collaborative office suite: **Wonky Write** (Markdown-first word processor, like Google Docs) and **Wonky Sheets** (offline-first spreadsheet, like Google Sheets). Both are Flutter apps (web + desktop) backed by one Serverpod server. Always build the backend with Serverpod. Build for multiple users and use Serverpod's built-in authentication, which is already set up in `wonky_server/lib/server.dart` (email/password, JWT). One sign-in covers both apps.

## Specs

The specs in `specs/` are the source of truth. Start with `specs/README.md` (reading order, conventions), then `specs/01-architecture.md` (layout, package rules, how the apps are served). App specs: `specs/wonky_write/` and `specs/wonky_sheets/`. When implementation reveals a better approach, update the spec in the same change.

Key rules from the specs: every user-visible action is a command and every state change is undoable (`specs/08-commands-and-undo.md`); single window, never open new tabs or windows (`specs/03-app-shell-and-navigation.md`); UI is built with `shad` and custom widgets in `wonky_ui` (`specs/02-design-system.md`); everything works in light and dark.

## Repository layout

| Path | What |
|------|------|
| `wonky_server/` | The Serverpod server. Its web server also serves both Flutter web builds: `/write/` and `/sheets/` (`specs/01-architecture.md` §2.4) |
| `wonky_client/` | Generated client (never edit) |
| `wonky_write/` | Flutter app: Wonky Write |
| `wonky_sheets/` | Flutter app: Wonky Sheets |
| `packages/` | Shared packages: `wonky_core`, `wonky_ui`, `wonky_app` (shell), `wonky_sync_models`, `wonky_write_core`, `wonky_sheets_core`, `wonky_sheets_script`, `wonky_mcp_stdio` |
| `third_party/` | Vendored, locally patched third-party packages (`specs/01-architecture.md` §2.3) |
| `tool/` | Repository scripts (dependency-rule check, pseudo-locale) |

Current state: the M0 restructure is done. **Wonky Write is complete for its first iteration** (sign-in, drive, sharing, real-time editor, comments, suggestions, history, themes and theme editor, import/export, offline cache, spellcheck, MCP, AI assistant). **Wonky Sheets is paused**: its core packages compile and are tested, the app only boots to its home. Deferred work is in `TODO.md`; the Sheets status and how to resume it are in `specs/wonky_sheets/STATUS.md`. `serverpod: flutter_apps:` launches `write` (web-port 8101) and `sheets` (8102). The debug web apps load slowly (thousands of DDC modules); for browser checks build a release with `flutter build web --wasm --base-href /write/ --output ../wonky_server/web/write` in `wonky_write` and open http://localhost:8082/write/.

## Serverpod workflow

The user starts the server and the Flutter apps with `serverpod start`. There is no need to check if the server is running: make the changes and call the `serverpod` MCP tools as needed. If the server is not running, an informative error message will be received from the MCP server. Then STOP and ask the user to start it. NEVER start the server yourself. The Flutter app is started along with it, or can be launched from the MCP tool `spawn_flutter_app`.

While running, `serverpod start` watches for file changes to run incremental code generation and hot reload both the server and the Flutter apps.

Calling `serverpod generate` directly is not needed, but might be useful to troubleshoot when an incremental generation fails.

ALWAYS use the MCP server instead of the command line. Use the MCP server to:

- `create_migration` and `apply_migrations` for database (after you change data models).
- `create_repair_migration` if the database has drifted out of sync with the migrations.
- `tail_server_logs` to read logs from the server.
- `tail_flutter_logs` to read the raw stdout/stderr of the Flutter app.
- `hot_reload` / `hot_restart` to reload or restart the server and the Flutter app. ALWAYS call `hot_restart` after doing changes in the Flutter app that may not work with normal hot reload (which is automatically applied).
- `spawn_flutter_app` to start a Flutter app declared under `serverpod: flutter_apps:` in the server `pubspec.yaml`.
- `get_flutter_app_dtd` (Dart tooling daemon) for connecting to the app through the `dart` MCP.

NEVER edit generated code. The server's `wonky_server/lib/src/generated/` directory and the whole `wonky_client` package are rewritten by the code generator. Change the `.spy.yaml` models, the endpoints, or `wonky_server/lib/server.dart` instead.

Migrations are a narrow exception: the `migration.sql` of a generated migration MAY be edited by hand when the generated SQL would lose data — to add a data transformation, or to reach a destructive change through non-destructive steps. Never touch the other files in the migration directory, and keep the schema the SQL ends up with identical to `definition.sql` — new databases are created from that file and never run `migration.sql`.

Only when the server cannot be started at all, fall back to the CLI in the server package:

- `serverpod generate` to regenerate the client and the generated server code.
- `serverpod create-migration` after changing a model with a `table` (add `--force` for destructive changes). It only writes the migration; `serverpod start` applies pending migrations when it boots the server.

How to write tests (layout, naming, helpers, determinism, tags) is in `specs/15-writing-tests.md`; read it before writing tests. Tests need no Docker. `config/test.yaml` sets `database.dataPath`, so Serverpod starts and manages the test database (an embedded PostgreSQL) itself, and the project's `docker-compose.yaml` is not used for it. Just run `dart test` in the server package. Pure-Dart packages run `dart test` and Flutter packages and apps run `flutter test` in their own folder.

## Checklist after changes

Do these in order:

- `dart analyze` (CLI)
- `dart format` (CLI)
- `create_migration` and `apply_migrations` (MCP - only if necessary)
- Do `serverpod` MCP `hot_restart` if required (hot reload is done automatically). Will also hot restart Flutter app
- Run tests, if applicable (`dart test` in the server package, `dart test`/`flutter test` in changed packages and apps)
- Check `serverpod` MCP `tail_server_logs` and `tail_flutter_logs` for any issues.

## Testing the apps

If the user asks you to test an app:

1. Use `get_flutter_app_dtd` (`serverpod` MCP) to get the Flutter app's DTD (pick the app's `flutter_apps` alias)
2. Pass the DTD to `connect_dart_tooling_daemon` (`dart` MCP) to connect to the app
3. Use `flutter_driver` (`dart` MCP) to navigate through the app

Each app is launched from its `lib/driver.dart` (`wonky_write/lib/driver.dart`, `wonky_sheets/lib/driver.dart`). It starts the Flutter driver extension with text entry emulation turned off so the app stays usable by hand. To let the driver type, set `enableTextEntryEmulation: true` there and `hot_restart` the app.
