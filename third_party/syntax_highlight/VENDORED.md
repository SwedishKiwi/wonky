# Vendored: syntax_highlight

| | |
|---|---|
| Source | pub.dev archive https://pub.dev/api/archives/syntax_highlight-0.5.0.tar.gz (upstream https://github.com/serverpod/syntax_highlight) |
| Version | 0.5.0 (+ patches in [PATCHES.md](PATCHES.md)) |
| Archive SHA-256 | `4d3ba40658cadba6ba55d697f29f00b43538ebb6eb4a0ca0e895c568eaced138` |
| Date | 2026-10-13 |
| License | BSD-3-Clause (see `LICENSE`) |
| Owner | Write editor workstream (WS-W3) |

Syntax highlighting of code blocks in the Write editor (Write 04 §13). Vendored because several
bundled grammars were broken (SQL, Swift, TypeScript, JavaScript, Python, Rust) and the package
depended on `super_clipboard` for a `CodeEditor` widget we don't use. Serverpod-owned: fixes go
upstream too. The `example/` and `images/` folders of the archive are left out.

Wired with `dependency_overrides: syntax_highlight: {path: third_party/syntax_highlight}` in the
workspace root `pubspec_overrides.yaml` (Flutter-only, kept out of the Serverpod Cloud build;
suite spec 01 §2.3).

Run the tests: `cd third_party/syntax_highlight && flutter pub get && flutter test`.
