# Vendored: super_editor

| | |
|---|---|
| Source | pub.dev archive https://pub.dev/api/archives/super_editor-0.3.0-dev.52.tar.gz (upstream https://github.com/superlistapp/super_editor) |
| Version | 0.3.0-dev.52 (+ patches in [PATCHES.md](PATCHES.md)) |
| Archive SHA-256 | `a711dabfa443a0b55771b9e459d5ab8d8b6fa46db797e13b1aba9ed33fa447f8` |
| Date | 2026-10-12 |
| License | MIT (see `LICENSE`, Copyright (c) 2021 Superlist, SuperDeclarative! and the contributors) |
| Owner | Write editor workstream (WS-W3, specs/wonky_write/10-implementation-plan.md) |

Copied from the archive: `lib/`, `test/`, `LICENSE`, `README.md`, `README_TESTS.md`,
`CHANGELOG.md`, `analysis_options.yaml`, `dart_test.yaml`, `pubspec.yaml`. Not copied (size,
not needed to build or test): `doc/`, `example/`, `example_chat/`, `example_perf/`,
`test_goldens/`.

Wired through `dependency_overrides: super_editor: {path: third_party/super_editor}` in the
workspace root `pubspec_overrides.yaml` (Flutter-only, kept out of the Serverpod Cloud build;
suite spec 01 §2.3). `super_text_layout` and `attributed_text`
are **not** vendored (no patch needs them).

Compatibility: the unpatched copy builds and passes its own suite (5,599 tests, `flutter test
-x golden`) on Flutter 3.47.5 / Dart 3.13.4, so no compatibility patch was needed.

## Running the package's own tests

The package is not a workspace member, so it resolves its own (dev) dependencies:

```sh
cd third_party/super_editor
flutter pub get
flutter test -x golden          # whole suite (~2 min)
flutter test test/wonky_patches  # tests of our patches only
```

## Upgrading

Re-download the new upstream archive into an empty directory, copy the same folders, re-apply
every entry of `PATCHES.md` (search for `WONKY PATCH`), run the suite, update this file.
