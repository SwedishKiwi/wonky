import 'storage_probe_io.dart'
    if (dart.library.js_interop) 'storage_probe_web.dart'
    as platform;

/// Whether large upload bytes can't be stored locally: on the web the
/// SQLite worker falls back to IndexedDB without OPFS (Drive 02 §4.1), where
/// only files up to 5 MB are stored. Desktop: never limited.
Future<bool> uploadStorageLimited() => platform.uploadStorageLimited();
