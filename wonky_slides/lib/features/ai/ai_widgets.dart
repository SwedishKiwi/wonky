import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

/// A labelled form row of the AI dialogs.
class AiField extends StatelessWidget {
  const AiField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        Text(label, style: theme.textTheme.small),
        child,
      ],
    );
  }
}

/// A select of [values] (keys `<id>.<value>`, options `<id>.option.<v>`).
Widget aiSelect<T>({
  required String id,
  required T value,
  required List<T> values,
  required String Function(T) text,
  required void Function(T) onChanged,
  double minWidth = 140,
  bool enabled = true,
}) => ShadSelect<T>(
  key: ValueKey<String>('$id.$value'),
  enabled: enabled,
  initialValue: values.contains(value) ? value : values.first,
  minWidth: minWidth,
  options: [
    for (final v in values)
      ShadOption<T>(
        key: ValueKey<String>('$id.option.$v'),
        value: v,
        child: Text(text(v)),
      ),
  ],
  selectedOptionBuilder: (context, v) =>
      Text(text(v), overflow: TextOverflow.ellipsis),
  onChanged: (v) {
    if (v != null && v != value) onChanged(v);
  },
);

/// A spinner with a status line (and streamed progress text).
class AiWorking extends StatelessWidget {
  const AiWorking({super.key, required this.label, this.detail});

  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          const SizedBox(width: 20, height: 20, child: ShadSpinner()),
          Text(label, style: theme.textTheme.muted),
          if (detail != null && detail!.trim().isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                reverse: true,
                child: Text(
                  detail!.trim(),
                  style: theme.textTheme.muted.copyWith(fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// An error line in the destructive color.
class AiError extends StatelessWidget {
  const AiError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Text(
      message,
      key: const ValueKey<String>('slides.ai.error'),
      style: theme.textTheme.small.copyWith(
        color: theme.colorScheme.destructive,
      ),
    );
  }
}
