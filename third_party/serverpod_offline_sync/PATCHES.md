# Patches

| Id | Reason | Files | Spec | Upstream |
|----|--------|-------|------|----------|
| OS-1 | Serverpod 4.1 compatibility: `OfflineSyncDatabase` implements `Database`, which gained `watch` and `unsafeWatch`. `watch` applies the same CRDT visibility/membership filter as `find` and re-runs when queried tables, `crdt_data_rows` or memberships change. | `lib/src/database/database.dart` | suite 12 §4 | to be upstreamed |
| OS-2 | Web deadlock: `_spaceIdsForQueries` runs membership lookups in the caller's transaction (web SQLite has one connection behind one lock). | `lib/src/database/database.dart` | suite 12 §4 | to be upstreamed |
