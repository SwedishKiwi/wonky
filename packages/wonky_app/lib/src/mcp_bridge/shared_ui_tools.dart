import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_core/wonky_core.dart' hide ActorKind;
import 'package:wonky_ui/wonky_ui.dart' show SyncState;

import 'package:flutter/scheduler.dart';

import '../commands/command.dart';
import '../bootstrap/app_urls.dart';
import 'ui_tool.dart';

/// The shared `ui.*` tools (suite 09 §6.2), executed in this window. Every
/// state change goes through the `CommandDispatcher` with source `mcp`, so
/// it is permission-checked and lands on the user's undo stack.
abstract final class SharedUiTools {
  static Map<String, UiToolHandler> get all => {
    'ui.get_state': getState,
    'ui.navigate': navigate,
    'ui.list_commands': listCommands,
    'ui.invoke_command': invokeCommand,
    'ui.get_menu_tree': getMenuTree,
    'ui.undo': (c, a) => _invoke(c, 'shell.edit.undo', const {}),
    'ui.redo': (c, a) => _invoke(c, 'shell.edit.redo', const {}),
    'ui.get_dialog': getDialog,
    'ui.fill_dialog': fillDialog,
    'ui.press_dialog_button': pressDialogButton,
    'ui.close_dialog': closeDialog,
    'ui.open_panel': (c, a) =>
        _invoke(c, 'shell.panels.open', {'panelId': a['panel_id']}),
    'ui.close_panel': (c, a) =>
        _invoke(c, 'shell.panels.close', {'panelId': a['panel_id']}),
    'ui.set_app_theme': (c, a) =>
        _invoke(c, 'shell.appearance.setTheme', {'mode': a['mode']}),
    'ui.screenshot': screenshot,
    'ui.get_semantics': getSemantics,
    'ui.type_text': typeText,
    'ui.press_keys': pressKeys,
    'ui.wait_for': waitFor,
    'ui.events': events,
  };

  // ----------------------------------------------------------------- state

  /// The current route of the window.
  static String routeOf(UiToolContext c) {
    try {
      return c.services.router.routerDelegate.currentConfiguration.uri
          .toString();
    } catch (_) {
      return '/';
    }
  }

  static Map<String, Object?> stateOf(UiToolContext c) {
    final s = c.services;
    final doc = s.activeDocument.value;
    final item = s.currentItem.value;
    final dialog = s.openDialogs.isEmpty ? null : s.openDialogs.last;
    final sync = doc?.syncStatus.value;
    return {
      'app': s.config.app.name,
      'route': routeOf(c),
      'signed_in_as': s.currentUser.value?.summary.displayName,
      'open_item': item == null
          ? null
          : {
              'uuid': item.uuid.uuid,
              'name': item.name,
              'kind': item.kind.name,
              'role': item.role.name,
            },
      'document': doc == null
          ? null
          : {
              'uuid': doc.itemUuid.uuid,
              'title': doc.title,
              'role': doc.role.name,
              'mode': doc.mode,
              'zoom': doc.zoom,
              'selection': doc.selectionSummary,
              'loaded': doc.isLoaded,
              // App-specific state (Sheets: active sheet, selection, …).
              'details': doc.describeState(),
              'sync': sync == null
                  ? null
                  : {
                      'state': sync.state.name,
                      'pending_changes': sync.pendingChanges,
                      'error': sync.error,
                    },
            },
      'dialog': dialog?.describe()['title'],
      'panel': s.panels.activePanelId,
      'theme': s.prefs.appTheme.name,
      'online': s.connectivity.online,
      'undo_label': s.undo.canUndo.value ? s.undo.undoLabel.value : null,
      'redo_label': s.undo.canRedo.value ? s.undo.redoLabel.value : null,
    };
  }

  static Future<UiToolResult> getState(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final state = stateOf(c);
    return UiToolResult(state, text: '${state['app']} at ${state['route']}');
  }

