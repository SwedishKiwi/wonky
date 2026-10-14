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

/// How a script execution was started (Sheets 09 §8.1, §13.1).
enum ScriptExecutionKind implements _isc.SerializableModel {
  editor,
  menu,
  macro,
  customFunction,
  onOpen,
  onEdit,
  onSelectionChange,
  onChange,
  timeDriven,
  installableOnEdit,
  installableOnChange,
  installableOnOpen,
  mcp,
  ai;

  static ScriptExecutionKind fromJson(String name) {
    switch (name) {
      case 'editor':
        return ScriptExecutionKind.editor;
      case 'menu':
        return ScriptExecutionKind.menu;
      case 'macro':
        return ScriptExecutionKind.macro;
      case 'customFunction':
        return ScriptExecutionKind.customFunction;
      case 'onOpen':
        return ScriptExecutionKind.onOpen;
      case 'onEdit':
        return ScriptExecutionKind.onEdit;
      case 'onSelectionChange':
        return ScriptExecutionKind.onSelectionChange;
      case 'onChange':
        return ScriptExecutionKind.onChange;
      case 'timeDriven':
        return ScriptExecutionKind.timeDriven;
      case 'installableOnEdit':
        return ScriptExecutionKind.installableOnEdit;
      case 'installableOnChange':
        return ScriptExecutionKind.installableOnChange;
      case 'installableOnOpen':
        return ScriptExecutionKind.installableOnOpen;
      case 'mcp':
        return ScriptExecutionKind.mcp;
      case 'ai':
        return ScriptExecutionKind.ai;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "ScriptExecutionKind"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
