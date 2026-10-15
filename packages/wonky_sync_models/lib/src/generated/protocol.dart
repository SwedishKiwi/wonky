/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_type_check

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_database/serverpod_database.dart' as _isd;
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;
import 'banding.dart' as _igaoyygq;
import 'basic_filter.dart' as _ir527j7r;
import 'cell.dart' as _ig8ot2c3;
import 'change_log.dart' as _i49u5dee;
import 'conditional_format_rule.dart' as _iagb74mi;
import 'data_validation_rule.dart' as _iwv9w6ou;
import 'dimension_group.dart' as _ihb6cnfg;
import 'embedded_object.dart' as _i1kjtrfg;
import 'enums/actor_kind.dart' as _iw5nkflj;
import 'enums/dimension.dart' as _ih6mykm1;
import 'enums/embedded_object_kind.dart' as _ij70oqpa;
import 'enums/horizontal_align.dart' as _i0dpapyw;
import 'enums/recalc_mode.dart' as _ioe6j54y;
import 'enums/script_build_status.dart' as _itrdthbz;
import 'enums/sheet_kind.dart' as _ir1newq6;
import 'enums/trigger_kind.dart' as _i4qnzfu9;
import 'enums/vertical_align.dart' as _iinjk5no;
import 'enums/wrap_strategy.dart' as _ijdxo9rm;
import 'filter_view.dart' as _irpnjcqz;
import 'macro.dart' as _ii49uszr;
import 'merged_range.dart' as _i86u9dto;
import 'named_range.dart' as _i5bzm6yh;
import 'pivot_table.dart' as _iagznf3k;
import 'protected_range.dart' as _iyj10qb7;
import 'script_build.dart' as _icmt6fy2;
import 'script_file.dart' as _ix1o0is2;
import 'script_project.dart' as _ivqhmfft;
import 'script_property.dart' as _i4368ao2;
import 'script_trigger.dart' as _i3nma2z7;
import 'script_user_property.dart' as _i28e4cu9;
import 'sheet.dart' as _ig4g76zp;
import 'sheet_column.dart' as _isl6cgsg;
import 'sheet_row.dart' as _ihygasqj;
import 'slides/chart_link.dart' as _idbbyz5o;
import 'slides/code_state.dart' as _ild4hnlk;
import 'slides/deck.dart' as _i5rkrncd;
import 'slides/deck_change_log.dart' as _iq02mgkm;
import 'slides/deck_theme.dart' as _ifho1iaj;
import 'slides/enums/build_kind.dart' as _i28s2inw;
import 'slides/enums/build_trigger.dart' as _ihn6hgce;
import 'slides/enums/deck_appearance.dart' as _i24j0uh3;
import 'slides/enums/placeholder_type.dart' as _i8b7xui8;
import 'slides/enums/slide_element_kind.dart' as _i2w8xpqg;
import 'slides/enums/slide_size_preset.dart' as _ixx3p5q7;
import 'slides/enums/table_dimension.dart' as _i2fu17sc;
import 'slides/slide.dart' as _iad1oxgb;
import 'slides/slide_build.dart' as _i6oyv19i;
import 'slides/slide_element.dart' as _iiliulbi;
import 'slides/slide_group.dart' as _ic4eqfvq;
import 'slides/slide_layout.dart' as _i1s0dhb4;
import 'slides/slide_master.dart' as _ii2umwrw;
import 'slides/slide_table_axis.dart' as _ie2n7e76;
import 'slides/slide_table_cell.dart' as _iuzroerr;
import 'spreadsheet.dart' as _ikok0gb2;
export 'banding.dart';
export 'basic_filter.dart';
export 'cell.dart';
export 'change_log.dart';
export 'conditional_format_rule.dart';
export 'data_validation_rule.dart';
export 'dimension_group.dart';
export 'embedded_object.dart';
export 'enums/actor_kind.dart';
export 'enums/dimension.dart';
export 'enums/embedded_object_kind.dart';
export 'enums/horizontal_align.dart';
export 'enums/recalc_mode.dart';
export 'enums/script_build_status.dart';
export 'enums/sheet_kind.dart';
export 'enums/trigger_kind.dart';
export 'enums/vertical_align.dart';
export 'enums/wrap_strategy.dart';
export 'filter_view.dart';
export 'macro.dart';
export 'merged_range.dart';
export 'named_range.dart';
export 'pivot_table.dart';
export 'protected_range.dart';
export 'script_build.dart';
export 'script_file.dart';
export 'script_project.dart';
export 'script_property.dart';
export 'script_trigger.dart';
export 'script_user_property.dart';
export 'sheet.dart';
export 'sheet_column.dart';
export 'sheet_row.dart';
export 'slides/chart_link.dart';
export 'slides/code_state.dart';
export 'slides/deck.dart';
export 'slides/deck_change_log.dart';
export 'slides/deck_theme.dart';
export 'slides/enums/build_kind.dart';
export 'slides/enums/build_trigger.dart';
export 'slides/enums/deck_appearance.dart';
export 'slides/enums/placeholder_type.dart';
export 'slides/enums/slide_element_kind.dart';
export 'slides/enums/slide_size_preset.dart';
export 'slides/enums/table_dimension.dart';
export 'slides/slide.dart';
export 'slides/slide_build.dart';
export 'slides/slide_element.dart';
export 'slides/slide_group.dart';
export 'slides/slide_layout.dart';
export 'slides/slide_master.dart';
export 'slides/slide_table_axis.dart';
export 'slides/slide_table_cell.dart';
export 'spreadsheet.dart';

