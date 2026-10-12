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

/// Why a user is a member of a spreadsheet space (suite 12 §2.3).
enum SubscriptionReason implements _is.SerializableModel {
  open,
  pinned,
  recent,
  mcp,
  script;

  static SubscriptionReason fromJson(String name) {
    switch (name) {
      case 'open':
        return SubscriptionReason.open;
      case 'pinned':
        return SubscriptionReason.pinned;
      case 'recent':
        return SubscriptionReason.recent;
      case 'mcp':
        return SubscriptionReason.mcp;
      case 'script':
        return SubscriptionReason.script;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "SubscriptionReason"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
