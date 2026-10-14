import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_sheets_core/model.dart';

/// Runs CPU-heavy pure work (parsing, file writers) off the UI thread: a
/// background isolate on native (11 §3.2, §6.1); on web (one thread) after
/// yielding a frame so progress UI can paint first.
Future<T> runOffThread<T>(T Function() work) async {
  if (kIsWeb) {
    await Future<void>.delayed(const Duration(milliseconds: 16));
    return work();
  }
  return compute<void, T>((_) => work(), null);
}

/// Saves [bytes] as [fileName]: a browser download in the same tab on web
/// (no new tab or window), the save dialog on desktop. Returns false when
/// the dialog was cancelled.
Future<bool> saveBytes(
  Uint8List bytes, {
  required String fileName,
  required String mimeType,
  String? dialogTitle,
}) async {
  final uri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType.split(';').first.trim(),
    dialogTitle: dialogTitle ?? fileName,
  );
  return kIsWeb || uri != null;
}

/// Bytes of the stored image files of [model] (exports embed them, 11 §6);
/// files that can't be fetched (offline, deleted) are skipped.
Future<Map<String, Uint8List>> fetchImageBytes(
  ShellServices s,
  WorkbookModel model,
) async {
  final out = <String, Uint8List>{};
  final ids = SheetsWorkbookExporter.imageFiles(model);
  if (ids.isEmpty || !s.connectivity.online) return out;
  final client = http.Client();
  try {
    for (final id in ids) {
      try {
        final v = await s.repositories.files.getUrl(
          UuidValue.withValidation(id),
        );
        final url = v.url;
        if (url == null) continue;
        final r = await client.get(Uri.parse(url));
        if (r.statusCode == 200) out[id] = r.bodyBytes;
      } catch (e) {
        debugPrint('Export image $id failed: $e');
      }
    }
  } finally {
    client.close();
  }
  return out;
}