  static Future<UiToolResult> navigate(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final s = c.services;
    final route = a['route'] as String?;
    final uuid = a['open_item_uuid'] as String?;
    if (route == null && uuid == null) {
      throw const UiToolException(
        'invalid_args',
        'Pass route or open_item_uuid.',
      );
    }
    if (uuid != null) {
      UuidValue id;
      try {
        id = UuidValue.withValidation(uuid);
      } on FormatException {
        throw const UiToolException('invalid_args', 'Invalid uuid.');
      }
      final item = s.knownItem(id) ?? await s.drive.get(id);
      await s.openItem(item);
      c.events.add('route', {'route': routeOf(c), 'via': 'mcp'});
      return UiToolResult({
        'route': routeOf(c),
        'opened': {'uuid': item.uuid.uuid, 'name': item.name},
      }, text: 'Opened ${item.name}');
    }
    final path = route!.startsWith('/') ? route : '/$route';
    final owner = WonkyAppKind.ownerOfPath(path);
    if (owner != null && owner != s.config.app) {
      throw UiToolException(
        'unsupported',
        'That route belongs to the other app; open it with '
            'open_item_uuid (it reloads the window).',
        details: {'route': path},
      );
    }
    s.router.go(path);
    await uiSettle();
    c.events.add('route', {'route': routeOf(c), 'via': 'mcp'});
    return UiToolResult({'route': routeOf(c)}, text: 'Navigated to $path');
  }

  // -------------------------------------------------------------- commands

  static Map<String, Object?> commandJson(
    UiToolContext c,
    BuildContext context,
    Command<CommandArgs> command,
    Map<String, List<String>> menuPaths,
  ) {
    final s = c.services;
    final id = command.id.value;
    final state = s.dispatcher.stateOf(id);
    return {
      'id': id,
      'title': command.title(context),
      'description': ?command.description(context),
      'category': ?command.category(context),
      'args_schema': command.argsSchema.toJson(),
      'enabled': state.enabled,
      'checked': ?state.checked,
      'disabled_reason': ?state.disabledReason,
      'shortcut': ?s.keymap.shortcutTextOf(id),
      'menu_path': ?menuPaths[id],
      'undoable': command.isUndoable,
    };
  }

  static Future<UiToolResult> listCommands(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final context = c.requireContext();
    final query = (a['query'] as String?)?.trim();
    Map<String, List<String>> paths;
    try {
      paths = c.services.menuPaths(context);
    } catch (_) {
      paths = const {};
    }
    final commands = <Map<String, Object?>>[];
    for (final command in c.services.registry.all) {
      final json = commandJson(c, context, command, paths);
      if (query != null && query.isNotEmpty) {
        final hay = '${json['id']} ${json['title']} ${json['category'] ?? ''}';
        if (Fuzzy.match(query, hay) == null) continue;
      }
      commands.add(json);
    }
    commands.sort((x, y) => '${x['id']}'.compareTo('${y['id']}'));
    return UiToolResult({
      'commands': commands,
      'count': commands.length,
    }, text: '${commands.length} command(s)');
  }

  static Future<UiToolResult> _invoke(
    UiToolContext c,
    String id,
    Map<String, Object?> args,
  ) async {
    final s = c.services;
    try {
      final r = await s.dispatcher.invoke(
        id,
        args: args,
        source: InvocationSource.mcp,
        context: c.context,
      );
      final data = r.data;
      return UiToolResult(
        {
          'command_id': id,
          'status': r.status.name,
          'message': ?r.message,
          'data': data == null
              ? null
              : jsonDecode(jsonEncode(data, toEncodable: (o) => '$o')),
          'undo_label': s.undo.canUndo.value ? s.undo.undoLabel.value : null,
        },
        text:
            '$id: ${r.status.name}${r.message == null ? '' : ' — ${r.message}'}',
      );
    } on UnknownCommand {
      throw UiToolException(
        'not_found',
        'Unknown command "$id". Call ui.list_commands.',
      );
    } on InvalidCommandArgs catch (e) {
      throw UiToolException(
        'invalid_args',
        e.message,
        details: [for (final v in e.violations) v.toString()],
      );
    } on CommandForbidden catch (e) {
      throw UiToolException('forbidden', e.reason);
    } on CommandDisabled catch (e) {
      throw UiToolException(
        'disabled',
        e.reason ?? 'The command is disabled right now.',
      );
    } on CommandException catch (e) {
      throw UiToolException(e.code, e.message);
    }
  }

  static Future<UiToolResult> invokeCommand(
    UiToolContext c,
    Map<String, Object?> a,
  ) {
    final args = a['args'];
    return _invoke(
      c,
      a['command_id']! as String,
      args is Map ? args.cast<String, Object?>() : const {},
    );
  }

