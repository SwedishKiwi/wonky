# Vendored: serverpod_offline_sync

| | |
|---|---|
| Source | https://github.com/marcelomendoncasoares/serverpod_offline_sync (pub.dev `serverpod_offline_sync` 0.0.9), taken via the patched copy in the TopTap project |
| Version | 0.0.9 (+ patches below) |
| Date | 2026-10-12 |
| License | BSD-3-Clause (see `LICENSE`) |

A workspace member (listed under `workspace:` in the root `pubspec.yaml`, patch OS-3) rather
than a path override, because the server uses it and Serverpod Cloud only uploads workspace
packages (suite spec 01 §2.3). Remove once an upstream release contains all patches.
