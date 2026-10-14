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
import 'package:wonky_server/src/generated/protocol.dart' as _il4umwa0;
import '../../../sheets/ai/models/sheets_fill_row.dart' as _ievdmmx5;

/// The result of `sheetsAi.fillRange`: proposals for the empty cells of a
/// column, shown in the Fill with AI preview (Sheets 12 §6.6).
abstract class SheetsFillProposal
    implements _is.SerializableModel, _is.ProtocolSerialization {
  SheetsFillProposal._({
    required this.range,
    this.header,
    required this.examples,
    required this.rows,
    bool? truncated,
  }) : truncated = truncated ?? false;

  factory SheetsFillProposal({
    required String range,
    String? header,
    required int examples,
    required List<_ievdmmx5.SheetsFillRow> rows,
    bool? truncated,
  }) = _SheetsFillProposalImpl;

  factory SheetsFillProposal.fromJson(Map<String, dynamic> jsonSerialization) {
    return SheetsFillProposal(
      range: jsonSerialization['range'] as String,
      header: jsonSerialization['header'] as String?,
      examples: jsonSerialization['examples'] as int,
      rows: _il4umwa0.Protocol().deserialize<List<_ievdmmx5.SheetsFillRow>>(
        jsonSerialization['rows'],
      ),
      truncated: jsonSerialization['truncated'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['truncated']),
    );
  }

  String range;

  /// Header of the target column, when detected.
  String? header;

  /// Number of example (already filled) cells used.
  int examples;

  List<_ievdmmx5.SheetsFillRow> rows;

  /// More empty cells exist than were processed (2,000 per run).
  bool truncated;

  /// Returns a shallow copy of this [SheetsFillProposal]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SheetsFillProposal copyWith({
    String? range,
    String? header,
    int? examples,
    List<_ievdmmx5.SheetsFillRow>? rows,
    bool? truncated,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SheetsFillProposal',
      'range': range,
      if (header != null) 'header': header,
      'examples': examples,
      'rows': rows.toJson(valueToJson: (v) => v.toJson()),
      'truncated': truncated,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SheetsFillProposal',
      'range': range,
      if (header != null) 'header': header,
      'examples': examples,
      'rows': rows.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'truncated': truncated,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SheetsFillProposalImpl extends SheetsFillProposal {
  _SheetsFillProposalImpl({
    required String range,
    String? header,
    required int examples,
    required List<_ievdmmx5.SheetsFillRow> rows,
    bool? truncated,
  }) : super._(
         range: range,
         header: header,
         examples: examples,
         rows: rows,
         truncated: truncated,
       );

  /// Returns a shallow copy of this [SheetsFillProposal]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SheetsFillProposal copyWith({
    String? range,
    Object? header = _Undefined,
    int? examples,
    List<_ievdmmx5.SheetsFillRow>? rows,
    bool? truncated,
  }) {
    return SheetsFillProposal(
      range: range ?? this.range,
      header: header is String? ? header : this.header,
      examples: examples ?? this.examples,
      rows: rows ?? this.rows.map((e0) => e0.copyWith()).toList(),
      truncated: truncated ?? this.truncated,
    );
  }
}
