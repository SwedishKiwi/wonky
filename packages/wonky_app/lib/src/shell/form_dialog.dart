import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import 'shell_scope.dart';
import 'shell_services.dart';

/// A dialog the MCP UI bridge can read and operate (suite 09 §6.2).
abstract class McpDescribableDialog {
  /// `{title, fields: [{id, label, type, value, options}], buttons: [...]}`.
  Map<String, Object?> describe();

  /// Sets a field; returns false for unknown ids or invalid values.
  bool setField(String id, Object? value);

  /// Presses a button; returns false for unknown ids.
  bool press(String buttonId);
}

/// A field of a [WonkyDialogSpec].
sealed class DialogFieldSpec {
  const DialogFieldSpec({required this.id, required this.label});

  final String id;
  final String label;
}

class TextFieldSpec extends DialogFieldSpec {
  const TextFieldSpec({
    required super.id,
    required super.label,
    this.initial = '',
    this.placeholder,
    this.validator,
    this.selectAll = true,
    this.maxLength,
    this.multiline = false,
    this.obscure = false,
  });

  final String initial;
  final String? placeholder;

  /// Returns an error message or null.
  final String? Function(String value)? validator;
  final bool selectAll;
  final int? maxLength;
  final bool multiline;
  final bool obscure;
}

class CheckboxFieldSpec extends DialogFieldSpec {
  const CheckboxFieldSpec({
    required super.id,
    required super.label,
    this.initial = false,
  });

  final bool initial;
}

class SelectFieldSpec extends DialogFieldSpec {
  const SelectFieldSpec({
    required super.id,
    required super.label,
    required this.options,
    required this.initial,
  });

  /// value → label.
  final Map<String, String> options;
  final String initial;
}

/// A dialog button.
class DialogButtonSpec {
  const DialogButtonSpec({
    required this.id,
    required this.label,
    this.primary = false,
    this.destructive = false,
    this.validates = true,
  });

  final String id;
  final String label;
  final bool primary;
  final bool destructive;

  /// Run field validators first.
  final bool validates;
}

/// A declarative dialog (title, fields, buttons) rendered by
/// [WonkyFormDialog]; automatically MCP-operable.
class WonkyDialogSpec {
  const WonkyDialogSpec({
    required this.title,
    this.description,
    this.fields = const [],
    required this.buttons,
    this.cancelId = 'cancel',
    this.width = 420,
    this.dialogKey,
  });

  final String title;
  final String? description;
  final List<DialogFieldSpec> fields;
  final List<DialogButtonSpec> buttons;

  /// The button id reported for Esc / close.
  final String cancelId;
  final double width;

  /// Stable key prefix for widgets (`dialog.rename`).
  final String? dialogKey;
}

/// What the user chose.
class DialogResult {
  const DialogResult(this.buttonId, this.values);

  final String buttonId;
  final Map<String, Object?> values;

  String text(String id) => '${values[id] ?? ''}';
  bool flag(String id) => values[id] == true;
}

/// Shows [spec]; resolves with the pressed button and field values (null
/// when dismissed).
Future<DialogResult?> showWonkyFormDialog(
  BuildContext context,
  WonkyDialogSpec spec,
) => showShadDialog<DialogResult>(
  context: context,
  builder: (_) => WonkyFormDialog(spec: spec),
);

/// Renders a [WonkyDialogSpec] with shad widgets.
class WonkyFormDialog extends StatefulWidget {
  const WonkyFormDialog({super.key, required this.spec});

  final WonkyDialogSpec spec;

  @override
  State<WonkyFormDialog> createState() => _WonkyFormDialogState();
}

