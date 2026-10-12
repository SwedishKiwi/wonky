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
import 'package:wonky_client/src/protocol/protocol.dart' as _i8pkqg1o;
import '../../sheets/models/cell_history_entry.dart' as _ipmetl3d;

abstract class CellHistoryPage
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  CellHistoryPage._({
    required this.entries,
    this.nextCursor,
  });

  factory CellHistoryPage({
    required List<_ipmetl3d.CellHistoryEntry> entries,
    String? nextCursor,
  }) = _CellHistoryPageImpl;

  factory CellHistoryPage.fromJson(Map<String, dynamic> jsonSerialization) {
    return CellHistoryPage(
      entries: _i8pkqg1o.Protocol()
          .deserialize<List<_ipmetl3d.CellHistoryEntry>>(
            jsonSerialization['entries'],
          ),
      nextCursor: jsonSerialization['nextCursor'] as String?,
    );
  }

  List<_ipmetl3d.CellHistoryEntry> entries;

  String? nextCursor;

  /// Returns a shallow copy of this [CellHistoryPage]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  CellHistoryPage copyWith({
    List<_ipmetl3d.CellHistoryEntry>? entries,
    String? nextCursor,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CellHistoryPage',
      'entries': entries.toJson(valueToJson: (v) => v.toJson()),
      if (nextCursor != null) 'nextCursor': nextCursor,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'CellHistoryPage',
      'entries': entries.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      if (nextCursor != null) 'nextCursor': nextCursor,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CellHistoryPageImpl extends CellHistoryPage {
  _CellHistoryPageImpl({
    required List<_ipmetl3d.CellHistoryEntry> entries,
    String? nextCursor,
  }) : super._(
         entries: entries,
         nextCursor: nextCursor,
       );

  /// Returns a shallow copy of this [CellHistoryPage]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  CellHistoryPage copyWith({
    List<_ipmetl3d.CellHistoryEntry>? entries,
    Object? nextCursor = _Undefined,
  }) {
    return CellHistoryPage(
      entries: entries ?? this.entries.map((e0) => e0.copyWith()).toList(),
      nextCursor: nextCursor is String? ? nextCursor : this.nextCursor,
    );
  }
}
