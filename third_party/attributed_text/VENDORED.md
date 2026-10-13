# Vendored: attributed_text

| | |
|---|---|
| Source | pub.dev archive https://pub.dev/api/archives/attributed_text-0.4.7.tar.gz (upstream https://github.com/superlistapp/super_editor/tree/main/attributed_text) |
| Version | 0.4.7 (+ patches in [PATCHES.md](PATCHES.md)) |
| Archive SHA-256 | `73161d761d77e33ae1375e5ea996d609379f4e4a483047605da7e638e9fae8af` |
| Date | 2026-10-12 |
| License | MIT (see `LICENSE`) |
| Owner | Write editor workstream (WS-W3) |

Vendored because the Write editor's property tests found a span-marker corruption bug in
`AttributedSpans.addAttribution` (patch AT-1) that `super_editor` triggers through
`AddTextAttributionsRequest`. Wired with `dependency_overrides: attributed_text: {path:
third_party/attributed_text}` in the workspace root `pubspec_overrides.yaml` (Flutter-only,
kept out of the Serverpod Cloud build; suite spec 01 §2.3); the vendored
`third_party/super_editor/pubspec.yaml` overrides it too, so its own suite runs against this copy.

Run the tests: `cd third_party/attributed_text && dart pub get && dart test`.
