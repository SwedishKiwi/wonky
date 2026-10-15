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

/// A participant's role in a presentation session (Slides 10 §6.3).
enum PresentationRole implements _isc.SerializableModel {
  /// Drives the session (presenter view); one per session.
  presenter,

  /// The presenter's own account on another device or browser.
  audience,

  /// Phone remote (P1, SL-41): sends commands.
  remote,

  /// Users with access to the deck who follow along (P1).
  follower;

  static PresentationRole fromJson(String name) {
    switch (name) {
      case 'presenter':
        return PresentationRole.presenter;
      case 'audience':
        return PresentationRole.audience;
      case 'remote':
        return PresentationRole.remote;
      case 'follower':
        return PresentationRole.follower;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "PresentationRole"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
