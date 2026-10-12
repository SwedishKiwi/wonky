import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show DriveItemView, UuidValue;
import 'package:wonky_write_core/wonky_write_core.dart';

/// File types Write imports (Write 07 §3, in-scope: Markdown, text, HTML).
const writeImportExtensions = {
  'md',
  'markdown',
  'mdown',
  'mkd',
  'txt',
  'text',
  'html',
  'htm',
};

/// A converted file, ready to become (or be inserted into) a document.
class ConvertedImport {
  const ConvertedImport({required this.name, required this.result});

  /// Document name (front matter `title`, first heading or file name).
  final String name;
  final ImportResult result;

  /// The Markdown of the converted document (for `initialMarkdown`).
  String get markdown => const MarkdownCodec().exportMarkdown(
    result.delta,
    frontMatter: result.frontMatter,
  );

  List<String> get warnings => [for (final w in result.warnings) w.message];
}

/// Converts [bytes] of [fileName] with the core importers.
Future<ConvertedImport> convertImport(String fileName, Uint8List bytes) async {
  final result = await const WonkyImporters().import(
    bytes,
    ImportOptions(fileName: fileName),
  );
  final base = fileName.contains('.')
      ? fileName.substring(0, fileName.lastIndexOf('.'))
      : fileName;
  final name =
      FrontMatter.title(result.frontMatter) ??
      (result.title?.trim().isNotEmpty ?? false
          ? result.title!.trim()
          : null) ??
      (base.trim().isEmpty ? 'Imported document' : base.trim());
  return ConvertedImport(name: name, result: result);
}

/// Picks importable files (Markdown, text, HTML).
Future<List<ImportFile>> pickImportFiles({bool multiple = true}) async {
  final files = multiple
      ? await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: writeImportExtensions.toList(),
          dialogTitle: 'Import documents',
        )
      : [
          ?await FilePicker.pickFile(
            type: FileType.custom,
            allowedExtensions: writeImportExtensions.toList(),
            dialogTitle: 'Choose a file',
          ),
        ];
  return [
    for (final f in files)
      ImportFile(name: f.name, bytes: await f.readAsBytes()),
  ];
}

/// Imports Markdown / text / HTML files as new documents on the home screen
/// (`shell.file.import`, drag and drop, Write 07 §3.1).
class WriteImportHandler implements ImportHandler {
  const WriteImportHandler();

  @override
  Set<String> get extensions => writeImportExtensions;

  @override
  Future<List<ImportFile>> pickFiles(BuildContext context) => pickImportFiles();

  @override
  Future<List<DriveItemView>> importFiles(
    BuildContext context,
    ShellServices services,
    List<ImportFile> files, {
    UuidValue? parentUuid,
  }) async {
    final created = <DriveItemView>[];
    final problems = <String>[];
    for (final f in files) {
      if (!writeImportExtensions.contains(f.extension)) {
        problems.add('${f.name}: unsupported file type');
        continue;
      }
      try {
        final converted = await convertImport(
          f.name,
          Uint8List.fromList(f.bytes),
        );
        final item = await services.drive.createDocument(
          parentUuid: parentUuid,
          name: converted.name,
          initialMarkdown: converted.markdown,
        );
        created.add(item);
        if (converted.warnings.isNotEmpty) {
          problems.add(
            '${f.name}: ${converted.warnings.length} '
            '${converted.warnings.length == 1 ? 'thing was' : 'things were'} '
            'converted or dropped',
          );
        }
      } catch (e) {
        problems.add('${f.name}: ${errorMessage(e)}');
      }
    }
    if (created.isNotEmpty) {
      services.toasts.show(
        created.length == 1
            ? 'Imported “${created.single.name}”'
            : 'Imported ${created.length} documents',
        description: problems.isEmpty ? null : problems.join('\n'),
        actionLabel: created.length == 1 ? 'Open' : null,
        onAction: created.length == 1
            ? () => services.openItem(created.single)
            : null,
      );
    } else if (problems.isNotEmpty) {
      services.toasts.error('Import failed', description: problems.join('\n'));
    }
    services.refreshDrive();
    return created;
  }
}
