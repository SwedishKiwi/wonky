# 15 · Writing Tests

How to write tests in this repository. *What* has to be covered is defined elsewhere:
the test levels and critical journeys in [11 §1](11-quality-testing-accessibility.md), command
tests in [08 §4](08-commands-and-undo.md), and the *Tests* section of each feature spec (plus
the testing strategies in [Write 10 §9](wonky_write/10-implementation-plan.md) and
[Sheets 13 §7](wonky_sheets/13-implementation-plan.md)). This spec is the shared *how*:
layout, naming, helpers, determinism and how to run everything.

Agent skills cover the tooling details: `serverpod-testing`, `flutter-add-widget-test`,
`flutter-add-integration-test`, `flutter-add-widget-preview`, `petitparser-test` (formula
grammar).

## 1. Principles

1. **Test at the lowest level that can catch the bug.** Logic goes in pure-Dart packages and
   is unit tested there; widget tests check UI behavior; server tests check endpoints,
   permissions and persistence; E2E covers only the critical journeys.
2. **Every behavior change ships with tests in the same change**; every bug fix starts with a
   failing regression test.
3. **Deterministic**: no real time, randomness, network or sleeps (§4). A flaky test is a bug.
4. **Independent**: tests don't depend on order or on each other's data.
5. **Test public behavior, not internals**: go through the package's public API, the
   `CommandDispatcher`, the endpoint, or the widget as a user would.
6. **Real code over mocks**: prefer real implementations and in-memory fakes (§5).
7. **Fast**: unit tests in milliseconds; slow suites are tagged (§3) so the default run stays
   quick.

## 2. Where tests live

File names mirror `lib/`: `lib/src/markdown/markdown_codec.dart` →
`test/markdown/markdown_codec_test.dart`.

| Package kind | Folder | Content |
|--------------|--------|---------|
| Pure Dart (`packages/wonky_core`, `*_core`, `wonky_sheets_script`, `wonky_sync_models`) | `test/` | Unit tests, mirroring `lib/` |
| | `test/property/` | Property/fuzz tests (§8) |
| | `test/support/` | Generators, builders, fakes for this package's own tests |
| | `lib/testing.dart` | Public test helpers other packages reuse (fakes, builders, generators); never imported from `lib/` code |
| `wonky_server` | `test/unit/` | Pure logic without Serverpod (no `withServerpod`) |
| | `test/integration/` | `withServerpod` tests: endpoints, services, streams, MCP, permissions |
| | `test/integration/test_tools/` | **Generated** (`serverpod_test_tools.dart`), never edit |
| | `test/support/` | `TestUsers`, `TestDrive`, fakes for external services |
| Flutter (`wonky_ui`, `wonky_app`, apps) | `test/` | Widget and controller tests, mirroring `lib/` |
| | `test/goldens/` | Golden tests and their `.png` masters (§7) |
| | `integration_test/` | App E2E tests (§9) |
| | `lib/testing.dart` | `wonky_ui`: `pumpWonky`; `wonky_app`: `CommandTestHarness`, fake repositories |
| Fixtures / corpora | `test/fixtures/` or the corpora named in the app specs (`wonky_write/test_corpus/`, Sheets JSON vectors) | Loaded through a small loader, never by relative path from the test file |

The template's `widget_test.dart` (counter demo) in both apps is deleted in M0.

## 3. Naming, structure and tags

Use **Given / when / then**, spread over groups and the test name, so a failure explains
itself without reading the code. Same style as the template's server test:

```dart
void main() {
  group('Given a document with a bold word', () {
    late WriteDocumentSession doc;
    setUp(() => doc = TestDocs.fromMarkdown('Hello **world**'));

    test('when toggling bold on it then the word is plain', () { … });
    test('when undoing the toggle then the word is bold again', () { … });
  });
}
```

- One behavior per test; arrange / act / assert, visibly separated.
- No logic (loops, conditionals) in assertions; use table-driven tests for vectors:
  `for (final (input, expected) in cases) test('when parsing "$input" …', …)`.
