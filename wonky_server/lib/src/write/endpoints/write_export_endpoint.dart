import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';

import '../../platform/common/models.dart';
import '../../platform/users/user_service.dart';
import '../export/write_export_service.dart';

/// Server-side Write exports and conversions (Write 07 §10). Formats use
/// MCP names: md, md_zip, pdf, html, html_zip, docx, odt, rtf, epub, txt.
class WriteExportEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<ExportResultView> export(
    Session session,
    UuidValue documentUuid,
    String format,
    String optionsJson,
    int? revision,
  ) async => WriteExportService.export(
    session,
    await UserService.actorOf(session),
    documentUuid,
    format,
    optionsJson,
    revision: revision,
  );

  /// Progress events; the last one is `done` or `error`. Cancel by closing.
  Stream<ExportProgressEvent> exportWithProgress(
    Session session,
    UuidValue documentUuid,
    String format,
    String optionsJson,
    int? revision,
  ) async* {
    final actor = await UserService.actorOf(session);
    yield* WriteExportService.exportWithProgress(
      session,
      actor,
      documentUuid,
      format,
      optionsJson,
      revision: revision,
    );
  }

  Future<ConvertForInsertResult> convertForInsert(
    Session session,
    UuidValue uploadId,
    String format,
    String optionsJson,
  ) async => WriteExportService.convertForInsert(
    session,
    await UserService.actorOf(session),
    uploadId,
    format,
    optionsJson,
  );

  /// Image proxy for client exports (CORS-blocked remote images).
  Future<ByteData> fetchImage(
    Session session,
    UuidValue documentUuid,
    String src,
  ) async => WriteExportService.fetchImage(
    session,
    await UserService.actorOf(session),
    documentUuid,
    src,
  );
}