class _WonkyFormDialogState extends State<WonkyFormDialog>
    implements McpDescribableDialog {
  ShellServices? _registeredIn;
  final Map<String, TextEditingController> _text = {};
  final Map<String, Object?> _values = {};
  final Map<String, String?> _errors = {};

  @override
  void initState() {
    super.initState();
    for (final f in widget.spec.fields) {
      switch (f) {
        case TextFieldSpec():
          final c = TextEditingController(text: f.initial);
          if (f.selectAll) {
            c.selection = TextSelection(
              baseOffset: 0,
              extentOffset: f.initial.length,
            );
          }
          _text[f.id] = c;
        case CheckboxFieldSpec():
          _values[f.id] = f.initial;
        case SelectFieldSpec():
          _values[f.id] = f.initial;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = ShellScope.maybeOf(context);
    _registeredIn = s;
    if (s != null && !s.openDialogs.contains(this)) s.openDialogs.add(this);
  }

  @override
  void dispose() {
    _registeredIn?.openDialogs.remove(this);
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, Object?> get _all => {
    ..._values,
    for (final e in _text.entries) e.key: e.value.text,
  };

  bool _validate() {
    var ok = true;
    for (final f in widget.spec.fields) {
      if (f is TextFieldSpec && f.validator != null) {
        final e = f.validator!(_text[f.id]!.text);
        _errors[f.id] = e;
        if (e != null) ok = false;
      }
    }
    setState(() {});
    return ok;
  }

  void _press(DialogButtonSpec b) {
    if (b.id != widget.spec.cancelId && b.validates && !_validate()) return;
    Navigator.of(context).pop(DialogResult(b.id, _all));
  }

  DialogButtonSpec? get _primary {
    for (final b in widget.spec.buttons) {
      if (b.primary) return b;
    }
    return null;
  }

  @override
  Map<String, Object?> describe() => {
    'title': widget.spec.title,
    if (widget.spec.description != null) 'description': widget.spec.description,
    'fields': [
      for (final f in widget.spec.fields)
        {
          'id': f.id,
          'label': f.label,
          'type': switch (f) {
            TextFieldSpec() => 'text',
            CheckboxFieldSpec() => 'checkbox',
            SelectFieldSpec() => 'select',
          },
          'value': _all[f.id],
          if (f is SelectFieldSpec) 'options': f.options.keys.toList(),
          if (_errors[f.id] != null) 'error': _errors[f.id],
        },
    ],
    'buttons': [
      for (final b in widget.spec.buttons) {'id': b.id, 'label': b.label},
    ],
  };

  @override
  bool setField(String id, Object? value) {
    final f = widget.spec.fields.where((f) => f.id == id).firstOrNull;
    switch (f) {
      case TextFieldSpec():
        _text[id]!.text = '${value ?? ''}';
      case CheckboxFieldSpec():
        if (value is! bool) return false;
        setState(() => _values[id] = value);
      case SelectFieldSpec():
        if (!f.options.containsKey(value)) return false;
        setState(() => _values[id] = value);
      case null:
        return false;
    }
    return true;
  }

  @override
  bool press(String buttonId) {
    final b = widget.spec.buttons.where((b) => b.id == buttonId).firstOrNull;
    if (b == null) return false;
    _press(b);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final theme = ShadTheme.of(context);
    final key = spec.dialogKey;
    var first = true;
    final fields = <Widget>[];
    for (final f in spec.fields) {
      final autofocus = first;
      first = false;
      switch (f) {
        case TextFieldSpec():
          fields.add(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (f.label.isNotEmpty) ...[
                  Text(f.label, style: theme.textTheme.small),
                  const SizedBox(height: 6),
                ],
                ShadInput(
                  key: key == null ? null : ValueKey<String>('$key.${f.id}'),
                  controller: _text[f.id],
                  autofocus: autofocus,
                  placeholder: f.placeholder == null
                      ? null
                      : Text(f.placeholder!),
                  maxLength: f.maxLength,
                  obscureText: f.obscure,
                  maxLines: f.multiline ? 5 : 1,
                  minLines: f.multiline ? 3 : 1,
                  onSubmitted: f.multiline
                      ? null
                      : (_) {
                          final p = _primary;
                          if (p != null) _press(p);
                        },
                  onChanged: (_) {
                    if (_errors[f.id] != null) {
                      setState(() => _errors[f.id] = null);
                    }
                  },
                ),
                if (_errors[f.id] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _errors[f.id]!,
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.destructive,
                    ),
                  ),
                ],
              ],
            ),
          );
        case CheckboxFieldSpec():
          fields.add(
            ShadCheckbox(
              key: key == null ? null : ValueKey<String>('$key.${f.id}'),
              value: _values[f.id] == true,
              onChanged: (v) => setState(() => _values[f.id] = v),
              label: Text(f.label),
            ),
          );
        case SelectFieldSpec():
          fields.add(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(f.label, style: theme.textTheme.small),
                const SizedBox(height: 6),
                ShadSelect<String>(
                  key: key == null ? null : ValueKey<String>('$key.${f.id}'),
                  initialValue: _values[f.id] as String?,
                  options: [
                    for (final o in f.options.entries)
                      ShadOption(value: o.key, child: Text(o.value)),
                  ],
                  selectedOptionBuilder: (context, v) =>
                      Text(f.options[v] ?? v),
                  onChanged: (v) => setState(() => _values[f.id] = v),
                ),
              ],
            ),
          );
      }
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: ShadDialog(
        key: key == null ? null : ValueKey<String>(key),
        title: Text(spec.title),
        description: spec.description == null ? null : Text(spec.description!),
        actions: [
          for (final b in spec.buttons)
            b.primary
                ? (b.destructive
                      ? ShadButton.destructive(
                          key: key == null
                              ? null
                              : ValueKey<String>('$key.${b.id}'),
                          onPressed: () => _press(b),
                          child: Text(b.label),
                        )
                      : ShadButton(
                          key: key == null
                              ? null
                              : ValueKey<String>('$key.${b.id}'),
                          onPressed: () => _press(b),
                          child: Text(b.label),
                        ))
                : ShadButton.outline(
                    key: key == null ? null : ValueKey<String>('$key.${b.id}'),
                    onPressed: () => _press(b),
                    child: Text(b.label),
                  ),
        ],
        child: SizedBox(
          width: spec.width,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: fields,
            ),
          ),
        ),
      ),
    );
  }
}
