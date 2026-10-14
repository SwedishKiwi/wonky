import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

/// The exact-date input of date conditions (06 §15.2): a text field (any
/// date the spreadsheet locale parses, or a `=formula`) with a calendar
/// button that fills in an ISO date.
class CfDateField extends StatefulWidget {
  const CfDateField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.pickLabel,
    this.placeholder,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String pickLabel;
  final String? placeholder;

  @override
  State<CfDateField> createState() => _CfDateFieldState();
}

class _CfDateFieldState extends State<CfDateField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value,
  );
  final _popover = ShadPopoverController();

  @override
  void didUpdateWidget(CfDateField old) {
    super.didUpdateWidget(old);
    if (widget.value != _text.text) _text.text = widget.value;
  }

  @override
  void dispose() {
    _text.dispose();
    _popover.dispose();
    super.dispose();
  }

  /// The ISO date typed in the field, if any.
  DateTime? get _selected {
    final m = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2})$',
    ).firstMatch(_text.text.trim());
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }

  static String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return ShadInput(
      controller: _text,
      placeholder: widget.placeholder == null
          ? null
          : Text(widget.placeholder!),
      onChanged: widget.onChanged,
      trailing: ShadPopover(
        controller: _popover,
        popover: (context) => ShadCalendar(
          key: const ValueKey<String>('cf.date.calendar'),
          selected: selected,
          initialMonth: selected,
          onChanged: (d) {
            if (d == null) return;
            _popover.hide();
            final t = iso(d);
            _text.text = t;
            widget.onChanged(t);
          },
        ),
        child: ShadTooltip(
          builder: (_) => Text(widget.pickLabel),
          child: ShadIconButton.ghost(
            key: const ValueKey<String>('cf.date.pick'),
            width: 26,
            height: 26,
            iconSize: 15,
            semanticLabel: widget.pickLabel,
            icon: const Icon(LucideIcons.calendar),
            onPressed: _popover.toggle,
          ),
        ),
      ),
    );
  }
}
