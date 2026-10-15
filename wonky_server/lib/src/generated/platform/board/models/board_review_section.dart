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

/// Sections of the admin Review tab (specs/16 §9.2).
enum BoardReviewSection implements _is.SerializableModel {
  held,
  check,
  unchecked,
  duplicates,
  drafts;

  static BoardReviewSection fromJson(String name) {
    switch (name) {
      case 'held':
        return BoardReviewSection.held;
      case 'check':
        return BoardReviewSection.check;
      case 'unchecked':
        return BoardReviewSection.unchecked;
      case 'duplicates':
        return BoardReviewSection.duplicates;
      case 'drafts':
        return BoardReviewSection.drafts;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "BoardReviewSection"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