- Prefer precise matchers (`equals`, `isA<T>().having(…)`, `throwsA(isA<X>())`) over
  `isTrue` on a computed boolean.

**Tags** (declared in each package's `dart_test.yaml`; the server already declares
`integration`):

| Tag | Meaning | Default run |
|-----|---------|-------------|
| `integration` | Needs `withServerpod` / a database | yes in server package |
| `property` | Property/fuzz tests with fixed seeds | yes (fast seeds); long runs nightly |
| `golden` | Golden image comparison | CI Linux only (§7) |
| `slow` | > 2 s per test | nightly |
| `e2e` | Full app against a running server | nightly / pre-merge |

## 4. Determinism

- **Time**: never call `DateTime.now()` in code under test. Services take a clock: pure Dart
  uses `package:clock` (`clock.now()`, tests wrap with `withClock(Clock.fixed(…))`); Sheets'
  formula engine uses its own `EngineClock` ([Sheets 05](wonky_sheets/05-formula-engine.md)).
  Timers and debounces are tested with `fake_async` (pure Dart) or `tester.pump(duration)`
  (widgets), never with real delays.
- **Randomness and ids**: inject `Random` / id generators (UUIDv7, fractional indexes, Sheets'
  `DeterministicRandom`) and seed them in tests.
- **Async**: await the operation or the stream event; for Serverpod streams use
  `flushEventQueue()`. `Future.delayed` in a test is not allowed.
- **Network**: no outgoing calls. External services (Anthropic, email, URL fetch proxy,
  cloud storage) are behind interfaces with fakes (§5).
- **Locale and fonts**: tests set locale and time zone explicitly (Sheets parsing/formatting
  depends on them); goldens load bundled fonts only.

## 5. Test doubles

| Need | Use |
|------|-----|
| Collaborator with simple state (repository, store, clock) | **In-memory fake** implementing the real interface, shipped from the owning package's `lib/testing.dart` (e.g. `FakeDriveRepository` in `wonky_app`) |
| External service (Anthropic Messages API, email, HTTP fetch) | Fake implementation with scripted responses (`FakeAnthropicClient` replays recorded responses; records requests for assertions) |
| Verify an interaction at a boundary (e.g. "notification sent once") | `mocktail` mock, sparingly |
| Generated Serverpod client | **Never mock it.** UI talks to repositories ([03 §5](03-app-shell-and-navigation.md)); fake the repository instead. Client ↔ server behavior is covered by server tests |
| Database | Real (embedded Postgres via `withServerpod`, in-memory/temporary SQLite for the Sheets sync DB) |

Fakes must honor the interface's contract; a shared contract test suite
(`runDriveRepositoryContract(() => impl)`) runs against both the fake and the real
implementation where a fake is widely used.

## 6. Server tests (`wonky_server`)

Built on the generated test tools (`import 'test_tools/serverpod_test_tools.dart'`); see the
`serverpod-testing` skill for the API. Nothing has to be started first: `config/test.yaml`
sets `database.dataPath`, so `withServerpod` boots an embedded Postgres itself. After changing
endpoints the test tools are regenerated (automatic under `serverpod start`, otherwise
`serverpod generate`).

- **Always call endpoints through `endpoints`**, never by instantiating endpoint classes.
  Services (`*_service.dart`) are tested with `sessionBuilder.build()` and the `endpoints`
  parameter ignored.
- **Users**: `TestUsers.create(session, name: 'Anna')` (in `test/support/`) creates the auth
  user and `UserProfile` and returns a `TestUser` with `.session(sessionBuilder)`, a
  `sessionBuilder.copyWith(authentication: AuthenticationOverride.authenticationInfo(…))`.
  Unauthenticated calls use `AuthenticationOverride.unauthenticated()`.
- **Data**: builders with defaults (`TestDrive.document(session, owner: anna, name: …)`,
  `TestDrive.share(session, item, with: bo, role: Role.commenter)`) instead of long manual
  inserts.