  static Future<UiToolResult> getMenuTree(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final context = c.requireContext();
    final s = c.services;
    final tree = s
        .menuRoot(context)
        .toJson(
          resolve: (item) {
            final command = s.registry.byId(item.commandId);
            final state = s.dispatcher.stateOf(item.commandId, item.args);
            return {
              'title': item.label ?? command?.title(context) ?? item.commandId,
              'enabled': state.enabled,
              'checked': ?state.checked,
              'shortcut': ?s.keymap.shortcutTextOf(item.commandId),
            };
          },
        );
    return UiToolResult({'menus': tree});
  }

  // --------------------------------------------------------------- dialogs

  static Future<UiToolResult> getDialog(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final dialogs = c.services.openDialogs;
    if (dialogs.isEmpty) {
      return const UiToolResult({'dialog': null}, text: 'No dialog is open');
    }
    final d = dialogs.last.describe();
    return UiToolResult({'dialog': d}, text: 'Dialog: ${d['title']}');
  }

  static Never _noDialog() => throw const UiToolException(
    'not_found',
    'No MCP-operable dialog is open.',
  );

  static Future<UiToolResult> fillDialog(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final dialogs = c.services.openDialogs;
    if (dialogs.isEmpty) _noDialog();
    final dialog = dialogs.last;
    final values = (a['values'] as Map?)?.cast<String, Object?>() ?? const {};
    final rejected = <String>[];
    for (final e in values.entries) {
      if (!dialog.setField(e.key, e.value)) rejected.add(e.key);
    }
    if (rejected.isNotEmpty) {
      throw UiToolException(
        'invalid_args',
        'Unknown fields or invalid values: ${rejected.join(', ')}.',
        details: {'fields': rejected, 'dialog': dialog.describe()},
      );
    }
    await uiSettle();
    return UiToolResult({'dialog': dialog.describe()});
  }

  static Future<UiToolResult> pressDialogButton(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final dialogs = c.services.openDialogs;
    if (dialogs.isEmpty) _noDialog();
    final dialog = dialogs.last;
    final id = a['button_id']! as String;
    if (!dialog.press(id)) {
      throw UiToolException(
        'invalid_args',
        'Unknown button "$id".',
        details: {'dialog': dialog.describe()},
      );
    }
    await uiSettle();
    c.events.add('dialog', {'pressed': id});
    return UiToolResult({
      'pressed': id,
      'dialog_open': c.services.openDialogs.contains(dialog),
    }, text: 'Pressed $id');
  }

  static Future<UiToolResult> closeDialog(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final nav = c.services.navigatorKey.currentState;
    final popped = await nav?.maybePop() ?? false;
    await uiSettle();
    return UiToolResult({'closed': popped});
  }

  // ------------------------------------------------------------ screenshot

