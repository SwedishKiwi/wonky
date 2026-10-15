/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _is;

/// (v2) Category of an uploaded file (`DriveItemKind.file`) for icons,
/// filters and the preview viewer (Drive 02 §1.2). Derived on the server from
/// the sniffed MIME type; the table is `wonky_core/lib/files/file_types.dart`.
enum FileCategory implements _is.SerializableModel {
  /// jpeg, png, gif, webp, bmp (previewed); heic/tiff/svg (not rendered).
  image,
  pdf,

  /// text/* and known source/data extensions.
  text,

  /// Previewed in P2.
  audio,

  /// Never previewed.
  video,

  /// zip, tar, gz, 7z, rar.
  archive,

  /// docx, odt, rtf, doc, pages (convertible ones offer Open with Write).
  document,

  /// xlsx, xls, ods, csv, tsv, numbers (convertible ones offer Open with Sheets).
  spreadsheet,

  /// pptx, odp, key (download only).
  presentation,
  other;

  static FileCategory fromJson(String name) {
    switch (name) {
      case 'image':
        return FileCategory.image;
      case 'pdf':
        return FileCategory.pdf;
      case 'text':
        return FileCategory.text;
      case 'audio':
        return FileCategory.audio;
      case 'video':
        return FileCategory.video;
      case 'archive':
        return FileCategory.archive;
      case 'document':
        return FileCategory.document;
      case 'spreadsheet':
        return FileCategory.spreadsheet;
      case 'presentation':
        return FileCategory.presentation;
      case 'other':
        return FileCategory.other;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "FileCategory"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
