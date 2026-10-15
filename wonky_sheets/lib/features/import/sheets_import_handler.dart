import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show DriveItemView, UuidValue;
import 'package:wonky_sheets_core/model.dart';

import '../../l10n/sheets_l10n.dart';
import 'import_pipeline.dart';

/// Imports spreadsheet files from the home screen / drive (*New › Upload
/// file*, drag and drop, `shell.file.import`; 11 §2.1): each file becomes a
/// new spreadsheet with the default options, through the server pipeline
/// online (offline: locally, see [importAsNewSpreadsheet]).
class SheetsImportHandler implements ImportHandler {
  const SheetsImportHandler();

  @override
  Set<String> get extensions => SheetsFileImporter.extensions;

  @override
  Future<List<ImportFile>> pickFiles(BuildContext context) async {
    final l = sheetsL10n(context);
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions.toList(),
      dialogTitle: l.importDialogTitle,
    );
    return [
      for (final f in files)
        ImportFile(name: f.name, bytes: await f.readAsBytes()),
    ];
  }

  @override
  Future<List<DriveItemView>> importFiles(
    BuildContext context,
    ShellServices services,
    List<ImportFile> files, {
    UuidValue? parentUuid,
  }) async {
    final l = sheetsL10nOf(services);
    final created = <(UuidValue, String)>[];
    final problems = <String>[];
    var warnings = 0;
    // Drive 03 §7.2: client-side pre-check of the imported bytes (the
    // server checks again; offline imports aren't blocked).
    if (!await services.storageChecks.ensureRoom(
      files.fold<int>(0, (n, f) => n + f.bytes.length),
      reason: QuotaReasons.import,
    )) {
      return const [];
    }
    for (final f in files) {
      final file = ImportFileData(
        name: f.name,
        bytes: f.bytes is Uint8List
            ? f.bytes as Uint8List
            : Uint8List.fromList(f.bytes),
      );
      final fmt = file.format;
      if (fmt == null || fmt == SheetsFileFormat.xls) {
        problems.add(
          '${f.name}: '
          '${fmt == null ? l.importUnsupportedType : l.importLegacyXls}',
        );
        continue;
      }
      try {
        final r = await importAsNewSpreadsheet(
          services,
          file,
          const ImportOptions(),
          parentUuid: parentUuid,
        );
        created.add((r.uuid, r.name));
        warnings += r.report.warnings.length;
      } catch (e) {
        // Out of storage: the dialog explains it; the rest won't fit either.
        if (services.quotaErrors.present(e)) break;
        problems.add('${f.name}: ${errorMessage(e)}');
      }
    }
    final items = <DriveItemView>[];
    for (final (uuid, _) in created) {
      try {
        items.add(await services.drive.get(uuid));
      } catch (_) {
        final known = services.knownItem(uuid);
        if (known != null) items.add(known);
      }
    }
    if (created.isNotEmpty) {
      final single = created.length == 1 ? created.single : null;
      final notes = [
        if (warnings > 0) l.importWarningsCount(warnings),
        ...problems,
      ].join('\n');
      services.toasts.show(
        single != null
            ? l.importCreated(single.$2)
            : l.importManyFiles(created.length),
        description: notes.isEmpty ? null : notes,
        actionLabel: single == null ? null : l.importOpen,
        onAction: single == null
            ? null
            : () => services.router.go('/s/${single.$1.uuid}'),
      );
    } else if (problems.isNotEmpty) {
      services.toasts.error(l.importFailed, description: problems.join('\n'));
    }
    services.refreshDrive();
    return items;
  }
}