  static Future<UiToolResult> screenshot(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final object = c.boundaryKey.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) {
      throw const UiToolException('unavailable', 'Nothing to capture yet.');
    }
    await uiSettle();
    final size = object.size;
    var scale = (a['scale'] as num?)?.toDouble() ?? 1.0;
    // Keep messages reasonable (≤ ~4 megapixels).
    const maxPixels = 4000000;
    final pixels = size.width * size.height * scale * scale;
    if (pixels > maxPixels) scale *= maxPixels / pixels;
    var image = await object.toImage(pixelRatio: scale);
    final region = a['region'];
    if (region is Map) {
      final r = Rect.fromLTWH(
        (region['x'] as num).toDouble(),
        (region['y'] as num).toDouble(),
        (region['width'] as num).toDouble(),
        (region['height'] as num).toDouble(),
      ).intersect(Offset.zero & size);
      if (r.isEmpty) {
        throw const UiToolException(
          'invalid_args',
          'The region is outside the window.',
        );
      }
      final src = Rect.fromLTWH(
        r.left * scale,
        r.top * scale,
        r.width * scale,
        r.height * scale,
      );
      final recorder = ui.PictureRecorder();
      Canvas(
        recorder,
      ).drawImageRect(image, src, Offset.zero & src.size, Paint());
      final cropped = await recorder.endRecording().toImage(
        src.width.round(),
        src.height.round(),
      );
      image.dispose();
      image = cropped;
    }
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final width = image.width;
    final height = image.height;
    image.dispose();
    if (bytes == null) {
      throw const UiToolException('unavailable', 'Encoding failed.');
    }
    return UiToolResult(
      {'width': width, 'height': height, 'scale': scale},
      text: 'Screenshot ${width}x$height',
      imageBase64: base64Encode(bytes.buffer.asUint8List()),
    );
  }

  // ------------------------------------------------------------- semantics

  static Future<UiToolResult> getSemantics(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final handle = SemanticsBinding.instance.ensureSemantics();
    try {
      WidgetsBinding.instance.scheduleFrame();
      await uiSettle();
      final views = RendererBinding.instance.renderViews;
      final root = views.isEmpty
          ? null
          : views.first.owner?.semanticsOwner?.rootSemanticsNode;
      if (root == null) {
        throw const UiToolException('unavailable', 'No semantics tree yet.');
      }
      var count = 0;
      const maxNodes = 2500;
      Map<String, Object?>? walk(SemanticsNode node, Matrix4 parent) {
        if (count >= maxNodes) return null;
        final transform = node.transform == null
            ? parent
            : (parent.clone()..multiply(node.transform!));
        final children = <Map<String, Object?>>[];
        node.visitChildren((child) {
          final j = walk(child, transform);
          if (j != null) children.add(j);
          return count < maxNodes;
        });
        final data = node.getSemanticsData();
        final hasContent =
            data.label.isNotEmpty ||
            data.value.isNotEmpty ||
            data.hint.isNotEmpty ||
            data.tooltip.isNotEmpty ||
            data.actions != 0;
        if (!hasContent && children.length == 1) return children.single;
        if (!hasContent && children.isEmpty) return null;
        count++;
        final rect = MatrixUtils.transformRect(transform, node.rect);
        return {
          'id': node.id,
          if (data.label.isNotEmpty) 'label': data.label,
          if (data.value.isNotEmpty) 'value': data.value,
          if (data.hint.isNotEmpty) 'hint': data.hint,
          if (data.tooltip.isNotEmpty) 'tooltip': data.tooltip,
          if (data.identifier.isNotEmpty) 'identifier': data.identifier,
          'role': data.role.name,
          'actions': [
            for (final action in SemanticsAction.values)
              if (data.hasAction(action)) action.name,
          ],
          'bounds': [
            rect.left.roundToDouble(),
            rect.top.roundToDouble(),
            rect.width.roundToDouble(),
            rect.height.roundToDouble(),
          ],
          if (children.isNotEmpty) 'children': children,
        };
      }

      final tree = walk(root, Matrix4.identity());
      return UiToolResult({
        'tree': tree,
        'nodes': count,
        'truncated': count >= maxNodes,
      }, text: '$count semantics nodes');
    } finally {
      handle.dispose();
    }
  }

  // ------------------------------------------------------------- keyboard

  static Future<UiToolResult> typeText(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final text = a['text']! as String;
    final focus = FocusManager.instance.primaryFocus;
    final editable = focus?.context
        ?.findAncestorStateOfType<EditableTextState>();
    if (editable != null) {
      final v = editable.textEditingValue;
      final sel = v.selection.isValid
          ? v.selection
          : TextSelection.collapsed(offset: v.text.length);
      final next = v.replaced(sel, text);
      editable.userUpdateTextEditingValue(next, SelectionChangedCause.keyboard);
      await uiSettle();
      return UiToolResult({'typed': text.length, 'target': 'text_field'});
    }
    final s = c.services;
    if (s.activeDocument.value != null &&
        s.registry.byId('write.edit.insertText') != null) {
      final r = await _invoke(c, 'write.edit.insertText', {'text': text});
      return UiToolResult({
        ...r.result,
        'typed': text.length,
        'target': 'document',
      });
    }
    throw const UiToolException(
      'unsupported',
      'No focused text field accepts text. Focus one first or use a command.',
    );
  }

  static const _named = <String, (LogicalKeyboardKey, PhysicalKeyboardKey)>{
    'enter': (LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter),
    'return': (LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter),
    'escape': (LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape),
    'esc': (LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape),
    'tab': (LogicalKeyboardKey.tab, PhysicalKeyboardKey.tab),
    'space': (LogicalKeyboardKey.space, PhysicalKeyboardKey.space),
    'backspace': (LogicalKeyboardKey.backspace, PhysicalKeyboardKey.backspace),
    'delete': (LogicalKeyboardKey.delete, PhysicalKeyboardKey.delete),
    'arrowup': (LogicalKeyboardKey.arrowUp, PhysicalKeyboardKey.arrowUp),
    'up': (LogicalKeyboardKey.arrowUp, PhysicalKeyboardKey.arrowUp),
    'arrowdown': (LogicalKeyboardKey.arrowDown, PhysicalKeyboardKey.arrowDown),
    'down': (LogicalKeyboardKey.arrowDown, PhysicalKeyboardKey.arrowDown),
    'arrowleft': (LogicalKeyboardKey.arrowLeft, PhysicalKeyboardKey.arrowLeft),
    'left': (LogicalKeyboardKey.arrowLeft, PhysicalKeyboardKey.arrowLeft),
    'arrowright': (
      LogicalKeyboardKey.arrowRight,
      PhysicalKeyboardKey.arrowRight,
    ),
    'right': (LogicalKeyboardKey.arrowRight, PhysicalKeyboardKey.arrowRight),
    'home': (LogicalKeyboardKey.home, PhysicalKeyboardKey.home),
    'end': (LogicalKeyboardKey.end, PhysicalKeyboardKey.end),
    'pageup': (LogicalKeyboardKey.pageUp, PhysicalKeyboardKey.pageUp),
    'pagedown': (LogicalKeyboardKey.pageDown, PhysicalKeyboardKey.pageDown),
    'f1': (LogicalKeyboardKey.f1, PhysicalKeyboardKey.f1),
    'f6': (LogicalKeyboardKey.f6, PhysicalKeyboardKey.f6),
    'f10': (LogicalKeyboardKey.f10, PhysicalKeyboardKey.f10),
  };

  static const _letters = 'abcdefghijklmnopqrstuvwxyz';
  static const _digits = '1234567890';

  static (LogicalKeyboardKey, PhysicalKeyboardKey, String?)? _key(String k) {
    final lower = k.toLowerCase();
    final named = _named[lower];
    if (named != null) {
      return (named.$1, named.$2, lower == 'space' ? ' ' : null);
    }
    if (k.length != 1) return null;
    final li = _letters.indexOf(lower);
    if (li >= 0) {
      return (
        LogicalKeyboardKey(lower.codeUnitAt(0)),
        PhysicalKeyboardKey(0x00070004 + li),
        k,
      );
    }
    final di = _digits.indexOf(lower);
    if (di >= 0) {
      return (
        LogicalKeyboardKey(lower.codeUnitAt(0)),
        PhysicalKeyboardKey(0x0007001e + di),
        k,
      );
    }
    final punct = <String, (LogicalKeyboardKey, PhysicalKeyboardKey)>{
      '/': (LogicalKeyboardKey.slash, PhysicalKeyboardKey.slash),
      '.': (LogicalKeyboardKey.period, PhysicalKeyboardKey.period),
      ',': (LogicalKeyboardKey.comma, PhysicalKeyboardKey.comma),
      '[': (LogicalKeyboardKey.bracketLeft, PhysicalKeyboardKey.bracketLeft),
      ']': (LogicalKeyboardKey.bracketRight, PhysicalKeyboardKey.bracketRight),
      '-': (LogicalKeyboardKey.minus, PhysicalKeyboardKey.minus),
      '=': (LogicalKeyboardKey.equal, PhysicalKeyboardKey.equal),
      '\\': (LogicalKeyboardKey.backslash, PhysicalKeyboardKey.backslash),
    }[k];
    return punct == null ? null : (punct.$1, punct.$2, k);
  }

  static bool _dispatch(KeyEvent event) {
    var node = FocusManager.instance.primaryFocus;
    while (node != null) {
      final r = node.onKeyEvent?.call(node, event);
      if (r == KeyEventResult.handled) return true;
      if (r == KeyEventResult.skipRemainingHandlers) return false;
      node = node.parent;
    }
    return false;
  }

  static Future<UiToolResult> pressKeys(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final chords = [for (final k in a['keys']! as List) '$k'];
    final mac =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final results = <Map<String, Object?>>[];
    for (final chord in chords) {
      final parts = chord.split('+').map((p) => p.trim()).toList();
      final keyName = parts.removeLast();
      final mods = <(LogicalKeyboardKey, PhysicalKeyboardKey)>[];
      for (final m in parts) {
        switch (m.toLowerCase()) {
          case 'mod':
            mods.add(
              mac
                  ? (LogicalKeyboardKey.metaLeft, PhysicalKeyboardKey.metaLeft)
                  : (
                      LogicalKeyboardKey.controlLeft,
                      PhysicalKeyboardKey.controlLeft,
                    ),
            );
          case 'ctrl' || 'control':
            mods.add((
              LogicalKeyboardKey.controlLeft,
              PhysicalKeyboardKey.controlLeft,
            ));
          case 'shift':
            mods.add((
              LogicalKeyboardKey.shiftLeft,
              PhysicalKeyboardKey.shiftLeft,
            ));
          case 'alt' || 'option':
            mods.add((LogicalKeyboardKey.altLeft, PhysicalKeyboardKey.altLeft));
          case 'meta' || 'cmd' || 'command':
            mods.add((
              LogicalKeyboardKey.metaLeft,
              PhysicalKeyboardKey.metaLeft,
            ));
          default:
            throw UiToolException('invalid_args', 'Unknown modifier "$m".');
        }
      }
      final key = keyName.isEmpty ? null : _key(keyName);
      if (key == null) {
        throw UiToolException('invalid_args', 'Unknown key "$keyName".');
      }
      final keyboard = HardwareKeyboard.instance;
      const t = Duration.zero;
      for (final m in mods) {
        keyboard.handleKeyEvent(
          KeyDownEvent(physicalKey: m.$2, logicalKey: m.$1, timeStamp: t),
        );
      }
      final printable =
          mods.isEmpty ||
          mods.every((m) => m.$1 == LogicalKeyboardKey.shiftLeft);
      final down = KeyDownEvent(
        physicalKey: key.$2,
        logicalKey: key.$1,
        character: printable ? key.$3 : null,
        timeStamp: t,
      );
      var handled = false;
      try {
        keyboard.handleKeyEvent(down);
        handled = _dispatch(down);
        final up = KeyUpEvent(
          physicalKey: key.$2,
          logicalKey: key.$1,
          timeStamp: t,
        );
        keyboard.handleKeyEvent(up);
        _dispatch(up);
      } finally {
        for (final m in mods.reversed) {
          keyboard.handleKeyEvent(
            KeyUpEvent(physicalKey: m.$2, logicalKey: m.$1, timeStamp: t),
          );
        }
      }
      results.add({'keys': chord, 'handled': handled});
      await uiSettle();
    }
    return UiToolResult({'results': results});
  }

  // -------------------------------------------------------------- waiting

  static bool _condition(UiToolContext c, String condition, String? pattern) {
    final s = c.services;
    switch (condition) {
      case 'idle':
        final doc = s.activeDocument.value;
        return !SchedulerBinding.instance.hasScheduledFrame &&
            (doc == null || doc.isLoaded);
      case 'synced':
        final doc = s.activeDocument.value;
        if (doc == null) return true;
        final st = doc.syncStatus.value;
        return doc.isLoaded &&
            st.state == SyncState.saved &&
            st.pendingChanges == 0;
      case 'dialog_open':
        return s.openDialogs.isNotEmpty;
      case 'route_matches':
        if (pattern == null) {
          throw const UiToolException(
            'invalid_args',
            'route_matches needs pattern.',
          );
        }
        return RegExp(pattern).hasMatch(routeOf(c));
      default:
        throw UiToolException('invalid_args', 'Unknown condition $condition.');
    }
  }

  static Future<UiToolResult> waitFor(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final condition = a['condition']! as String;
    final pattern = a['pattern'] as String?;
    final timeout = Duration(
      milliseconds: (a['timeout_ms'] as num?)?.toInt() ?? 30000,
    );
    final watch = Stopwatch()..start();
    while (!_condition(c, condition, pattern)) {
      if (watch.elapsed >= timeout) {
        throw UiToolException(
          'timeout',
          'Condition $condition not met within ${timeout.inMilliseconds} ms.',
          details: {'state': stateOf(c)},
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return UiToolResult({
      'condition': condition,
      'met': true,
      'waited_ms': watch.elapsedMilliseconds,
    });
  }

  static Future<UiToolResult> events(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final cursor = (a['cursor'] as num?)?.toInt();
    final list = c.events.since(cursor);
    return UiToolResult({
      'events': [for (final e in list) e.toJson()],
      'next_cursor': c.events.lastSeq,
    }, text: '${list.length} event(s)');
  }
}
