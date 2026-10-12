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
import '../../platform/drive/drive_item_view.dart' as _ivpffrb8;
import '../../platform/drive/import_warning_view.dart' as _ibijl4o7;

abstract class ImportReportView
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  ImportReportView._({
    required this.item,
    required this.warnings,
  });

  factory ImportReportView({
    required _ivpffrb8.DriveItemView item,
    required List<_ibijl4o7.ImportWarningView> warnings,
  }) = _ImportReportViewImpl;

  factory ImportReportView.fromJson(Map<String, dynamic> jsonSerialization) {
    return ImportReportView(
      item: _i8pkqg1o.Protocol().deserialize<_ivpffrb8.DriveItemView>(
        jsonSerialization['item'],
      ),
      warnings: _i8pkqg1o.Protocol()
          .deserialize<List<_ibijl4o7.ImportWarningView>>(
            jsonSerialization['warnings'],
          ),
    );
  }

  _ivpffrb8.DriveItemView item;

  List<_ibijl4o7.ImportWarningView> warnings;

  /// Returns a shallow copy of this [ImportReportView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ImportReportView copyWith({
    _ivpffrb8.DriveItemView? item,
    List<_ibijl4o7.ImportWarningView>? warnings,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ImportReportView',
      'item': item.toJson(),
      'warnings': warnings.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ImportReportView',
      'item': item.toJsonForProtocol(),
      'warnings': warnings.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _ImportReportViewImpl extends ImportReportView {
  _ImportReportViewImpl({
    required _ivpffrb8.DriveItemView item,
    required List<_ibijl4o7.ImportWarningView> warnings,
  }) : super._(
         item: item,
         warnings: warnings,
       );

  /// Returns a shallow copy of this [ImportReportView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ImportReportView copyWith({
    _ivpffrb8.DriveItemView? item,
    List<_ibijl4o7.ImportWarningView>? warnings,
  }) {
    return ImportReportView(
      item: item ?? this.item.copyWith(),
      warnings: warnings ?? this.warnings.map((e0) => e0.copyWith()).toList(),
    );
  }
}
