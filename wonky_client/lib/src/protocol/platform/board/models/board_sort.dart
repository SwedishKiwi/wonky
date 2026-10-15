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

enum BoardSort implements _isc.SerializableModel {
  /// Votes in the last 14 days, then score.
  trending,
  top,
  newest,
  discussed;

  static BoardSort fromJson(String name) {
    switch (name) {
      case 'trending':
        return BoardSort.trending;
      case 'top':
        return BoardSort.top;
      case 'newest':
        return BoardSort.newest;
      case 'discussed':
        return BoardSort.discussed;
      default:
        throw ArgumentError('Value "$name" cannot be converted to "BoardSort"');
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
