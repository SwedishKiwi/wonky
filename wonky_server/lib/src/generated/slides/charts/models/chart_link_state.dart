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

/// The status of a linked chart's source (Slides 08 §5.2, §13 `checkLinks`).
enum ChartLinkState implements _is.SerializableModel {
  /// The snapshot shows the current chart.
  upToDate,

  /// The chart's data or style changed since the snapshot.
  changed,

  /// The caller can't open the spreadsheet (no data or title is returned).
  noAccess,

  /// The caller is a viewer and the owner doesn't allow copying data.
  exportDisabled,

  /// The chart was deleted in Sheets.
  chartDeleted,

  /// The spreadsheet is in the trash.
  spreadsheetTrashed,

  /// The spreadsheet was deleted forever.
  spreadsheetDeleted,

  /// The chart was made with a newer version of Wonky Sheets.
  unsupportedSpec;

  static ChartLinkState fromJson(String name) {
    switch (name) {
      case 'upToDate':
        return ChartLinkState.upToDate;
      case 'changed':
        return ChartLinkState.changed;
      case 'noAccess':
        return ChartLinkState.noAccess;
      case 'exportDisabled':
        return ChartLinkState.exportDisabled;
      case 'chartDeleted':
        return ChartLinkState.chartDeleted;
      case 'spreadsheetTrashed':
        return ChartLinkState.spreadsheetTrashed;
      case 'spreadsheetDeleted':
        return ChartLinkState.spreadsheetDeleted;
      case 'unsupportedSpec':
        return ChartLinkState.unsupportedSpec;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "ChartLinkState"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
