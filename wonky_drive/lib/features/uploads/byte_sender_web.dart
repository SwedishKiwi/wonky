import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:wonky_app/wonky_app.dart' show OfflineException;

import 'byte_sender.dart';

/// Web: an `XMLHttpRequest` with `upload.onprogress` (spike S-D2: the
/// `http` package's browser client — and so `FileUploader` — buffers the
/// body and reports no upload progress).
Future<void> sendBytes(
  String uploadDescription,
  Uint8List bytes, {
  required void Function(int sent) onProgress,
  required UploadAbort abort,
}) {
  final d = UploadDescription.parse(uploadDescription);
  final done = Completer<void>();
  final xhr = (globalContext['XMLHttpRequest']! as JSFunction)
      .callAsConstructor<JSObject>();
  xhr.callMethod<JSAny?>('open'.toJS, d.method.toJS, d.url.toString().toJS);
  if (!d.multipart) {
    for (final h in d.headers.entries) {
      xhr.callMethod<JSAny?>('setRequestHeader'.toJS, h.key.toJS, h.value.toJS);
    }
  }
  final upload = xhr['upload']! as JSObject;
  upload['onprogress'] = ((JSObject e) {
    final loaded = e['loaded'];
    if (loaded.isA<JSNumber>()) onProgress((loaded! as JSNumber).toDartInt);
  }).toJS;
  xhr['onload'] = ((JSAny? _) {
    if (done.isCompleted) return;
    final status = (xhr['status']! as JSNumber).toDartInt;
    if (d.succeeded(status)) {
      onProgress(bytes.length);
      done.complete();
    } else {
      done.completeError(
        UploadTransferException('HTTP $status', status: status),
      );
    }
  }).toJS;
  xhr['onerror'] = ((JSAny? _) {
    if (!done.isCompleted) {
      done.completeError(const OfflineException('The upload was interrupted'));
    }
  }).toJS;
  xhr['onabort'] = ((JSAny? _) {
    if (!done.isCompleted) done.completeError(const UploadAborted());
  }).toJS;
  abort.onAbort = () => xhr.callMethod<JSAny?>('abort'.toJS);

  final JSAny body;
  if (d.multipart) {
    final form = (globalContext['FormData']! as JSFunction)
        .callAsConstructor<JSObject>();
    for (final f in d.fields.entries) {
      form.callMethod<JSAny?>('append'.toJS, f.key.toJS, f.value.toJS);
    }
    final blob = (globalContext['Blob']! as JSFunction)
        .callAsConstructor<JSObject>(<JSAny>[bytes.toJS].toJS);
    form.callMethod<JSAny?>(
      'append'.toJS,
      (d.field ?? 'file').toJS,
      blob,
      (d.fileName ?? 'file').toJS,
    );
    body = form;
  } else {
    body = bytes.toJS;
  }
  xhr.callMethod<JSAny?>('send'.toJS, body);
  return done.future.whenComplete(() => abort.onAbort = null);
}
