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

/// Public lifecycle of a post (specs/16 §3.1).
enum BoardPostStatus implements _is.SerializableModel {
  open,
  planned,
  done,
  shipped,
  declined,
  duplicate;

  static BoardPostStatus fromJson(String name) {
    switch (name) {
      case 'open':
        return BoardPostStatus.open;
      case 'planned':
        return BoardPostStatus.planned;
      case 'done':
        return BoardPostStatus.done;
      case 'shipped':
        return BoardPostStatus.shipped;
      case 'declined':
        return BoardPostStatus.declined;
      case 'duplicate':
        return BoardPostStatus.duplicate;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "BoardPostStatus"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
