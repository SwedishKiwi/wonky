import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

import '../../commands/sheets_command.dart' show editorOfServices;
import '../../l10n/sheets_l10n.dart';
import '../macros/macro_service.dart';
import 'script_project.dart';
import 'script_service.dart';

/// Menu ids of the scripting entries (stable for MCP `ui.get_menu_tree`).
abstract final class ScriptMenuIds {
  static const extensions = 'extensions';
  static const macros = 'extensions.macros';
  static const scripts = 'extensions.scripts';

  /// Top-level menu [i] added by a script.
  static String scriptMenu(int i) => 'script.menu.$i';
}

/// The menubar with the active spreadsheet's script additions (09 §15,
/// §16.1): the macro list under *Extensions › Macros*, *Script settings*,
/// and each custom menu of the last `onOpen` under *Extensions* and — when
/// "Show script menus in menubar" is on — as a top-level menu after
/// *Extensions* (max 10 menus, 50 items, depth 3). Items run
/// `sheets.script.runMenuItem`.
MenuRoot withScriptMenus(MenuRoot root, BuildContext context) {
  final s = ShellScope.maybeOf(context);
  final ed = s == null ? null : editorOfServices(s);
  final svc = ScriptService.maybeOf(ed);
  if (ed == null || svc == null) return root;
  final l = sheetsL10n(context);
  var out = root;
  if (out.find('sheets.script.openExecutions') != null) {
    out = out.insertAfter('sheets.script.openExecutions', [
      MenuSpec.command('sheets.script.openSettings'),
    ]);
  }
  final macros = svc.macros;
  if (macros.isNotEmpty && out.find(ScriptMenuIds.macros) != null) {
    out = out.appendTo(ScriptMenuIds.macros, [
      MenuSpec.separator(),
      for (final m in macros)
        MenuSpec.command(
          macroCommandId(m.id),
          id: 'extensions.macros.${m.id}',
          label: ScriptProjectRows.nameOf(m),
        ),
    ]);
  }
  final menus = svc.menus.take(10).toList();
  if (menus.isEmpty) return out;
  List<MenuSpec> items(List<ScriptMenuItem> list, String prefix, int depth) {
    final specs = <MenuSpec>[];
    for (var i = 0; i < list.length && i < 50; i++) {
      final it = list[i];
      final id = '$prefix.$i';
      if (it.separator) {
        specs.add(MenuSpec.separator(id: id));
      } else if (it.functionName != null) {
        specs.add(
          MenuSpec.command(
            'sheets.script.runMenuItem',
            id: id,
            label: it.caption,
            args: {'functionName': it.functionName, 'caption': it.caption},
          ),
        );
      } else if (depth < 3) {
        specs.add(
          MenuSpec.submenu(
            id,
            it.caption ?? '',
            items(it.items, id, depth + 1),
          ),
        );
      }
    }
    return specs;
  }

  if (out.find(ScriptMenuIds.extensions) != null) {
    out = out.appendTo(ScriptMenuIds.extensions, [
      MenuSpec.separator(),
      MenuSpec.label(l.menuScriptMenus),
      for (var i = 0; i < menus.length; i++)
        MenuSpec.submenu(
          'extensions.script.$i',
          menus[i].caption,
          items(menus[i].items, 'extensions.script.$i', 2),
        ),
    ]);
  }
  if (svc.showMenusInMenubar) {
    out = out.insertMenusBefore(ShellMenuIds.help, [
      for (var i = 0; i < menus.length; i++)
        MenuSpec.submenu(
          ScriptMenuIds.scriptMenu(i),
          menus[i].caption,
          items(menus[i].items, ScriptMenuIds.scriptMenu(i), 1),
        ),
    ]);
  }
  return out;
}
