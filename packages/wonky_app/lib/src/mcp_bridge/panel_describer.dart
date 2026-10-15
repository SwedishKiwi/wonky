import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../shell/shell_services.dart';

/// Reads and operates a panel for the MCP panel tools
/// (`ui.sheets.describe_panel` / `set_panel_field` / `press_panel_button`,
/// Sheets 12 §5; `ui.slides.*_panel`, Slides 11 §5), like `ui.get_dialog`
/// does for dialogs: the panel's widget tree is walked for text inputs,
/// checkboxes, switches and buttons. Field and button ids are the widgets'
/// `ValueKey<String>`s (else the nearest keyed ancestor's, else a
/// positional id such as `text_2`), so they are the same keys the apps'
/// tests use.
///
/// (v2) Moved from Wonky Sheets to the shell so that Slides describes its
/// side panels and the docked inspector the same way ([under]).
class PanelDescriber {
  PanelDescriber._(this.panelId, this.root);

  /// The open side panel of [services] (or [panelId] when it is open),
  /// null when no panel is open.
  static PanelDescriber? of(ShellServices services, {String? panelId}) {
    final open = services.panels.activePanelId;
    if (open == null || (panelId != null && panelId != open)) return null;
    return under(open, PageStorageKey<String>('panel-body-$open'));
  }

  /// The mounted widget keyed [key] (e.g. a docked inspector) described as
  /// panel [panelId], or null when nothing with [key] is mounted.
  static PanelDescriber? under(String panelId, Key key) {
    final root = _find(WidgetsBinding.instance.rootElement, key);
    return root == null ? null : PanelDescriber._(panelId, root);
  }

  final String panelId;
  final Element root;

  static Element? _find(Element? from, Key key) {
    if (from == null) return null;
    Element? hit;
    void visit(Element e) {
      if (hit != null) return;
      if (e.widget.key == key) {
        hit = e;
        return;
      }
      e.visitChildElements(visit);
    }

    visit(from);
    return hit;
  }

  late final List<_Field> _fields = _collect();

  List<_Field> _collect() {
    final out = <_Field>[];
    final counts = <String, int>{};
    String id(Element e, String kind) {
      final own = e.widget.key;
      if (own is ValueKey<String>) return own.value;
      var depth = 0;
      String? found;
      e.visitAncestorElements((a) {
        if (identical(a, root) || depth++ > 6) return false;
        final k = a.widget.key;
        if (k is ValueKey<String>) {
          found = k.value;
          return false;
        }
        return true;
      });
      if (found != null && !out.any((f) => f.id == found)) return found!;
      final n = counts[kind] = (counts[kind] ?? 0) + 1;
      return '${kind}_$n';
    }

    void visit(Element e) {
      final w = e.widget;
      switch (w) {
        case ShadInput():
          final editable = _descendant<EditableText>(e);
          if (editable != null) {
            out.add(
              _Field(
                id(e, 'text'),
                'text',
                e,
                label: _text(w.placeholder),
                value: editable.controller.text,
                enabled: w.enabled,
              ),
            );
          }
          return;
        case EditableText():
          out.add(
            _Field(
              id(e, 'text'),
              'text',
              e,
              value: w.controller.text,
              enabled: !w.readOnly,
            ),
          );
          return;
        case ShadCheckbox():
          out.add(
            _Field(
              id(e, 'checkbox'),
              'checkbox',
              e,
              label: _text(w.label),
              value: w.value,
              enabled: w.enabled && w.onChanged != null,
            ),
          );
          return;
        case ShadSwitch():
          out.add(
            _Field(
              id(e, 'switch'),
              'switch',
              e,
              label: _text(w.label),
              value: w.value,
              enabled: w.enabled && w.onChanged != null,
            ),
          );
          return;
        case ShadButton():
          out.add(
            _Field(
              id(e, 'button'),
              'button',
              e,
              label: _textBelow(e),
              enabled: w.enabled && w.onPressed != null,
            ),
          );
          return;
        case ShadIconButton():
          out.add(
            _Field(
              id(e, 'button'),
              'button',
              e,
              label: w.semanticLabel ?? _textBelow(e),
              enabled: w.enabled && w.onPressed != null,
            ),
          );
          return;
        default:
          e.visitChildElements(visit);
      }
    }

    root.visitChildElements(visit);
    return out;
  }

  static T? _descendant<T extends Widget>(Element e) {
    T? hit;
    void visit(Element c) {
      if (hit != null) return;
      if (c.widget is T) {
        hit = c.widget as T;
        return;
      }
      c.visitChildElements(visit);
    }

    e.visitChildElements(visit);
    return hit;
  }

  static String? _text(Widget? w) => switch (w) {
    Text(:final data?) => data,
    Text(:final textSpan?) => textSpan.toPlainText(),
    _ => null,
  };

  static String? _textBelow(Element e) {
    final parts = <String>[];
    void visit(Element c) {
      final t = _text(c.widget);
      if (t != null) {
        parts.add(t);
        return;
      }
      c.visitChildElements(visit);
    }

    e.visitChildElements(visit);
    return parts.isEmpty ? null : parts.join(' ');
  }

  /// `{panel, fields: [{id, type, label, value, enabled}], buttons: [...]}`.
  Map<String, Object?> describe({String? title}) => {
    'panel': panelId,
    'title': ?title,
    'fields': [
      for (final f in _fields)
        if (f.type != 'button') f.toJson(),
    ],
    'buttons': [
      for (final f in _fields)
        if (f.type == 'button') f.toJson(),
    ],
  };

  _Field? _byId(String id) {
    for (final f in _fields) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// Sets a text field (as typed: the field's onChanged runs), a checkbox
  /// or a switch. Returns an error message, or null.
  String? setField(String id, Object? value) {
    final f = _byId(id);
    if (f == null || f.type == 'button') return 'Unknown field "$id".';
    if (!f.enabled) return 'The field "$id" is disabled.';
    switch (f.type) {
      case 'text':
        final state = _state<EditableTextState>(f.element);
        if (state == null) return 'The field "$id" is not editable.';
        final text = value == null ? '' : '$value';
        state.userUpdateTextEditingValue(
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          ),
          SelectionChangedCause.keyboard,
        );
        return null;
      case 'checkbox' || 'switch':
        if (value is! bool) return 'The field "$id" takes true or false.';
        if (f.value == value) return null;
        final w = f.element.widget;
        if (w is ShadCheckbox) w.onChanged?.call(value);
        if (w is ShadSwitch) w.onChanged?.call(value);
        return null;
    }
    return 'Unsupported field "$id".';
  }

  /// Presses a button. Returns an error message, or null.
  String? press(String id) {
    final f = _byId(id);
    if (f == null || f.type != 'button') return 'Unknown button "$id".';
    if (!f.enabled) return 'The button "$id" is disabled.';
    final w = f.element.widget;
    if (w is ShadButton) w.onPressed?.call();
    if (w is ShadIconButton) w.onPressed?.call();
    return null;
  }

  static T? _state<T extends State>(Element e) {
    T? hit;
    void visit(Element c) {
      if (hit != null) return;
      if (c is StatefulElement && c.state is T) {
        hit = c.state as T;
        return;
      }
      c.visitChildElements(visit);
    }

    visit(e);
    return hit;
  }
}

class _Field {
  _Field(
    this.id,
    this.type,
    this.element, {
    this.label,
    this.value,
    this.enabled = true,
  });

  final String id;
  final String type;
  final Element element;
  final String? label;
  final Object? value;
  final bool enabled;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'label': ?label,
    if (type != 'button') 'value': value,
    'enabled': enabled,
  };
}
