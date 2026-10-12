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

/// Role of a user on a drive item, ordered (viewer < commenter < editor <
/// owner). Mirrors `Role` in wonky_core (specs/06 §1).
enum AccessRole implements _is.SerializableModel {
  viewer,
  commenter,
  editor,
  owner;

  static AccessRole fromJson(String name) {
    switch (name) {
      case 'viewer':
        return AccessRole.viewer;
      case 'commenter':
        return AccessRole.commenter;
      case 'editor':
        return AccessRole.editor;
      case 'owner':
        return AccessRole.owner;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "AccessRole"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
