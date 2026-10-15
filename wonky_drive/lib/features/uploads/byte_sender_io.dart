import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:wonky_client/wonky_client.dart' show FileUploader;

import 'byte_sender.dart';

/// Desktop/tests: `FileUploader` on a stream that counts the bytes it
/// hands to the HTTP client.
Future<void> sendBytes(
  String uploadDescription,
  Uint8List bytes, {
  required void Function(int sent) onProgress,
  required UploadAbort abort,
}) async {
  const chunk = 64 * 1024;
  var sent = 0;
  Stream<List<int>> chunks() async* {
    for (var i = 0; i < bytes.length; i += chunk) {
      if (abort.aborted) throw const UploadAborted();
      final part = Uint8List.sublistView(
        bytes,
        i,
        min(i + chunk, bytes.length),
      );
      sent += part.length;
      onProgress(sent);
      yield part;
    }
  }

  final ok = await FileUploader(
    uploadDescription,
  ).upload(chunks(), bytes.length);
  if (abort.aborted) throw const UploadAborted();
  if (!ok) throw const UploadTransferException('The storage refused the file');
}