- **Permission matrix**: every endpoint method gets role tests ([11 §1](11-quality-testing-accessibility.md)
  contract tests). Use the shared helper so the matrix is complete and uniform:

  ```dart
  forEachRole(
    'Given a shared document', endpoints, sessionBuilder,
    allowed: {Role.owner, Role.editor},
    act: (session, item) => endpoints.document.rename(session, item.uuid, 'New'),
  ); // generates one test per role incl. no access and unauthenticated
  ```

- **Rollback**: default `RollbackDatabase.afterEach`. Use `RollbackDatabase.disabled` only for
  code that runs concurrent transactions (Write OT, sync merges); each `withServerpod` group
  gets its own database, so no manual cleanup across groups.
- **Streams** (Write document sessions, presence, UI bridge): open the stream, then
  `await flushEventQueue()`, then act as the second user and assert with
  `emitsInOrder`/`emitsThrough`.
- **Future calls / scheduled jobs**: call the job's handler directly with a fixed clock;
  scheduling itself is tested once per job (it is registered with the right delay).
- **External services**: injected through the server's service registry; `withServerpod`
  tests register fakes in `setUp` (`Services.overrideForTest(anthropic: FakeAnthropicClient())`).
- **MCP**: tool logic is tested through `ToolExecutor` with a token-resolved user; each tool
  also has one test through the `/mcp` route (JSON-RPC in, result out) — 09 contract rule.
  If the test tools don't expose the web server, the route tests start the server on port 0
  (as `config/test.yaml` does) and call it over HTTP; decided in the M0 MCP spike.
- **Multi-client sync** (Sheets): the isolate-based harness of
  [Sheets 13 §7.3](wonky_sheets/13-implementation-plan.md); Write's in-process
  `WriteSimulator` ([Write 10](wonky_write/10-implementation-plan.md) WS-W0).

## 7. Flutter tests (`wonky_ui`, `wonky_app`, apps)

- **Pump helper**: `pumpWonky(tester, child, {brightness, density, locale, size})` from
  `package:wonky_ui/testing.dart` wraps the widget in `ShadApp` with `WonkyTheme`,
  localizations and a sensible surface size. `wonky_app`'s `pumpShell` adds the providers
  (fake repositories, `CommandRegistry`, `UndoService`, `KeymapService`).
- **Both themes**: every `wonky_ui` widget test runs in light and dark
  (`for (final b in Brightness.values)`), matching the widget preview requirement of
  [02 §4](02-design-system.md).
- **Finding widgets**: by semantics label (`find.bySemanticsLabel`), text, or a stable key.
  Stable keys are `ValueKey<String>` ids in the form `<area>.<element>` (e.g.
  `shell.topBar.share`, `write.toolbar.bold`) defined as constants next to the widget, so
  widget tests, `flutter_driver` and the MCP UI bridge use the same ids. Never find by
  widget index or private types.
- **Keyboard**: shortcuts and focus traversal are tested with `tester.sendKeyEvent` /
  `sendKeyDownEvent` and `Mod` resolved per platform (`debugDefaultTargetPlatformOverride`
  for macOS vs others).
- **Commands**: `CommandTestHarness` (from `wonky_app/testing.dart`; Sheets extends it in
  `wonky_sheets/test/harness/`) dispatches through the real `CommandDispatcher` and offers
  the 08 §4 round trip:

  ```dart
  test('when bolding the selection then undo and redo round-trip', () async {
    final h = await WriteCommandHarness.fromMarkdown('Hello [world]');  // [] = selection
    await h.expectUndoRedoRoundTrip('write.format.bold');
  });
  ```

- **Accessibility**: `expect(tester, meetsGuideline(textContrastGuideline))`,
  and `labeledTapTargetGuideline` on every screen-level test;
  semantics announcements asserted via `tester.takeAnnouncements()` where specs require them.
- **Goldens**: `test/goldens/<area>/<name>_<variant>_<light|dark>.png`, tagged `golden`.
  Masters are generated and compared **only on CI Linux** with bundled fonts (OS font
  rendering differs); locally run `flutter test -x golden`, and update masters with the
  `tool/update_goldens.sh` script (runs the CI container) — never commit masters rendered on
  macOS.