class Protocol extends _isd.DatabaseSerializationManager
    implements _isd.DatabaseProtocolDeserializationProvider {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  final Set<_iss.SerializationManager> _hostProtocols = {};

  @override
  _iss.ProtocolDeserialization get deserializationMetadata =>
      _iss.ProtocolDeserialization.cached(
        this,
        types: const [
          _iss.getType<_igaoyygq.Banding>,
          _iss.getType<_ir527j7r.BasicFilter>,
          _iss.getType<_ig8ot2c3.Cell>,
          _iss.getType<_i49u5dee.ChangeLog>,
          _iss.getType<_iagb74mi.ConditionalFormatRule>,
          _iss.getType<_iwv9w6ou.DataValidationRule>,
          _iss.getType<_ihb6cnfg.DimensionGroup>,
          _iss.getType<_i1kjtrfg.EmbeddedObject>,
          _iss.getType<_iw5nkflj.ActorKind>,
          _iss.getType<_ih6mykm1.Dimension>,
          _iss.getType<_ij70oqpa.EmbeddedObjectKind>,
          _iss.getType<_i0dpapyw.HorizontalAlign>,
          _iss.getType<_ioe6j54y.RecalcMode>,
          _iss.getType<_itrdthbz.ScriptBuildStatus>,
          _iss.getType<_ir1newq6.SheetKind>,
          _iss.getType<_i4qnzfu9.TriggerKind>,
          _iss.getType<_iinjk5no.VerticalAlign>,
          _iss.getType<_ijdxo9rm.WrapStrategy>,
          _iss.getType<_irpnjcqz.FilterView>,
          _iss.getType<_ii49uszr.Macro>,
          _iss.getType<_i86u9dto.MergedRange>,
          _iss.getType<_i5bzm6yh.NamedRange>,
          _iss.getType<_iagznf3k.PivotTable>,
          _iss.getType<_iyj10qb7.ProtectedRange>,
          _iss.getType<_icmt6fy2.ScriptBuild>,
          _iss.getType<_ix1o0is2.ScriptFile>,
          _iss.getType<_ivqhmfft.ScriptProject>,
          _iss.getType<_i4368ao2.ScriptProperty>,
          _iss.getType<_i3nma2z7.ScriptTrigger>,
          _iss.getType<_i28e4cu9.ScriptUserProperty>,
          _iss.getType<_ig4g76zp.Sheet>,
          _iss.getType<_isl6cgsg.SheetColumn>,
          _iss.getType<_ihygasqj.SheetRow>,
          _iss.getType<_idbbyz5o.ChartLink>,
          _iss.getType<_ild4hnlk.CodeState>,
          _iss.getType<_i5rkrncd.Deck>,
          _iss.getType<_iq02mgkm.DeckChangeLog>,
          _iss.getType<_ifho1iaj.DeckTheme>,
          _iss.getType<_i28s2inw.BuildKind>,
          _iss.getType<_ihn6hgce.BuildTrigger>,
          _iss.getType<_i24j0uh3.DeckAppearance>,
          _iss.getType<_i8b7xui8.PlaceholderType>,
          _iss.getType<_i2w8xpqg.SlideElementKind>,
          _iss.getType<_ixx3p5q7.SlideSizePreset>,
          _iss.getType<_i2fu17sc.TableDimension>,
          _iss.getType<_iad1oxgb.Slide>,
          _iss.getType<_i6oyv19i.SlideBuild>,
          _iss.getType<_iiliulbi.SlideElement>,
          _iss.getType<_ic4eqfvq.SlideGroup>,
          _iss.getType<_i1s0dhb4.SlideLayout>,
          _iss.getType<_ii2umwrw.SlideMaster>,
          _iss.getType<_ie2n7e76.SlideTableAxis>,
          _iss.getType<_iuzroerr.SlideTableCell>,
          _iss.getType<_ikok0gb2.Spreadsheet>,
          _iss.getType<_igaoyygq.Banding?>,
          _iss.getType<_ir527j7r.BasicFilter?>,
          _iss.getType<_ig8ot2c3.Cell?>,
          _iss.getType<_i49u5dee.ChangeLog?>,
          _iss.getType<_iagb74mi.ConditionalFormatRule?>,
          _iss.getType<_iwv9w6ou.DataValidationRule?>,
          _iss.getType<_ihb6cnfg.DimensionGroup?>,
          _iss.getType<_i1kjtrfg.EmbeddedObject?>,
          _iss.getType<_iw5nkflj.ActorKind?>,
          _iss.getType<_ih6mykm1.Dimension?>,
          _iss.getType<_ij70oqpa.EmbeddedObjectKind?>,
          _iss.getType<_i0dpapyw.HorizontalAlign?>,
          _iss.getType<_ioe6j54y.RecalcMode?>,
          _iss.getType<_itrdthbz.ScriptBuildStatus?>,
          _iss.getType<_ir1newq6.SheetKind?>,
          _iss.getType<_i4qnzfu9.TriggerKind?>,
          _iss.getType<_iinjk5no.VerticalAlign?>,
          _iss.getType<_ijdxo9rm.WrapStrategy?>,
          _iss.getType<_irpnjcqz.FilterView?>,
          _iss.getType<_ii49uszr.Macro?>,
          _iss.getType<_i86u9dto.MergedRange?>,
          _iss.getType<_i5bzm6yh.NamedRange?>,
          _iss.getType<_iagznf3k.PivotTable?>,
          _iss.getType<_iyj10qb7.ProtectedRange?>,
          _iss.getType<_icmt6fy2.ScriptBuild?>,
          _iss.getType<_ix1o0is2.ScriptFile?>,
          _iss.getType<_ivqhmfft.ScriptProject?>,
          _iss.getType<_i4368ao2.ScriptProperty?>,
          _iss.getType<_i3nma2z7.ScriptTrigger?>,
          _iss.getType<_i28e4cu9.ScriptUserProperty?>,
          _iss.getType<_ig4g76zp.Sheet?>,
          _iss.getType<_isl6cgsg.SheetColumn?>,
          _iss.getType<_ihygasqj.SheetRow?>,
          _iss.getType<_idbbyz5o.ChartLink?>,
          _iss.getType<_ild4hnlk.CodeState?>,
          _iss.getType<_i5rkrncd.Deck?>,
          _iss.getType<_iq02mgkm.DeckChangeLog?>,
          _iss.getType<_ifho1iaj.DeckTheme?>,
          _iss.getType<_i28s2inw.BuildKind?>,
          _iss.getType<_ihn6hgce.BuildTrigger?>,
          _iss.getType<_i24j0uh3.DeckAppearance?>,
          _iss.getType<_i8b7xui8.PlaceholderType?>,
          _iss.getType<_i2w8xpqg.SlideElementKind?>,
          _iss.getType<_ixx3p5q7.SlideSizePreset?>,
          _iss.getType<_i2fu17sc.TableDimension?>,
          _iss.getType<_iad1oxgb.Slide?>,
          _iss.getType<_i6oyv19i.SlideBuild?>,
          _iss.getType<_iiliulbi.SlideElement?>,
          _iss.getType<_ic4eqfvq.SlideGroup?>,
          _iss.getType<_i1s0dhb4.SlideLayout?>,
          _iss.getType<_ii2umwrw.SlideMaster?>,
          _iss.getType<_ie2n7e76.SlideTableAxis?>,
          _iss.getType<_iuzroerr.SlideTableCell?>,
          _iss.getType<_ikok0gb2.Spreadsheet?>,
        ],
        modules: const [],
      );

  static List<_isd.TableDefinition> get targetTableDefinitions => [
    _isd.TableDefinition(
      name: 'banding',
      dartName: 'Banding',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'sheetId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'rangeJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'styleJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'banding_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'banding_fk_1',
          columns: ['sheetId'],
          referenceTable: 'sheet',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'basic_filter',
      dartName: 'BasicFilter',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'sheetId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'rangeJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'criteriaJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'sortJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'basic_filter_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'basic_filter_fk_1',
          columns: ['sheetId'],
          referenceTable: 'sheet',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'cell',
      dartName: 'Cell',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'sheetId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'rowId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'columnId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'content',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'note',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'numberFormat',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'fontFamily',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'fontSize',
          columnType: _isd.ColumnType.doublePrecision,
          isNullable: true,
          dartType: 'double?',
        ),
        _isd.ColumnDefinition(
          name: 'bold',
          columnType: _isd.ColumnType.boolean,
          isNullable: true,
          dartType: 'bool?',
        ),
        _isd.ColumnDefinition(
          name: 'italic',
          columnType: _isd.ColumnType.boolean,
          isNullable: true,
          dartType: 'bool?',
        ),
        _isd.ColumnDefinition(
          name: 'underline',
          columnType: _isd.ColumnType.boolean,
          isNullable: true,
          dartType: 'bool?',
        ),
        _isd.ColumnDefinition(
          name: 'strikethrough',
          columnType: _isd.ColumnType.boolean,
          isNullable: true,
          dartType: 'bool?',
        ),
        _isd.ColumnDefinition(
          name: 'textColor',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'fillColor',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'hAlign',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'wonky_sync_models:HorizontalAlign?',
        ),
        _isd.ColumnDefinition(
          name: 'vAlign',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'wonky_sync_models:VerticalAlign?',
        ),
        _isd.ColumnDefinition(
          name: 'wrap',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'wonky_sync_models:WrapStrategy?',
        ),
        _isd.ColumnDefinition(
          name: 'rotation',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'borderTop',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'borderRight',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'borderBottom',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'borderLeft',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'linkUrl',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'cell_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'cell_fk_1',
          columns: ['sheetId'],
          referenceTable: 'sheet',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'cell_fk_2',
          columns: ['rowId'],
          referenceTable: 'sheet_row',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'cell_fk_3',
          columns: ['columnId'],
          referenceTable: 'sheet_column',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'cell_row_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'sheetId',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'rowId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isd.IndexDefinition(
          indexName: 'cell_col_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'sheetId',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'columnId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'change_log',
      dartName: 'ChangeLog',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'spreadsheetId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'userId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'actorKind',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'wonky_sync_models:ActorKind',
        ),
        _isd.ColumnDefinition(
          name: 'sessionId',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'label',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'summaryJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'detailJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'at',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'change_log_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'change_log_fk_1',
          columns: ['spreadsheetId'],
          referenceTable: 'spreadsheet',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'change_log_at_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'spreadsheetId',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'at',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'chart_link',
      dartName: 'ChartLink',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'elementId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'spreadsheetItemUuid',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'chartObjectId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'sheetId',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'sourceSpecJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'dataSnapshotJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'sourceVersion',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'updatedAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isd.ColumnDefinition(
          name: 'updatedBy',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'autoUpdate',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'chart_link_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'chart_link_fk_1',
          columns: ['elementId'],
          referenceTable: 'slide_element',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'chart_link_element_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'elementId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'code_state',
      dartName: 'CodeState',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'elementId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'sortKey',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'label',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'code',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'language',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'title',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'highlight',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'annotationsJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'transitionJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'code_state_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'code_state_fk_1',
          columns: ['elementId'],
          referenceTable: 'slide_element',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'code_state_element_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'elementId',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'sortKey',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'conditional_format_rule',
      dartName: 'ConditionalFormatRule',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'sheetId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'sortKey',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'rangesJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'ruleJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'enabled',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'true',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'conditional_format_rule_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'conditional_format_rule_fk_1',
          columns: ['sheetId'],
          referenceTable: 'sheet',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'data_validation_rule',
      dartName: 'DataValidationRule',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'sheetId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'rangesJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'criteriaJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'strict',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isd.ColumnDefinition(
          name: 'showDropdown',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'true',
        ),
        _isd.ColumnDefinition(
          name: 'displayStyle',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'helpText',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'data_validation_rule_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'data_validation_rule_fk_1',
          columns: ['sheetId'],
          referenceTable: 'sheet',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'deck',
      dartName: 'Deck',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'title',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'width',
          columnType: _isd.ColumnType.doublePrecision,
          isNullable: false,
          dartType: 'double',
          columnDefault: '1920.0',
        ),
        _isd.ColumnDefinition(
          name: 'height',
          columnType: _isd.ColumnType.doublePrecision,
          isNullable: false,
          dartType: 'double',
          columnDefault: '1080.0',
        ),
        _isd.ColumnDefinition(
          name: 'sizePreset',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'wonky_sync_models:SlideSizePreset',
          columnDefault: '\'widescreen16x9\'',
        ),
        _isd.ColumnDefinition(
          name: 'themeId',
          columnType: _isd.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isd.ColumnDefinition(
          name: 'appearance',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'wonky_sync_models:DeckAppearance',
          columnDefault: '\'light\'',
        ),
        _isd.ColumnDefinition(
          name: 'language',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'showSlideNumbers',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isd.ColumnDefinition(
          name: 'hideNumberOnTitle',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'true',
        ),
        _isd.ColumnDefinition(
          name: 'firstSlideNumber',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
          columnDefault: '1',
        ),
        _isd.ColumnDefinition(
          name: 'footerText',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'defaultsJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'guidesJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'presentJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'createdBy',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'deck_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'deck_change_log',
      dartName: 'DeckChangeLog',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'deckId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'userId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'actorKind',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'wonky_sync_models:ActorKind',
        ),
        _isd.ColumnDefinition(
          name: 'sessionId',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'label',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'summaryJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'detailJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'at',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'deck_change_log_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'deck_change_log_fk_1',
          columns: ['deckId'],
          referenceTable: 'deck',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'deck_change_log_at_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'deckId',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'at',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'deck_theme',
      dartName: 'DeckTheme',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'deckId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'name',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'sourceKey',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'colorsJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'fontsJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'textStylesJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'backgroundJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'shapeStyleJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'tableStyleJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'codeStyleJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'chartStyleJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'sortKey',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'deck_theme_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'deck_theme_fk_1',
          columns: ['deckId'],
          referenceTable: 'deck',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'deck_theme_deck_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'deckId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'dimension_group',
      dartName: 'DimensionGroup',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'sheetId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'dimension',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'wonky_sync_models:Dimension',
        ),
        _isd.ColumnDefinition(
          name: 'startId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'endId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'depth',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isd.ColumnDefinition(
          name: 'collapsed',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'dimension_group_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'dimension_group_fk_1',
          columns: ['sheetId'],
          referenceTable: 'sheet',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'embedded_object',
      dartName: 'EmbeddedObject',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'sheetId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'kind',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'wonky_sync_models:EmbeddedObjectKind',
        ),
        _isd.ColumnDefinition(
          name: 'anchorJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'specJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'zIndex',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
          columnDefault: '0',
        ),
        _isd.ColumnDefinition(
          name: 'title',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'altText',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'embedded_object_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'embedded_object_fk_1',
          columns: ['sheetId'],
          referenceTable: 'sheet',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'filter_view',
      dartName: 'FilterView',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'sheetId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'name',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'rangeJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'criteriaJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'sortJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'createdBy',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'filter_view_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'filter_view_fk_1',
          columns: ['sheetId'],
          referenceTable: 'sheet',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'macro',
      dartName: 'Macro',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'projectId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'name',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'functionName',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'shortcutSlot',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'macro_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'macro_fk_1',
          columns: ['projectId'],
          referenceTable: 'script_project',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'merged_range',
      dartName: 'MergedRange',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'sheetId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'rangeJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'merged_range_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'merged_range_fk_1',
          columns: ['sheetId'],
          referenceTable: 'sheet',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'named_range',
      dartName: 'NamedRange',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'spreadsheetId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'name',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'rangeJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'formula',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'comment',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'metaJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'named_range_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'named_range_fk_1',
          columns: ['spreadsheetId'],
          referenceTable: 'spreadsheet',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'pivot_table',
      dartName: 'PivotTable',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'sheetId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'anchorRowId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'anchorColId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'sourceRangeJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'specJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'pivot_table_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'pivot_table_fk_1',
          columns: ['sheetId'],
          referenceTable: 'sheet',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'protected_range',
      dartName: 'ProtectedRange',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'sheetId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'rangeJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'exceptRangesJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'description',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'warningOnly',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isd.ColumnDefinition(
          name: 'editorsJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'createdBy',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'protected_range_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'protected_range_fk_1',
          columns: ['sheetId'],
          referenceTable: 'sheet',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'script_build',
      dartName: 'ScriptBuild',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'projectId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'status',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'wonky_sync_models:ScriptBuildStatus',
          columnDefault: '\'ok\'',
        ),
        _isd.ColumnDefinition(
          name: 'sourceHash',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'bytecodeFileUuid',
          columnType: _isd.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isd.ColumnDefinition(
          name: 'diagnosticsJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'exportsJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'apiVersion',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
          columnDefault: '1',
        ),
        _isd.ColumnDefinition(
          name: 'compilerVersion',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
          columnDefault: '\'\'',
        ),
        _isd.ColumnDefinition(
          name: 'requestedBy',
          columnType: _isd.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isd.ColumnDefinition(
          name: 'lastGoodSourceHash',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'lastGoodBytecodeFileUuid',
          columnType: _isd.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isd.ColumnDefinition(
          name: 'lastGoodExportsJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'lastGoodBuiltAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isd.ColumnDefinition(
          name: 'positionsFileUuid',
          columnType: _isd.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isd.ColumnDefinition(
          name: 'builtAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'script_build_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'script_build_fk_1',
          columns: ['projectId'],
          referenceTable: 'script_project',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'script_file',
      dartName: 'ScriptFile',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'projectId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'name',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'sortKey',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'source',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'contentHash',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'updatedBy',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'updatedAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'script_file_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'script_file_fk_1',
          columns: ['projectId'],
          referenceTable: 'script_project',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'script_project',
      dartName: 'ScriptProject',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'spreadsheetId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'name',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'settingsJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'script_project_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'script_project_fk_1',
          columns: ['spreadsheetId'],
          referenceTable: 'spreadsheet',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'script_property',
      dartName: 'ScriptProperty',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'projectId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'key',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'value',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'script_property_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'script_property_fk_1',
          columns: ['projectId'],
          referenceTable: 'script_project',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'script_trigger',
      dartName: 'ScriptTrigger',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'projectId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'kind',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'wonky_sync_models:TriggerKind',
        ),
        _isd.ColumnDefinition(
          name: 'functionName',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'scheduleJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'runAsUserId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'enabled',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'true',
        ),
        _isd.ColumnDefinition(
          name: 'optionsJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'script_trigger_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'script_trigger_fk_1',
          columns: ['projectId'],
          referenceTable: 'script_project',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'script_user_property',
      dartName: 'ScriptUserProperty',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'spreadsheetId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'key',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'value',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'script_user_property_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'script_user_property_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'spreadsheetId',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'key',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'sheet',
      dartName: 'Sheet',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'spreadsheetId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'name',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'sortKey',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'kind',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'wonky_sync_models:SheetKind',
          columnDefault: '\'grid\'',
        ),
        _isd.ColumnDefinition(
          name: 'hidden',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isd.ColumnDefinition(
          name: 'tabColor',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'rightToLeft',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isd.ColumnDefinition(
          name: 'showGridlines',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'true',
        ),
        _isd.ColumnDefinition(
          name: 'frozenRows',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
          columnDefault: '0',
        ),
        _isd.ColumnDefinition(
          name: 'frozenColumns',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
          columnDefault: '0',
        ),
        _isd.ColumnDefinition(
          name: 'defaultRowHeight',
          columnType: _isd.ColumnType.doublePrecision,
          isNullable: false,
          dartType: 'double',
          columnDefault: '21.0',
        ),
        _isd.ColumnDefinition(
          name: 'defaultColumnWidth',
          columnType: _isd.ColumnType.doublePrecision,
          isNullable: false,
          dartType: 'double',
          columnDefault: '100.0',
        ),
        _isd.ColumnDefinition(
          name: 'formatJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'printSettingsJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'sheet_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'sheet_fk_1',
          columns: ['spreadsheetId'],
          referenceTable: 'spreadsheet',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'sheet_order_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'spreadsheetId',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'sortKey',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'sheet_column',
      dartName: 'SheetColumn',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'sheetId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'sortKey',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'width',
          columnType: _isd.ColumnType.doublePrecision,
          isNullable: true,
          dartType: 'double?',
        ),
        _isd.ColumnDefinition(
          name: 'hidden',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isd.ColumnDefinition(
          name: 'formatJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'sheet_column_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'sheet_column_fk_1',
          columns: ['sheetId'],
          referenceTable: 'sheet',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'sheet_column_order_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'sheetId',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'sortKey',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'sheet_row',
      dartName: 'SheetRow',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'sheetId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'sortKey',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'height',
          columnType: _isd.ColumnType.doublePrecision,
          isNullable: true,
          dartType: 'double?',
        ),
        _isd.ColumnDefinition(
          name: 'hidden',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isd.ColumnDefinition(
          name: 'formatJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'sheet_row_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'sheet_row_fk_1',
          columns: ['sheetId'],
          referenceTable: 'sheet',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'sheet_row_order_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'sheetId',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'sortKey',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'slide',
      dartName: 'Slide',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'deckId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'sortKey',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'groupId',
          columnType: _isd.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isd.ColumnDefinition(
          name: 'layoutId',
          columnType: _isd.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isd.ColumnDefinition(
          name: 'backgroundJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'skipped',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isd.ColumnDefinition(
          name: 'notes',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'transitionJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'hideMasterElements',
          columnType: _isd.ColumnType.boolean,
          isNullable: true,
          dartType: 'bool?',
        ),
        _isd.ColumnDefinition(
          name: 'timingsJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'slide_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'slide_fk_1',
          columns: ['deckId'],
          referenceTable: 'deck',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'slide_order_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'deckId',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'sortKey',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'slide_build',
      dartName: 'SlideBuild',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'slideId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'elementId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'kind',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'wonky_sync_models:BuildKind',
        ),
        _isd.ColumnDefinition(
          name: 'effect',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'sortKey',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'trigger',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'wonky_sync_models:BuildTrigger',
        ),
        _isd.ColumnDefinition(
          name: 'delayMs',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
          columnDefault: '0',
        ),
        _isd.ColumnDefinition(
          name: 'durationMs',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isd.ColumnDefinition(
          name: 'easing',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'optionsJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'slide_build_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'slide_build_fk_1',
          columns: ['slideId'],
          referenceTable: 'slide',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'slide_build_fk_2',
          columns: ['elementId'],
          referenceTable: 'slide_element',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'slide_build_slide_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'slideId',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'sortKey',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isd.IndexDefinition(
          indexName: 'slide_build_element_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'elementId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'slide_element',
      dartName: 'SlideElement',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'slideId',
          columnType: _isd.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isd.ColumnDefinition(
          name: 'layoutId',
          columnType: _isd.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isd.ColumnDefinition(
          name: 'masterId',
          columnType: _isd.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isd.ColumnDefinition(
          name: 'parentId',
          columnType: _isd.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isd.ColumnDefinition(
          name: 'kind',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'wonky_sync_models:SlideElementKind',
        ),
        _isd.ColumnDefinition(
          name: 'name',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'x',
          columnType: _isd.ColumnType.doublePrecision,
          isNullable: true,
          dartType: 'double?',
        ),
        _isd.ColumnDefinition(
          name: 'y',
          columnType: _isd.ColumnType.doublePrecision,
          isNullable: true,
          dartType: 'double?',
        ),
        _isd.ColumnDefinition(
          name: 'width',
          columnType: _isd.ColumnType.doublePrecision,
          isNullable: true,
          dartType: 'double?',
        ),
        _isd.ColumnDefinition(
          name: 'height',
          columnType: _isd.ColumnType.doublePrecision,
          isNullable: true,
          dartType: 'double?',
        ),
        _isd.ColumnDefinition(
          name: 'rotation',
          columnType: _isd.ColumnType.doublePrecision,
          isNullable: true,
          dartType: 'double?',
        ),
        _isd.ColumnDefinition(
          name: 'flipH',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isd.ColumnDefinition(
          name: 'flipV',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isd.ColumnDefinition(
          name: 'zKey',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'readingKey',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'locked',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isd.ColumnDefinition(
          name: 'hidden',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isd.ColumnDefinition(
          name: 'placeholderType',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'wonky_sync_models:PlaceholderType?',
        ),
        _isd.ColumnDefinition(
          name: 'placeholderOf',
          columnType: _isd.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isd.ColumnDefinition(
          name: 'matchKey',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'text',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'textStyleJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'fillJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'strokeJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'effectsJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'opacity',
          columnType: _isd.ColumnType.doublePrecision,
          isNullable: true,
          dartType: 'double?',
        ),
        _isd.ColumnDefinition(
          name: 'dataJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'linkJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'altText',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'decorative',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'slide_element_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'slide_element_fk_1',
          columns: ['slideId'],
          referenceTable: 'slide',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'slide_element_fk_2',
          columns: ['layoutId'],
          referenceTable: 'slide_layout',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'slide_element_fk_3',
          columns: ['masterId'],
          referenceTable: 'slide_master',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'slide_element_fk_4',
          columns: ['parentId'],
          referenceTable: 'slide_element',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'slide_element_slide_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'slideId',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'zKey',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isd.IndexDefinition(
          indexName: 'slide_element_layout_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'layoutId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isd.IndexDefinition(
          indexName: 'slide_element_master_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'masterId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isd.IndexDefinition(
          indexName: 'slide_element_parent_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'parentId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'slide_group',
      dartName: 'SlideGroup',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'deckId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'title',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'sortKey',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'parentId',
          columnType: _isd.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isd.ColumnDefinition(
          name: 'color',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'skipped',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'slide_group_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'slide_group_fk_1',
          columns: ['deckId'],
          referenceTable: 'deck',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'slide_group_order_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'deckId',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'sortKey',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'slide_layout',
      dartName: 'SlideLayout',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'masterId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'name',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'key',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'sortKey',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'backgroundJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'hideMasterElements',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isd.ColumnDefinition(
          name: 'hidden',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'slide_layout_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'slide_layout_fk_1',
          columns: ['masterId'],
          referenceTable: 'slide_master',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'slide_layout_master_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'masterId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'slide_master',
      dartName: 'SlideMaster',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'themeId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'name',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'sortKey',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'backgroundJson',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'slide_master_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'slide_master_fk_1',
          columns: ['themeId'],
          referenceTable: 'deck_theme',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'slide_master_theme_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'themeId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'slide_table_axis',
      dartName: 'SlideTableAxis',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'elementId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'dimension',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'wonky_sync_models:TableDimension',
        ),
        _isd.ColumnDefinition(
          name: 'sortKey',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'size',
          columnType: _isd.ColumnType.doublePrecision,
          isNullable: true,
          dartType: 'double?',
        ),
        _isd.ColumnDefinition(
          name: 'header',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'slide_table_axis_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'slide_table_axis_fk_1',
          columns: ['elementId'],
          referenceTable: 'slide_element',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'slide_table_axis_element_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'elementId',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'sortKey',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'slide_table_cell',
      dartName: 'SlideTableCell',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'elementId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'rowId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'columnId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'text',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'fill',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'borderTop',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'borderRight',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'borderBottom',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'borderLeft',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'vAlign',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'padding',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'rowSpan',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'colSpan',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'slide_table_cell_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'slide_table_cell_fk_1',
          columns: ['elementId'],
          referenceTable: 'slide_element',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'slide_table_cell_fk_2',
          columns: ['rowId'],
          referenceTable: 'slide_table_axis',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'slide_table_cell_fk_3',
          columns: ['columnId'],
          referenceTable: 'slide_table_axis',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'slide_table_cell_element_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'elementId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'spreadsheet',
      dartName: 'Spreadsheet',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'spaceId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'title',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'locale',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'timeZone',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'recalcMode',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'wonky_sync_models:RecalcMode',
          columnDefault: '\'onChange\'',
        ),
        _isd.ColumnDefinition(
          name: 'iterativeCalc',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isd.ColumnDefinition(
          name: 'maxIterations',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
          columnDefault: '50',
        ),
        _isd.ColumnDefinition(
          name: 'convergenceThreshold',
          columnType: _isd.ColumnType.doublePrecision,
          isNullable: false,
          dartType: 'double',
          columnDefault: '0.05',
        ),
        _isd.ColumnDefinition(
          name: 'defaultFontFamily',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
          columnDefault: '\'Inter\'',
        ),
        _isd.ColumnDefinition(
          name: 'defaultFontSize',
          columnType: _isd.ColumnType.doublePrecision,
          isNullable: false,
          dartType: 'double',
          columnDefault: '10.0',
        ),
        _isd.ColumnDefinition(
          name: 'themeJson',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'displayLanguage',
          columnType: _isd.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isd.ColumnDefinition(
          name: 'createdBy',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'createdAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'spreadsheet_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [],
      managed: true,
    ),
  ];

  void registerHostProtocol(
    String projectName,
    _iss.SerializationManager protocol,
  ) {
    _hostProtocols.add(protocol);
  }

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    return className;
  }

  @override
  T deserialize<T>(dynamic data, [Type? t]) {
    t ??= T;

    final dataClassName = getClassNameFromObjectJson(data);
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on _iss.DeserializationClassNameNotFoundException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _igaoyygq.Banding) {
      return _igaoyygq.Banding.fromJson(data) as T;
    }
    if (t == _ir527j7r.BasicFilter) {
      return _ir527j7r.BasicFilter.fromJson(data) as T;
    }
    if (t == _ig8ot2c3.Cell) {
      return _ig8ot2c3.Cell.fromJson(data) as T;
    }
    if (t == _i49u5dee.ChangeLog) {
      return _i49u5dee.ChangeLog.fromJson(data) as T;
    }
    if (t == _iagb74mi.ConditionalFormatRule) {
      return _iagb74mi.ConditionalFormatRule.fromJson(data) as T;
    }
    if (t == _iwv9w6ou.DataValidationRule) {
      return _iwv9w6ou.DataValidationRule.fromJson(data) as T;
    }
    if (t == _ihb6cnfg.DimensionGroup) {
      return _ihb6cnfg.DimensionGroup.fromJson(data) as T;
    }
    if (t == _i1kjtrfg.EmbeddedObject) {
      return _i1kjtrfg.EmbeddedObject.fromJson(data) as T;
    }
    if (t == _iw5nkflj.ActorKind) {
      return _iw5nkflj.ActorKind.fromJson(data) as T;
    }
    if (t == _ih6mykm1.Dimension) {
      return _ih6mykm1.Dimension.fromJson(data) as T;
    }
    if (t == _ij70oqpa.EmbeddedObjectKind) {
      return _ij70oqpa.EmbeddedObjectKind.fromJson(data) as T;
    }
    if (t == _i0dpapyw.HorizontalAlign) {
      return _i0dpapyw.HorizontalAlign.fromJson(data) as T;
    }
    if (t == _ioe6j54y.RecalcMode) {
      return _ioe6j54y.RecalcMode.fromJson(data) as T;
    }
    if (t == _itrdthbz.ScriptBuildStatus) {
      return _itrdthbz.ScriptBuildStatus.fromJson(data) as T;
    }
    if (t == _ir1newq6.SheetKind) {
      return _ir1newq6.SheetKind.fromJson(data) as T;
    }
    if (t == _i4qnzfu9.TriggerKind) {
      return _i4qnzfu9.TriggerKind.fromJson(data) as T;
    }
    if (t == _iinjk5no.VerticalAlign) {
      return _iinjk5no.VerticalAlign.fromJson(data) as T;
    }
    if (t == _ijdxo9rm.WrapStrategy) {
      return _ijdxo9rm.WrapStrategy.fromJson(data) as T;
    }
    if (t == _irpnjcqz.FilterView) {
      return _irpnjcqz.FilterView.fromJson(data) as T;
    }
    if (t == _ii49uszr.Macro) {
      return _ii49uszr.Macro.fromJson(data) as T;
    }
    if (t == _i86u9dto.MergedRange) {
      return _i86u9dto.MergedRange.fromJson(data) as T;
    }
    if (t == _i5bzm6yh.NamedRange) {
      return _i5bzm6yh.NamedRange.fromJson(data) as T;
    }
    if (t == _iagznf3k.PivotTable) {
      return _iagznf3k.PivotTable.fromJson(data) as T;
    }
    if (t == _iyj10qb7.ProtectedRange) {
      return _iyj10qb7.ProtectedRange.fromJson(data) as T;
    }
    if (t == _icmt6fy2.ScriptBuild) {
      return _icmt6fy2.ScriptBuild.fromJson(data) as T;
    }
    if (t == _ix1o0is2.ScriptFile) {
      return _ix1o0is2.ScriptFile.fromJson(data) as T;
    }
    if (t == _ivqhmfft.ScriptProject) {
      return _ivqhmfft.ScriptProject.fromJson(data) as T;
    }
    if (t == _i4368ao2.ScriptProperty) {
      return _i4368ao2.ScriptProperty.fromJson(data) as T;
    }
    if (t == _i3nma2z7.ScriptTrigger) {
      return _i3nma2z7.ScriptTrigger.fromJson(data) as T;
    }
    if (t == _i28e4cu9.ScriptUserProperty) {
      return _i28e4cu9.ScriptUserProperty.fromJson(data) as T;
    }
    if (t == _ig4g76zp.Sheet) {
      return _ig4g76zp.Sheet.fromJson(data) as T;
    }
    if (t == _isl6cgsg.SheetColumn) {
      return _isl6cgsg.SheetColumn.fromJson(data) as T;
    }
    if (t == _ihygasqj.SheetRow) {
      return _ihygasqj.SheetRow.fromJson(data) as T;
    }
    if (t == _idbbyz5o.ChartLink) {
      return _idbbyz5o.ChartLink.fromJson(data) as T;
    }
    if (t == _ild4hnlk.CodeState) {
      return _ild4hnlk.CodeState.fromJson(data) as T;
    }
    if (t == _i5rkrncd.Deck) {
      return _i5rkrncd.Deck.fromJson(data) as T;
    }
    if (t == _iq02mgkm.DeckChangeLog) {
      return _iq02mgkm.DeckChangeLog.fromJson(data) as T;
    }
    if (t == _ifho1iaj.DeckTheme) {
      return _ifho1iaj.DeckTheme.fromJson(data) as T;
    }
    if (t == _i28s2inw.BuildKind) {
      return _i28s2inw.BuildKind.fromJson(data) as T;
    }
    if (t == _ihn6hgce.BuildTrigger) {
      return _ihn6hgce.BuildTrigger.fromJson(data) as T;
    }
    if (t == _i24j0uh3.DeckAppearance) {
      return _i24j0uh3.DeckAppearance.fromJson(data) as T;
    }
    if (t == _i8b7xui8.PlaceholderType) {
      return _i8b7xui8.PlaceholderType.fromJson(data) as T;
    }
    if (t == _i2w8xpqg.SlideElementKind) {
      return _i2w8xpqg.SlideElementKind.fromJson(data) as T;
    }
    if (t == _ixx3p5q7.SlideSizePreset) {
      return _ixx3p5q7.SlideSizePreset.fromJson(data) as T;
    }
    if (t == _i2fu17sc.TableDimension) {
      return _i2fu17sc.TableDimension.fromJson(data) as T;
    }
    if (t == _iad1oxgb.Slide) {
      return _iad1oxgb.Slide.fromJson(data) as T;
    }
    if (t == _i6oyv19i.SlideBuild) {
      return _i6oyv19i.SlideBuild.fromJson(data) as T;
    }
    if (t == _iiliulbi.SlideElement) {
      return _iiliulbi.SlideElement.fromJson(data) as T;
    }
    if (t == _ic4eqfvq.SlideGroup) {
      return _ic4eqfvq.SlideGroup.fromJson(data) as T;
    }
    if (t == _i1s0dhb4.SlideLayout) {
      return _i1s0dhb4.SlideLayout.fromJson(data) as T;
    }
    if (t == _ii2umwrw.SlideMaster) {
      return _ii2umwrw.SlideMaster.fromJson(data) as T;
    }
    if (t == _ie2n7e76.SlideTableAxis) {
      return _ie2n7e76.SlideTableAxis.fromJson(data) as T;
    }
    if (t == _iuzroerr.SlideTableCell) {
      return _iuzroerr.SlideTableCell.fromJson(data) as T;
    }
    if (t == _ikok0gb2.Spreadsheet) {
      return _ikok0gb2.Spreadsheet.fromJson(data) as T;
    }
    if (t == _iss.getType<_igaoyygq.Banding?>()) {
      return (data != null ? _igaoyygq.Banding.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_ir527j7r.BasicFilter?>()) {
      return (data != null ? _ir527j7r.BasicFilter.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_ig8ot2c3.Cell?>()) {
      return (data != null ? _ig8ot2c3.Cell.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_i49u5dee.ChangeLog?>()) {
      return (data != null ? _i49u5dee.ChangeLog.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_iagb74mi.ConditionalFormatRule?>()) {
      return (data != null
              ? _iagb74mi.ConditionalFormatRule.fromJson(data)
              : null)
          as T;
    }
    if (t == _iss.getType<_iwv9w6ou.DataValidationRule?>()) {
      return (data != null ? _iwv9w6ou.DataValidationRule.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_ihb6cnfg.DimensionGroup?>()) {
      return (data != null ? _ihb6cnfg.DimensionGroup.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_i1kjtrfg.EmbeddedObject?>()) {
      return (data != null ? _i1kjtrfg.EmbeddedObject.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_iw5nkflj.ActorKind?>()) {
      return (data != null ? _iw5nkflj.ActorKind.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_ih6mykm1.Dimension?>()) {
      return (data != null ? _ih6mykm1.Dimension.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_ij70oqpa.EmbeddedObjectKind?>()) {
      return (data != null ? _ij70oqpa.EmbeddedObjectKind.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_i0dpapyw.HorizontalAlign?>()) {
      return (data != null ? _i0dpapyw.HorizontalAlign.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_ioe6j54y.RecalcMode?>()) {
      return (data != null ? _ioe6j54y.RecalcMode.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_itrdthbz.ScriptBuildStatus?>()) {
      return (data != null ? _itrdthbz.ScriptBuildStatus.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_ir1newq6.SheetKind?>()) {
      return (data != null ? _ir1newq6.SheetKind.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_i4qnzfu9.TriggerKind?>()) {
      return (data != null ? _i4qnzfu9.TriggerKind.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_iinjk5no.VerticalAlign?>()) {
      return (data != null ? _iinjk5no.VerticalAlign.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_ijdxo9rm.WrapStrategy?>()) {
      return (data != null ? _ijdxo9rm.WrapStrategy.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_irpnjcqz.FilterView?>()) {
      return (data != null ? _irpnjcqz.FilterView.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_ii49uszr.Macro?>()) {
      return (data != null ? _ii49uszr.Macro.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_i86u9dto.MergedRange?>()) {
      return (data != null ? _i86u9dto.MergedRange.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_i5bzm6yh.NamedRange?>()) {
      return (data != null ? _i5bzm6yh.NamedRange.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_iagznf3k.PivotTable?>()) {
      return (data != null ? _iagznf3k.PivotTable.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_iyj10qb7.ProtectedRange?>()) {
      return (data != null ? _iyj10qb7.ProtectedRange.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_icmt6fy2.ScriptBuild?>()) {
      return (data != null ? _icmt6fy2.ScriptBuild.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_ix1o0is2.ScriptFile?>()) {
      return (data != null ? _ix1o0is2.ScriptFile.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_ivqhmfft.ScriptProject?>()) {
      return (data != null ? _ivqhmfft.ScriptProject.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_i4368ao2.ScriptProperty?>()) {
      return (data != null ? _i4368ao2.ScriptProperty.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_i3nma2z7.ScriptTrigger?>()) {
      return (data != null ? _i3nma2z7.ScriptTrigger.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_i28e4cu9.ScriptUserProperty?>()) {
      return (data != null ? _i28e4cu9.ScriptUserProperty.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_ig4g76zp.Sheet?>()) {
      return (data != null ? _ig4g76zp.Sheet.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_isl6cgsg.SheetColumn?>()) {
      return (data != null ? _isl6cgsg.SheetColumn.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_ihygasqj.SheetRow?>()) {
      return (data != null ? _ihygasqj.SheetRow.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_idbbyz5o.ChartLink?>()) {
      return (data != null ? _idbbyz5o.ChartLink.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_ild4hnlk.CodeState?>()) {
      return (data != null ? _ild4hnlk.CodeState.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_i5rkrncd.Deck?>()) {
      return (data != null ? _i5rkrncd.Deck.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_iq02mgkm.DeckChangeLog?>()) {
      return (data != null ? _iq02mgkm.DeckChangeLog.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_ifho1iaj.DeckTheme?>()) {
      return (data != null ? _ifho1iaj.DeckTheme.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_i28s2inw.BuildKind?>()) {
      return (data != null ? _i28s2inw.BuildKind.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_ihn6hgce.BuildTrigger?>()) {
      return (data != null ? _ihn6hgce.BuildTrigger.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_i24j0uh3.DeckAppearance?>()) {
      return (data != null ? _i24j0uh3.DeckAppearance.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_i8b7xui8.PlaceholderType?>()) {
      return (data != null ? _i8b7xui8.PlaceholderType.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_i2w8xpqg.SlideElementKind?>()) {
      return (data != null ? _i2w8xpqg.SlideElementKind.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_ixx3p5q7.SlideSizePreset?>()) {
      return (data != null ? _ixx3p5q7.SlideSizePreset.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_i2fu17sc.TableDimension?>()) {
      return (data != null ? _i2fu17sc.TableDimension.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_iad1oxgb.Slide?>()) {
      return (data != null ? _iad1oxgb.Slide.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_i6oyv19i.SlideBuild?>()) {
      return (data != null ? _i6oyv19i.SlideBuild.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_iiliulbi.SlideElement?>()) {
      return (data != null ? _iiliulbi.SlideElement.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_ic4eqfvq.SlideGroup?>()) {
      return (data != null ? _ic4eqfvq.SlideGroup.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_i1s0dhb4.SlideLayout?>()) {
      return (data != null ? _i1s0dhb4.SlideLayout.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_ii2umwrw.SlideMaster?>()) {
      return (data != null ? _ii2umwrw.SlideMaster.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_ie2n7e76.SlideTableAxis?>()) {
      return (data != null ? _ie2n7e76.SlideTableAxis.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_iuzroerr.SlideTableCell?>()) {
      return (data != null ? _iuzroerr.SlideTableCell.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_ikok0gb2.Spreadsheet?>()) {
      return (data != null ? _ikok0gb2.Spreadsheet.fromJson(data) : null) as T;
    }
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _igaoyygq.Banding => 'Banding',
      _ir527j7r.BasicFilter => 'BasicFilter',
      _ig8ot2c3.Cell => 'Cell',
      _i49u5dee.ChangeLog => 'ChangeLog',
      _iagb74mi.ConditionalFormatRule => 'ConditionalFormatRule',
      _iwv9w6ou.DataValidationRule => 'DataValidationRule',
      _ihb6cnfg.DimensionGroup => 'DimensionGroup',
      _i1kjtrfg.EmbeddedObject => 'EmbeddedObject',
      _iw5nkflj.ActorKind => 'ActorKind',
      _ih6mykm1.Dimension => 'Dimension',
      _ij70oqpa.EmbeddedObjectKind => 'EmbeddedObjectKind',
      _i0dpapyw.HorizontalAlign => 'HorizontalAlign',
      _ioe6j54y.RecalcMode => 'RecalcMode',
      _itrdthbz.ScriptBuildStatus => 'ScriptBuildStatus',
      _ir1newq6.SheetKind => 'SheetKind',
      _i4qnzfu9.TriggerKind => 'TriggerKind',
      _iinjk5no.VerticalAlign => 'VerticalAlign',
      _ijdxo9rm.WrapStrategy => 'WrapStrategy',
      _irpnjcqz.FilterView => 'FilterView',
      _ii49uszr.Macro => 'Macro',
      _i86u9dto.MergedRange => 'MergedRange',
      _i5bzm6yh.NamedRange => 'NamedRange',
      _iagznf3k.PivotTable => 'PivotTable',
      _iyj10qb7.ProtectedRange => 'ProtectedRange',
      _icmt6fy2.ScriptBuild => 'ScriptBuild',
      _ix1o0is2.ScriptFile => 'ScriptFile',
      _ivqhmfft.ScriptProject => 'ScriptProject',
      _i4368ao2.ScriptProperty => 'ScriptProperty',
      _i3nma2z7.ScriptTrigger => 'ScriptTrigger',
      _i28e4cu9.ScriptUserProperty => 'ScriptUserProperty',
      _ig4g76zp.Sheet => 'Sheet',
      _isl6cgsg.SheetColumn => 'SheetColumn',
      _ihygasqj.SheetRow => 'SheetRow',
      _idbbyz5o.ChartLink => 'ChartLink',
      _ild4hnlk.CodeState => 'CodeState',
      _i5rkrncd.Deck => 'Deck',
      _iq02mgkm.DeckChangeLog => 'DeckChangeLog',
      _ifho1iaj.DeckTheme => 'DeckTheme',
      _i28s2inw.BuildKind => 'BuildKind',
      _ihn6hgce.BuildTrigger => 'BuildTrigger',
      _i24j0uh3.DeckAppearance => 'DeckAppearance',
      _i8b7xui8.PlaceholderType => 'PlaceholderType',
      _i2w8xpqg.SlideElementKind => 'SlideElementKind',
      _ixx3p5q7.SlideSizePreset => 'SlideSizePreset',
      _i2fu17sc.TableDimension => 'TableDimension',
      _iad1oxgb.Slide => 'Slide',
      _i6oyv19i.SlideBuild => 'SlideBuild',
      _iiliulbi.SlideElement => 'SlideElement',
      _ic4eqfvq.SlideGroup => 'SlideGroup',
      _i1s0dhb4.SlideLayout => 'SlideLayout',
      _ii2umwrw.SlideMaster => 'SlideMaster',
      _ie2n7e76.SlideTableAxis => 'SlideTableAxis',
      _iuzroerr.SlideTableCell => 'SlideTableCell',
      _ikok0gb2.Spreadsheet => 'Spreadsheet',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst('wonky.', '');
    }

    switch (data) {
      case _igaoyygq.Banding():
        return 'Banding';
      case _ir527j7r.BasicFilter():
        return 'BasicFilter';
      case _ig8ot2c3.Cell():
        return 'Cell';
      case _i49u5dee.ChangeLog():
        return 'ChangeLog';
      case _iagb74mi.ConditionalFormatRule():
        return 'ConditionalFormatRule';
      case _iwv9w6ou.DataValidationRule():
        return 'DataValidationRule';
      case _ihb6cnfg.DimensionGroup():
        return 'DimensionGroup';
      case _i1kjtrfg.EmbeddedObject():
        return 'EmbeddedObject';
      case _iw5nkflj.ActorKind():
        return 'ActorKind';
      case _ih6mykm1.Dimension():
        return 'Dimension';
      case _ij70oqpa.EmbeddedObjectKind():
        return 'EmbeddedObjectKind';
      case _i0dpapyw.HorizontalAlign():
        return 'HorizontalAlign';
      case _ioe6j54y.RecalcMode():
        return 'RecalcMode';
      case _itrdthbz.ScriptBuildStatus():
        return 'ScriptBuildStatus';
      case _ir1newq6.SheetKind():
        return 'SheetKind';
      case _i4qnzfu9.TriggerKind():
        return 'TriggerKind';
      case _iinjk5no.VerticalAlign():
        return 'VerticalAlign';
      case _ijdxo9rm.WrapStrategy():
        return 'WrapStrategy';
      case _irpnjcqz.FilterView():
        return 'FilterView';
      case _ii49uszr.Macro():
        return 'Macro';
      case _i86u9dto.MergedRange():
        return 'MergedRange';
      case _i5bzm6yh.NamedRange():
        return 'NamedRange';
      case _iagznf3k.PivotTable():
        return 'PivotTable';
      case _iyj10qb7.ProtectedRange():
        return 'ProtectedRange';
      case _icmt6fy2.ScriptBuild():
        return 'ScriptBuild';
      case _ix1o0is2.ScriptFile():
        return 'ScriptFile';
      case _ivqhmfft.ScriptProject():
        return 'ScriptProject';
      case _i4368ao2.ScriptProperty():
        return 'ScriptProperty';
      case _i3nma2z7.ScriptTrigger():
        return 'ScriptTrigger';
      case _i28e4cu9.ScriptUserProperty():
        return 'ScriptUserProperty';
      case _ig4g76zp.Sheet():
        return 'Sheet';
      case _isl6cgsg.SheetColumn():
        return 'SheetColumn';
      case _ihygasqj.SheetRow():
        return 'SheetRow';
      case _idbbyz5o.ChartLink():
        return 'ChartLink';
      case _ild4hnlk.CodeState():
        return 'CodeState';
      case _i5rkrncd.Deck():
        return 'Deck';
      case _iq02mgkm.DeckChangeLog():
        return 'DeckChangeLog';
      case _ifho1iaj.DeckTheme():
        return 'DeckTheme';
      case _i28s2inw.BuildKind():
        return 'BuildKind';
      case _ihn6hgce.BuildTrigger():
        return 'BuildTrigger';
      case _i24j0uh3.DeckAppearance():
        return 'DeckAppearance';
      case _i8b7xui8.PlaceholderType():
        return 'PlaceholderType';
      case _i2w8xpqg.SlideElementKind():
        return 'SlideElementKind';
      case _ixx3p5q7.SlideSizePreset():
        return 'SlideSizePreset';
      case _i2fu17sc.TableDimension():
        return 'TableDimension';
      case _iad1oxgb.Slide():
        return 'Slide';
      case _i6oyv19i.SlideBuild():
        return 'SlideBuild';
      case _iiliulbi.SlideElement():
        return 'SlideElement';
      case _ic4eqfvq.SlideGroup():
        return 'SlideGroup';
      case _i1s0dhb4.SlideLayout():
        return 'SlideLayout';
      case _ii2umwrw.SlideMaster():
        return 'SlideMaster';
      case _ie2n7e76.SlideTableAxis():
        return 'SlideTableAxis';
      case _iuzroerr.SlideTableCell():
        return 'SlideTableCell';
      case _ikok0gb2.Spreadsheet():
        return 'Spreadsheet';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'Banding') {
      return deserialize<_igaoyygq.Banding>(data['data']);
    }
    if (dataClassName == 'BasicFilter') {
      return deserialize<_ir527j7r.BasicFilter>(data['data']);
    }
    if (dataClassName == 'Cell') {
      return deserialize<_ig8ot2c3.Cell>(data['data']);
    }
    if (dataClassName == 'ChangeLog') {
      return deserialize<_i49u5dee.ChangeLog>(data['data']);
    }
    if (dataClassName == 'ConditionalFormatRule') {
      return deserialize<_iagb74mi.ConditionalFormatRule>(data['data']);
    }
    if (dataClassName == 'DataValidationRule') {
      return deserialize<_iwv9w6ou.DataValidationRule>(data['data']);
    }
    if (dataClassName == 'DimensionGroup') {
      return deserialize<_ihb6cnfg.DimensionGroup>(data['data']);
    }
    if (dataClassName == 'EmbeddedObject') {
      return deserialize<_i1kjtrfg.EmbeddedObject>(data['data']);
    }
    if (dataClassName == 'ActorKind') {
      return deserialize<_iw5nkflj.ActorKind>(data['data']);
    }
    if (dataClassName == 'Dimension') {
      return deserialize<_ih6mykm1.Dimension>(data['data']);
    }
    if (dataClassName == 'EmbeddedObjectKind') {
      return deserialize<_ij70oqpa.EmbeddedObjectKind>(data['data']);
    }
    if (dataClassName == 'HorizontalAlign') {
      return deserialize<_i0dpapyw.HorizontalAlign>(data['data']);
    }
    if (dataClassName == 'RecalcMode') {
      return deserialize<_ioe6j54y.RecalcMode>(data['data']);
    }
    if (dataClassName == 'ScriptBuildStatus') {
      return deserialize<_itrdthbz.ScriptBuildStatus>(data['data']);
    }
    if (dataClassName == 'SheetKind') {
      return deserialize<_ir1newq6.SheetKind>(data['data']);
    }
    if (dataClassName == 'TriggerKind') {
      return deserialize<_i4qnzfu9.TriggerKind>(data['data']);
    }
    if (dataClassName == 'VerticalAlign') {
      return deserialize<_iinjk5no.VerticalAlign>(data['data']);
    }
    if (dataClassName == 'WrapStrategy') {
      return deserialize<_ijdxo9rm.WrapStrategy>(data['data']);
    }
    if (dataClassName == 'FilterView') {
      return deserialize<_irpnjcqz.FilterView>(data['data']);
    }
    if (dataClassName == 'Macro') {
      return deserialize<_ii49uszr.Macro>(data['data']);
    }
    if (dataClassName == 'MergedRange') {
      return deserialize<_i86u9dto.MergedRange>(data['data']);
    }
    if (dataClassName == 'NamedRange') {
      return deserialize<_i5bzm6yh.NamedRange>(data['data']);
    }
    if (dataClassName == 'PivotTable') {
      return deserialize<_iagznf3k.PivotTable>(data['data']);
    }
    if (dataClassName == 'ProtectedRange') {
      return deserialize<_iyj10qb7.ProtectedRange>(data['data']);
    }
    if (dataClassName == 'ScriptBuild') {
      return deserialize<_icmt6fy2.ScriptBuild>(data['data']);
    }
    if (dataClassName == 'ScriptFile') {
      return deserialize<_ix1o0is2.ScriptFile>(data['data']);
    }
    if (dataClassName == 'ScriptProject') {
      return deserialize<_ivqhmfft.ScriptProject>(data['data']);
    }
    if (dataClassName == 'ScriptProperty') {
      return deserialize<_i4368ao2.ScriptProperty>(data['data']);
    }
    if (dataClassName == 'ScriptTrigger') {
      return deserialize<_i3nma2z7.ScriptTrigger>(data['data']);
    }
    if (dataClassName == 'ScriptUserProperty') {
      return deserialize<_i28e4cu9.ScriptUserProperty>(data['data']);
    }
    if (dataClassName == 'Sheet') {
      return deserialize<_ig4g76zp.Sheet>(data['data']);
    }
    if (dataClassName == 'SheetColumn') {
      return deserialize<_isl6cgsg.SheetColumn>(data['data']);
    }
    if (dataClassName == 'SheetRow') {
      return deserialize<_ihygasqj.SheetRow>(data['data']);
    }
    if (dataClassName == 'ChartLink') {
      return deserialize<_idbbyz5o.ChartLink>(data['data']);
    }
    if (dataClassName == 'CodeState') {
      return deserialize<_ild4hnlk.CodeState>(data['data']);
    }
    if (dataClassName == 'Deck') {
      return deserialize<_i5rkrncd.Deck>(data['data']);
    }
    if (dataClassName == 'DeckChangeLog') {
      return deserialize<_iq02mgkm.DeckChangeLog>(data['data']);
    }
    if (dataClassName == 'DeckTheme') {
      return deserialize<_ifho1iaj.DeckTheme>(data['data']);
    }
    if (dataClassName == 'BuildKind') {
      return deserialize<_i28s2inw.BuildKind>(data['data']);
    }
    if (dataClassName == 'BuildTrigger') {
      return deserialize<_ihn6hgce.BuildTrigger>(data['data']);
    }
    if (dataClassName == 'DeckAppearance') {
      return deserialize<_i24j0uh3.DeckAppearance>(data['data']);
    }
    if (dataClassName == 'PlaceholderType') {
      return deserialize<_i8b7xui8.PlaceholderType>(data['data']);
    }
    if (dataClassName == 'SlideElementKind') {
      return deserialize<_i2w8xpqg.SlideElementKind>(data['data']);
    }
    if (dataClassName == 'SlideSizePreset') {
      return deserialize<_ixx3p5q7.SlideSizePreset>(data['data']);
    }
    if (dataClassName == 'TableDimension') {
      return deserialize<_i2fu17sc.TableDimension>(data['data']);
    }
    if (dataClassName == 'Slide') {
      return deserialize<_iad1oxgb.Slide>(data['data']);
    }
    if (dataClassName == 'SlideBuild') {
      return deserialize<_i6oyv19i.SlideBuild>(data['data']);
    }
    if (dataClassName == 'SlideElement') {
      return deserialize<_iiliulbi.SlideElement>(data['data']);
    }
    if (dataClassName == 'SlideGroup') {
      return deserialize<_ic4eqfvq.SlideGroup>(data['data']);
    }
    if (dataClassName == 'SlideLayout') {
      return deserialize<_i1s0dhb4.SlideLayout>(data['data']);
    }
    if (dataClassName == 'SlideMaster') {
      return deserialize<_ii2umwrw.SlideMaster>(data['data']);
    }
    if (dataClassName == 'SlideTableAxis') {
      return deserialize<_ie2n7e76.SlideTableAxis>(data['data']);
    }
    if (dataClassName == 'SlideTableCell') {
      return deserialize<_iuzroerr.SlideTableCell>(data['data']);
    }
    if (dataClassName == 'Spreadsheet') {
      return deserialize<_ikok0gb2.Spreadsheet>(data['data']);
    }
    return super.deserializeByClassName(data);
  }

  @override
  Object? dynamicFieldToJson(Object? object, {bool forProtocol = false}) {
    if ((object is List || object is Set || object is Map) ||
        getClassNameForObject(object) != null) {
      return super.dynamicFieldToJson(object, forProtocol: forProtocol);
    }
    for (final protocol in _hostProtocols) {
      final className = protocol.getClassNameForObject(object);
      if (className == null) continue;
      final host = protocol.getModuleName();
      final wrapped = {
        'className': className.contains('.') ? className : '$host.$className',
        'data': object,
      };
      return forProtocol
          ? _iss.SerializationManager.toEncodableForProtocol(wrapped)
          : _iss.SerializationManager.toEncodable(wrapped);
    }
    return super.dynamicFieldToJson(object, forProtocol: forProtocol);
  }

  @override
  dynamic deserializeDynamicFieldValue(Object? value) {
    if (value == null) return null;
    if (value is! Map<String, dynamic> || value['className'] is! String) {
      throw FormatException(
        'Dynamic fields are encoded as a Map with className and data, but got '
        '${value.runtimeType} instead.',
      );
    }
    final className = value['className'] as String;
    for (final protocol in _hostProtocols) {
      final host = protocol.getModuleName();
      final hostPrefix = '$host.';
      if (className.startsWith(hostPrefix)) {
        final strippedClassName = className.substring(hostPrefix.length);
        if (strippedClassName.contains('.')) {
          throw FormatException(
            'Dynamic field className must not use multiple prefixes: $className',
          );
        }
        final hostData = Map<String, dynamic>.from(value);
        hostData['className'] = strippedClassName;
        return protocol.deserializeByClassName(hostData);
      }
    }
    if (className.contains('.')) {
      for (final protocol in _hostProtocols) {
        try {
          return protocol.deserializeByClassName(value);
        } on _iss.DeserializationClassNameNotFoundException catch (_) {}
      }
    }
    return deserializeByClassName(value);
  }

  @override
  _isd.Table? getTableForType(Type t) {
    switch (t) {
      case _igaoyygq.Banding:
        return _igaoyygq.Banding.t;
      case _ir527j7r.BasicFilter:
        return _ir527j7r.BasicFilter.t;
      case _ig8ot2c3.Cell:
        return _ig8ot2c3.Cell.t;
      case _i49u5dee.ChangeLog:
        return _i49u5dee.ChangeLog.t;
      case _iagb74mi.ConditionalFormatRule:
        return _iagb74mi.ConditionalFormatRule.t;
      case _iwv9w6ou.DataValidationRule:
        return _iwv9w6ou.DataValidationRule.t;
      case _ihb6cnfg.DimensionGroup:
        return _ihb6cnfg.DimensionGroup.t;
      case _i1kjtrfg.EmbeddedObject:
        return _i1kjtrfg.EmbeddedObject.t;
      case _irpnjcqz.FilterView:
        return _irpnjcqz.FilterView.t;
      case _ii49uszr.Macro:
        return _ii49uszr.Macro.t;
      case _i86u9dto.MergedRange:
        return _i86u9dto.MergedRange.t;
      case _i5bzm6yh.NamedRange:
        return _i5bzm6yh.NamedRange.t;
      case _iagznf3k.PivotTable:
        return _iagznf3k.PivotTable.t;
      case _iyj10qb7.ProtectedRange:
        return _iyj10qb7.ProtectedRange.t;
      case _icmt6fy2.ScriptBuild:
        return _icmt6fy2.ScriptBuild.t;
      case _ix1o0is2.ScriptFile:
        return _ix1o0is2.ScriptFile.t;
      case _ivqhmfft.ScriptProject:
        return _ivqhmfft.ScriptProject.t;
      case _i4368ao2.ScriptProperty:
        return _i4368ao2.ScriptProperty.t;
      case _i3nma2z7.ScriptTrigger:
        return _i3nma2z7.ScriptTrigger.t;
      case _i28e4cu9.ScriptUserProperty:
        return _i28e4cu9.ScriptUserProperty.t;
      case _ig4g76zp.Sheet:
        return _ig4g76zp.Sheet.t;
      case _isl6cgsg.SheetColumn:
        return _isl6cgsg.SheetColumn.t;
      case _ihygasqj.SheetRow:
        return _ihygasqj.SheetRow.t;
      case _idbbyz5o.ChartLink:
        return _idbbyz5o.ChartLink.t;
      case _ild4hnlk.CodeState:
        return _ild4hnlk.CodeState.t;
      case _i5rkrncd.Deck:
        return _i5rkrncd.Deck.t;
      case _iq02mgkm.DeckChangeLog:
        return _iq02mgkm.DeckChangeLog.t;
      case _ifho1iaj.DeckTheme:
        return _ifho1iaj.DeckTheme.t;
      case _iad1oxgb.Slide:
        return _iad1oxgb.Slide.t;
      case _i6oyv19i.SlideBuild:
        return _i6oyv19i.SlideBuild.t;
      case _iiliulbi.SlideElement:
        return _iiliulbi.SlideElement.t;
      case _ic4eqfvq.SlideGroup:
        return _ic4eqfvq.SlideGroup.t;
      case _i1s0dhb4.SlideLayout:
        return _i1s0dhb4.SlideLayout.t;
      case _ii2umwrw.SlideMaster:
        return _ii2umwrw.SlideMaster.t;
      case _ie2n7e76.SlideTableAxis:
        return _ie2n7e76.SlideTableAxis.t;
      case _iuzroerr.SlideTableCell:
        return _iuzroerr.SlideTableCell.t;
      case _ikok0gb2.Spreadsheet:
        return _ikok0gb2.Spreadsheet.t;
    }
    return null;
  }

  @override
  List<_isd.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

  @override
  String getModuleName() => 'wonky';

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
