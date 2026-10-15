import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// `WebSqlite.connectToRecommended` picks OPFS when the browser offers the
/// origin private file system with synchronous access handles (a secure
/// context, `FileSystemFileHandle`, a usable `navigator.storage
/// .getDirectory()` — it rejects in some private windows), else IndexedDB.
/// The worker can't be asked, so this checks the same prerequisites (as
/// the Sheets replica does).
Future<bool> uploadStorageLimited() async {
  try {
    if (globalContext['isSecureContext'] != true.toJS) return true;
    if (!globalContext.has('FileSystemFileHandle')) return true;
    final navigator = globalContext['navigator']! as JSObject;
    final storage = navigator['storage'] as JSObject?;
    if (storage == null || !storage.has('getDirectory')) return true;
    await storage.callMethod<JSPromise<JSAny?>>('getDirectory'.toJS).toDart;
    return false;
  } on Object {
    return true;
  }
}
