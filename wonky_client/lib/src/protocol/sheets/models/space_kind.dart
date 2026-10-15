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

/// (v2) What an offline-sync space holds (suite 12 §2.6, Slides 02 §9.2).
/// Each sync endpoint syncs only its kind (+ the personal space, patch OS-8).
enum SpaceKind implements _isc.SerializableModel {
  /// A Wonky Sheets spreadsheet (Spreadsheet.id = space UUID).
  spreadsheet,

  /// A Wonky Slides deck (Deck.id = space UUID).
  deck;

  static SpaceKind fromJson(String name) {
    switch (name) {
      case 'spreadsheet':
        return SpaceKind.spreadsheet;
      case 'deck':
        return SpaceKind.deck;
      default:
        throw ArgumentError('Value "$name" cannot be converted to "SpaceKind"');
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
