/// Serverpod shared package with the offline-synced (`database: sync`) models
/// of Wonky Sheets (specs/wonky_sheets/02-data-model.md §3), used by the
/// server, the generated client and the Sheets app.
///
/// Id helpers (UUIDv5 namespaces, fractional indexes) are in
/// `package:wonky_sync_models/ids.dart`.
library;

export 'src/generated/protocol.dart';
