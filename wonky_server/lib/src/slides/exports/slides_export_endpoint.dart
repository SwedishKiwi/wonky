import 'package:serverpod/serverpod.dart';

import '../../platform/common/models.dart';
import '../../platform/users/user_service.dart';
import 'slides_export_service.dart';

/// Server-side Slides exports (Slides 10 §11.5, `slidesExport`): the same
/// shape as Write's `writeExport`. Formats: `pdf` (`png`/`pngZip` are P1).
/// [optionsJson] holds the `SlidesPdfOptions` of 10 §11.1; [revision]
/// (older versions) is P1.
class SlidesExportEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Exports deck [itemUuid]; the result is downloaded through its signed
  /// URL (15 min; the stored file expires after 24 h).
  Future<ExportResultView> export(
    Session session,
    UuidValue itemUuid,
    String format,
    String optionsJson,
    int? revision,
  ) async => SlidesExportService.export(
    session,
    await UserService.actorOf(session),
    itemUuid,
    format,
    optionsJson,
    revision: revision,
  );

  /// Progress events (`loading`, `layout`, `fonts`, `images`, `packaging`,
  /// `uploading`); the last one is `done` or `error`. Cancel by closing.
  Stream<ExportProgressEvent> exportWithProgress(
    Session session,
    UuidValue itemUuid,
    String format,
    String optionsJson,
    int? revision,
  ) async* {
    final actor = await UserService.actorOf(session);
    yield* SlidesExportService.exportWithProgress(
      session,
      actor,
      itemUuid,
      format,
      optionsJson,
      revision: revision,
    );
  }
}
