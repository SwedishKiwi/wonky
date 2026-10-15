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
import 'package:serverpod_client/serverpod_client.dart' as _isc;

/// Who sees a post or comment (specs/16 §3.2).
enum BoardModeration implements _isc.SerializableModel {
  /// Author only, triage running.
  checking,
  visible,

  /// Author and admins, waiting for review.
  held,

  /// Admins only; the author sees the reason.
  removed;

  static BoardModeration fromJson(String name) {
    switch (name) {
      case 'checking':
        return BoardModeration.checking;
      case 'visible':
        return BoardModeration.visible;
      case 'held':
        return BoardModeration.held;
      case 'removed':
        return BoardModeration.removed;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "BoardModeration"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
