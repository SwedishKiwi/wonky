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

enum CommentAnchorKind implements _is.SerializableModel {
  /// Write: a text range carrying `cmt_<threadUuid>`.
  textRange,

  /// Sheets: one cell.
  cell,

  /// Sheets: a range.
  range,

  /// The whole item.
  document,

  /// (v2) Slides: a slide (`{v, slideId, point?}`, Slides 09 §3.1).
  slide,

  /// (v2) Slides: an element on a slide (`{v, slideId, elementId, point?}`).
  element;

  static CommentAnchorKind fromJson(String name) {
    switch (name) {
      case 'textRange':
        return CommentAnchorKind.textRange;
      case 'cell':
        return CommentAnchorKind.cell;
      case 'range':
        return CommentAnchorKind.range;
      case 'document':
        return CommentAnchorKind.document;
      case 'slide':
        return CommentAnchorKind.slide;
      case 'element':
        return CommentAnchorKind.element;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "CommentAnchorKind"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
