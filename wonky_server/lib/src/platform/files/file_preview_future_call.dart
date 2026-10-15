import 'package:serverpod/serverpod.dart';

import 'file_preview_service.dart';

/// Generates the server preview and thumbnail of an uploaded image right
/// after its upload completed (Drive 02 §6.2).
class FilePreviewFutureCall extends FutureCall {
  Future<void> generate(Session session, int itemId) async {
    try {
      await FilePreviewService.generate(session, itemId);
    } on Exception catch (e, st) {
      session.log(
        'File preview $itemId failed: $e',
        level: LogLevel.error,
        stackTrace: st,
      );
    }
  }
}