## 8. Property and fuzz tests

- Generators live in `test/support/generators/` (or `lib/testing.dart` when shared:
  `DeltaGen`, `EditGen`, Sheets op generators).
- Every property test takes its seed from `WONKY_SEED` (default: a fixed list) and the run
  count from `WONKY_PROPERTY_RUNS`; the seed is printed on failure so it can be replayed:
  `WONKY_SEED=12345 dart test test/property/ot_convergence_test.dart`.
- CI runs the fixed seeds plus one random seed per run (logged); nightly runs long counts.
- Failing cases are shrunk to a minimal sequence and added as a regular regression test.
- Tests that need several Serverpod/sync clients run each client in its own isolate
  (`serverpod_database` has a process-wide encoder — [11 §1](11-quality-testing-accessibility.md)).

## 9. Integration and E2E tests

- App E2E tests live in `integration_test/` and run against a running server
  (`serverpod start`) in development mode; they cover the critical journeys of
  [11 §1.1](11-quality-testing-accessibility.md).
- Agents explore with `flutter_driver` through the `dart` and `serverpod` MCPs (AGENTS.md:
  `get_flutter_app_dtd` → `connect_dart_tooling_daemon`; the apps start from
  `lib/driver.dart`) and turn the flows they verified into permanent `integration_test`
  tests (skill `flutter-add-integration-test`), using the stable keys of §7.
- **Test accounts**: each E2E test creates its own users with unique emails
  (`e2e+<run>-<name>@example.test`). Sign-up needs the verification code; in development and
  test run modes the server exposes an `e2eSupport` endpoint that returns the latest code for
  an `@example.test` address. It refuses all calls unless the run mode is `development` or
  `test`, and a server test asserts that it does in `production` and `staging`
  ([13](13-security-and-operations.md)).
- **Multi-client journeys** (co-editing, presence, sharing) run two app instances, or one
  app instance plus a scripted second client through the generated client.
- **Offline**: toggled through the app's connectivity service test hook (driven through the
  UI bridge), not by killing the server.

## 10. Running tests

| What | Command (in the package folder) |
|------|---------------------------------|
| Pure Dart package | `dart test` |
| Server (unit + integration) | `dart test` in `wonky_server` (`-x integration` for unit only) |
| Flutter package / app | `flutter test -x golden` locally; CI runs with goldens on Linux |
| One test | `dart test path/to/file_test.dart --name "when undoing"` |
| Replay a property failure | `WONKY_SEED=<seed> dart test test/property/<file>` |
| E2E | `flutter test integration_test/<file>.dart -d <device>` with the server running |
| Coverage | `dart test --coverage=coverage` / `flutter test --coverage` |

CI (`.github/workflows/tests.yml`, see [01 §2](01-architecture.md)) runs every workspace
package that has tests, one job per package, on every PR: `dart test -x slow -x e2e` for pure-Dart
packages, `flutter test -x golden -x slow -x e2e` for Flutter packages and apps, `dart test` in
`wonky_server`, plus the vendored packages' own suites (`third_party/super_editor`,
`third_party/attributed_text`). Still to be added: one random property seed per run, image
goldens on PRs that touch Flutter packages (needs the golden container of §7), and the nightly
`slow`, `e2e`, long property, export-validation and perf runs.

**Coverage**: logic folders of `*_core`, `wonky_sheets_script` and `wonky_sync_models` keep
≥ 90 % line coverage ([Sheets 13 §7.1](wonky_sheets/13-implementation-plan.md)); other
packages report coverage without a gate.

## 11. Checklist for a change

- [ ] New behavior is tested at the lowest useful level; bug fixes have a regression test.
- [ ] New commands have the execute → undo → redo test; new endpoints the role matrix; new MCP
      tools a `ToolExecutor` test and a `/mcp` test.
- [ ] New `wonky_ui` widgets have light + dark widget tests and a widget preview.
- [ ] No real time, randomness, network or sleeps; seeds and clocks are injected.
- [ ] Tests pass locally (`dart test` / `flutter test -x golden`) and are tagged if slow.
