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

/// Row counts of a spreadsheet space for download progress.
abstract class SpaceStats
    implements _is.SerializableModel, _is.ProtocolSerialization {
  SpaceStats._({
    required this.spaceUuid,
    required this.rowCounts,
    required this.totalRows,
    required this.sheetCount,
    required this.cellCount,
    required this.gridCells,
  });

  factory SpaceStats({
    required _is.UuidValue spaceUuid,
    required Map<String, int> rowCounts,
    required int totalRows,
    required int sheetCount,
    required int cellCount,
    required int gridCells,
  }) = _SpaceStatsImpl;

  factory SpaceStats.fromJson(Map<String, dynamic> jsonSerialization) {
    return SpaceStats(
      spaceUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['spaceUuid'],
      ),
      rowCounts: _il4umwa0.Protocol().deserialize<Map<String, int>>(
        jsonSerialization['rowCounts'],
      ),
      totalRows: jsonSerialization['totalRows'] as int,
      sheetCount: jsonSerialization['sheetCount'] as int,
      cellCount: jsonSerialization['cellCount'] as int,
      gridCells: jsonSerialization['gridCells'] as int,
    );
  }

  _is.UuidValue spaceUuid;

  /// table name → visible row count.
  Map<String, int> rowCounts;

  int totalRows;

  int sheetCount;

  int cellCount;

  /// Grid size (Σ rows × columns), counted against the cell limit.
  int gridCells;

  /// Returns a shallow copy of this [SpaceStats]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SpaceStats copyWith({
    _is.UuidValue? spaceUuid,
    Map<String, int>? rowCounts,
    int? totalRows,
    int? sheetCount,
    int? cellCount,
    int? gridCells,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SpaceStats',
      'spaceUuid': spaceUuid.toJson(),
      'rowCounts': rowCounts.toJson(),
      'totalRows': totalRows,
      'sheetCount': sheetCount,
      'cellCount': cellCount,
      'gridCells': gridCells,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SpaceStats',
      'spaceUuid': spaceUuid.toJson(),
      'rowCounts': rowCounts.toJson(),
      'totalRows': totalRows,
      'sheetCount': sheetCount,
      'cellCount': cellCount,
      'gridCells': gridCells,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _SpaceStatsImpl extends SpaceStats {
  _SpaceStatsImpl({
    required _is.UuidValue spaceUuid,
    required Map<String, int> rowCounts,
    required int totalRows,
    required int sheetCount,
    required int cellCount,
    required int gridCells,
  }) : super._(
         spaceUuid: spaceUuid,
         rowCounts: rowCounts,
         totalRows: totalRows,
         sheetCount: sheetCount,
         cellCount: cellCount,
         gridCells: gridCells,
       );

  /// Returns a shallow copy of this [SpaceStats]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SpaceStats copyWith({
    _is.UuidValue? spaceUuid,
    Map<String, int>? rowCounts,
    int? totalRows,
    int? sheetCount,
    int? cellCount,
    int? gridCells,
  }) {
    return SpaceStats(
      spaceUuid: spaceUuid ?? this.spaceUuid,
      rowCounts:
          rowCounts ??
          this.rowCounts.map(
            (
              key0,
              value0,
            ) => MapEntry(
              key0,
              value0,
            ),
          ),
      totalRows: totalRows ?? this.totalRows,
      sheetCount: sheetCount ?? this.sheetCount,
      cellCount: cellCount ?? this.cellCount,
      gridCells: gridCells ?? this.gridCells,
    );
  }
}
