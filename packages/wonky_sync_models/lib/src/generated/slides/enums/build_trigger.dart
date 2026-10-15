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
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;

/// What starts an animation step (Slides 02 §3.11, 06 §4.1). Append-only;
/// `onElementClick` is reserved for P2 (A-06-2).
enum BuildTrigger implements _iss.SerializableModel {
  onClick,
  withPrevious,
  afterPrevious;

  static BuildTrigger fromJson(String name) {
    switch (name) {
      case 'onClick':
        return BuildTrigger.onClick;
      case 'withPrevious':
        return BuildTrigger.withPrevious;
      case 'afterPrevious':
        return BuildTrigger.afterPrevious;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "BuildTrigger"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
