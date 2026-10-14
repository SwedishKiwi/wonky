# Vendored: dart_eval

| | |
|---|---|
| Source | https://pub.dev/packages/dart_eval 0.8.5 (https://github.com/ethanblake4/dart_eval) |
| Version | 0.8.5 (+ patches below) |
| Date | 2026-10-14 |
| License | BSD-3-Clause (see `LICENSE`) |

Interpreter for Wonky Sheets scripts (Sheets spec 09). A workspace member (listed under
`workspace:` in the root `pubspec.yaml`) rather than a path override, because the server
compiles and runs scripts and Serverpod Cloud only uploads workspace packages (suite spec
01 §2.3). The Flutter apps only instantiate `Runtime`; the compiler (and the analyzer it
uses) is tree-shaken out of their builds.

Note: dart_eval 0.8.5 requires `analyzer ^8.2.0`, so the workspace resolves analyzer 8.4.1
(instead of 13.x). The compiler uses the analyzer's AST API, which changed substantially in
analyzer 9–13 (`NamedCompilationUnitMember`, formal parameters, class bodies); moving to a
newer analyzer means porting the compiler (about 90 call sites).

Run the package's tests (upstream suite plus `test/wonky_patches_test.dart`) with
`dart test` in this folder.
