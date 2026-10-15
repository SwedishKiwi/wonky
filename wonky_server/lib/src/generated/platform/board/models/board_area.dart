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

/// Where a post belongs (specs/16 §2).
enum BoardArea implements _is.SerializableModel {
  drive,
  write,
  sheets,
  slides,

  /// Shell, sign-in, settings, cross-app.
  suite,

  /// Performance, sync, email; not visible UI.
  server;

  static BoardArea fromJson(String name) {
    switch (name) {
      case 'drive':
        return BoardArea.drive;
      case 'write':
        return BoardArea.write;
      case 'sheets':
        return BoardArea.sheets;
      case 'slides':
        return BoardArea.slides;
      case 'suite':
        return BoardArea.suite;
      case 'server':
        return BoardArea.server;
      default:
        throw ArgumentError('Value "$name" cannot be converted to "BoardArea"');
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
