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

/// Internal session.messages payload on `sheets:merged:<spaceUuid>`.
abstract class SheetsMergedSignal
    implements _is.SerializableModel, _is.ProtocolSerialization {
  SheetsMergedSignal._({
    required this.spaceUuid,
    required this.hlc,
  });

  factory SheetsMergedSignal({
    required _is.UuidValue spaceUuid,
    required String hlc,
  }) = _SheetsMergedSignalImpl;

  factory SheetsMergedSignal.fromJson(Map<String, dynamic> jsonSerialization) {
    return SheetsMergedSignal(
      spaceUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['spaceUuid'],
      ),
      hlc: jsonSerialization['hlc'] as String,
    );
  }

  _is.UuidValue spaceUuid;

  String hlc;

  /// Returns a shallow copy of this [SheetsMergedSignal]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SheetsMergedSignal copyWith({
    _is.UuidValue? spaceUuid,
    String? hlc,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SheetsMergedSignal',
      'spaceUuid': spaceUuid.toJson(),
      'hlc': hlc,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _SheetsMergedSignalImpl extends SheetsMergedSignal {
  _SheetsMergedSignalImpl({
    required _is.UuidValue spaceUuid,
    required String hlc,
  }) : super._(
         spaceUuid: spaceUuid,
         hlc: hlc,
       );

  /// Returns a shallow copy of this [SheetsMergedSignal]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SheetsMergedSignal copyWith({
    _is.UuidValue? spaceUuid,
    String? hlc,
  }) {
    return SheetsMergedSignal(
      spaceUuid: spaceUuid ?? this.spaceUuid,
      hlc: hlc ?? this.hlc,
    );
  }
}
