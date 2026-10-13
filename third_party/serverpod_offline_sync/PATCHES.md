# Patches

| Id | Reason | Files | Spec | Upstream |
|----|--------|-------|------|----------|
| OS-1 | Serverpod 4.1 compatibility: `OfflineSyncDatabase` implements `Database`, which gained `watch` and `unsafeWatch`. `watch` applies the same CRDT visibility/membership filter as `find` and re-runs when queried tables, `crdt_data_rows` or memberships change. | `lib/src/database/database.dart` | suite 12 §4 | to be upstreamed |
| OS-2 | Web deadlock: `_spaceIdsForQueries` runs membership lookups in the caller's transaction (web SQLite has one connection behind one lock). | `lib/src/database/database.dart` | suite 12 §4 | to be upstreamed |
| OS-3 | Infra: `resolution: workspace` and version `0.0.9` (was `0.0.9+wonky.1`) so the copy is a workspace member instead of a root path override. Serverpod Cloud only uploads workspace packages the server depends on; a path override to a folder outside them breaks the cloud `pub get`. The hosted `serverpod_offline_sync_client`/`_server` pin `0.0.9` exactly. | `pubspec.yaml` | suite 01 §2.3 | not upstreamable |
