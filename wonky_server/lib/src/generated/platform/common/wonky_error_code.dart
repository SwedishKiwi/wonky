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

/// Machine-readable error codes of [WonkyException].
enum WonkyErrorCode implements _is.SerializableModel {
  /// The item does not exist or the caller has no access to it.
  notFound,

  /// The caller's role is too low for the operation.
  forbidden,

  /// An argument failed validation (names, sizes, formats).
  invalidArgument,

  /// A concurrent change conflicts with this one.
  conflict,

  /// A move would put a folder inside itself (specs/05 §2).
  cycle,

  /// A configured limit (cells, uploads, reservations, …) would be exceeded.
  limitExceeded,

  /// The payload is too large for this API.
  tooLarge,

  /// The document is too large for the synchronous export; use the progress API.
  useProgressApi,

  /// The resource expired (links, change records, upload descriptions).
  expired,

  /// The operation is not available in this run mode or deployment.
  unavailable,

  /// A concurrent operation holds the lock; retry later.
  busy,

  /// (v2) Not enough storage for a byte-adding operation (Drive 03 §7.1);
  /// `detailsJson` is a [QuotaExceededDetails].
  quotaExceeded;

  static WonkyErrorCode fromJson(String name) {
    switch (name) {
      case 'notFound':
        return WonkyErrorCode.notFound;
      case 'forbidden':
        return WonkyErrorCode.forbidden;
      case 'invalidArgument':
        return WonkyErrorCode.invalidArgument;
      case 'conflict':
        return WonkyErrorCode.conflict;
      case 'cycle':
        return WonkyErrorCode.cycle;
      case 'limitExceeded':
        return WonkyErrorCode.limitExceeded;
      case 'tooLarge':
        return WonkyErrorCode.tooLarge;
      case 'useProgressApi':
        return WonkyErrorCode.useProgressApi;
      case 'expired':
        return WonkyErrorCode.expired;
      case 'unavailable':
        return WonkyErrorCode.unavailable;
      case 'busy':
        return WonkyErrorCode.busy;
      case 'quotaExceeded':
        return WonkyErrorCode.quotaExceeded;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "WonkyErrorCode"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
