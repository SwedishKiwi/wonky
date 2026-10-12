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

/// Options of `drive.import` (Write 07 §3.2, Sheets 11).
abstract class ImportOptions
    implements _is.SerializableModel, _is.ProtocolSerialization {
  ImportOptions._({
    this.format,
    this.name,
    this.parentUuid,
    this.optionsJson,
  });

  factory ImportOptions({
    String? format,
    String? name,
    _is.UuidValue? parentUuid,
    String? optionsJson,
  }) = _ImportOptionsImpl;

  factory ImportOptions.fromJson(Map<String, dynamic> jsonSerialization) {
    return ImportOptions(
      format: jsonSerialization['format'] as String?,
      name: jsonSerialization['name'] as String?,
      parentUuid: jsonSerialization['parentUuid'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(
              jsonSerialization['parentUuid'],
            ),
      optionsJson: jsonSerialization['optionsJson'] as String?,
    );
  }

  /// md, txt, html, csv, tsv; null = detect from extension/content.
  String? format;

  String? name;

  _is.UuidValue? parentUuid;

  /// Format specific options as JSON (txt.lineBreaks, csv.delimiter, …).
  String? optionsJson;

  /// Returns a shallow copy of this [ImportOptions]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ImportOptions copyWith({
    String? format,
    String? name,
    _is.UuidValue? parentUuid = const _is.$UndefinedUuidValue(),
    String? optionsJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ImportOptions',
      if (format != null) 'format': format,
      if (name != null) 'name': name,
      if (parentUuid != null) 'parentUuid': parentUuid?.toJson(),
      if (optionsJson != null) 'optionsJson': optionsJson,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ImportOptions',
      if (format != null) 'format': format,
      if (name != null) 'name': name,
      if (parentUuid != null) 'parentUuid': parentUuid?.toJson(),
      if (optionsJson != null) 'optionsJson': optionsJson,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ImportOptionsImpl extends ImportOptions {
  _ImportOptionsImpl({
    String? format,
    String? name,
    _is.UuidValue? parentUuid,
    String? optionsJson,
  }) : super._(
         format: format,
         name: name,
         parentUuid: parentUuid,
         optionsJson: optionsJson,
       );

  /// Returns a shallow copy of this [ImportOptions]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ImportOptions copyWith({
    Object? format = _Undefined,
    Object? name = _Undefined,
    _is.UuidValue? parentUuid = const _is.$UndefinedUuidValue(),
    Object? optionsJson = _Undefined,
  }) {
    return ImportOptions(
      format: format is String? ? format : this.format,
      name: name is String? ? name : this.name,
      parentUuid: parentUuid is _is.UndefinedSentinel
          ? this.parentUuid
          : parentUuid,
      optionsJson: optionsJson is String? ? optionsJson : this.optionsJson,
    );
  }
}
