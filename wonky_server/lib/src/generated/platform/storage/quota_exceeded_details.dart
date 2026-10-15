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

/// (v2) `WonkyException.detailsJson` of `WonkyErrorCode.quotaExceeded`
/// (Drive 03 §7.1). Clients map it to the *Out of storage* dialog variants
/// (Drive 03 §6.3).
abstract class QuotaExceededDetails
    implements _is.SerializableModel, _is.ProtocolSerialization {
  QuotaExceededDetails._({
    required this.neededBytes,
    required this.availableBytes,
    required this.quotaBytes,
    required this.chargedUserId,
    required this.chargedUserName,
    required this.isCaller,
    required this.reason,
  });

  factory QuotaExceededDetails({
    required int neededBytes,
    required int availableBytes,
    required int quotaBytes,
    required int chargedUserId,
    required String chargedUserName,
    required bool isCaller,
    required String reason,
  }) = _QuotaExceededDetailsImpl;

  factory QuotaExceededDetails.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return QuotaExceededDetails(
      neededBytes: jsonSerialization['neededBytes'] as int,
      availableBytes: jsonSerialization['availableBytes'] as int,
      quotaBytes: jsonSerialization['quotaBytes'] as int,
      chargedUserId: jsonSerialization['chargedUserId'] as int,
      chargedUserName: jsonSerialization['chargedUserName'] as String,
      isCaller: _is.BoolJsonExtension.fromJson(jsonSerialization['isCaller']),
      reason: jsonSerialization['reason'] as String,
    );
  }

  int neededBytes;

  int availableBytes;

  int quotaBytes;

  /// The user whose quota is short: the caller, or the item owner (images
  /// added to someone else's item, ownership transfers).
  int chargedUserId;

  String chargedUserName;

  /// Whether [chargedUserId] is the caller.
  bool isCaller;

  /// What was refused: upload, image, import, convert, copy, template,
  /// transfer, restoreVersionCopy (`QuotaReason` constants on the server).
  String reason;

  /// Returns a shallow copy of this [QuotaExceededDetails]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  QuotaExceededDetails copyWith({
    int? neededBytes,
    int? availableBytes,
    int? quotaBytes,
    int? chargedUserId,
    String? chargedUserName,
    bool? isCaller,
    String? reason,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'QuotaExceededDetails',
      'neededBytes': neededBytes,
      'availableBytes': availableBytes,
      'quotaBytes': quotaBytes,
      'chargedUserId': chargedUserId,
      'chargedUserName': chargedUserName,
      'isCaller': isCaller,
      'reason': reason,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'QuotaExceededDetails',
      'neededBytes': neededBytes,
      'availableBytes': availableBytes,
      'quotaBytes': quotaBytes,
      'chargedUserId': chargedUserId,
      'chargedUserName': chargedUserName,
      'isCaller': isCaller,
      'reason': reason,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _QuotaExceededDetailsImpl extends QuotaExceededDetails {
  _QuotaExceededDetailsImpl({
    required int neededBytes,
    required int availableBytes,
    required int quotaBytes,
    required int chargedUserId,
    required String chargedUserName,
    required bool isCaller,
    required String reason,
  }) : super._(
         neededBytes: neededBytes,
         availableBytes: availableBytes,
         quotaBytes: quotaBytes,
         chargedUserId: chargedUserId,
         chargedUserName: chargedUserName,
         isCaller: isCaller,
         reason: reason,
       );

  /// Returns a shallow copy of this [QuotaExceededDetails]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  QuotaExceededDetails copyWith({
    int? neededBytes,
    int? availableBytes,
    int? quotaBytes,
    int? chargedUserId,
    String? chargedUserName,
    bool? isCaller,
    String? reason,
  }) {
    return QuotaExceededDetails(
      neededBytes: neededBytes ?? this.neededBytes,
      availableBytes: availableBytes ?? this.availableBytes,
      quotaBytes: quotaBytes ?? this.quotaBytes,
      chargedUserId: chargedUserId ?? this.chargedUserId,
      chargedUserName: chargedUserName ?? this.chargedUserName,
      isCaller: isCaller ?? this.isCaller,
      reason: reason ?? this.reason,
    );
  }
}
