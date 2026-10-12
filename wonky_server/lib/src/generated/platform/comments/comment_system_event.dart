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

enum CommentSystemEvent implements _is.SerializableModel {
  resolved,
  reopened,
  assigned,
  orphaned,
  suggestionAccepted,
  suggestionRejected,
  suggestionWithdrawn,
  suggestionSuperseded,
  suggestionReopened;

  static CommentSystemEvent fromJson(String name) {
    switch (name) {
      case 'resolved':
        return CommentSystemEvent.resolved;
      case 'reopened':
        return CommentSystemEvent.reopened;
      case 'assigned':
        return CommentSystemEvent.assigned;
      case 'orphaned':
        return CommentSystemEvent.orphaned;
      case 'suggestionAccepted':
        return CommentSystemEvent.suggestionAccepted;
      case 'suggestionRejected':
        return CommentSystemEvent.suggestionRejected;
      case 'suggestionWithdrawn':
        return CommentSystemEvent.suggestionWithdrawn;
      case 'suggestionSuperseded':
        return CommentSystemEvent.suggestionSuperseded;
      case 'suggestionReopened':
        return CommentSystemEvent.suggestionReopened;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "CommentSystemEvent"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
