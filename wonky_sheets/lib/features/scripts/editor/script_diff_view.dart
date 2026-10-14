import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_core/diff.dart';
import 'package:wonky_ui/wonky_ui.dart';

/// A line diff of two script versions (09 §14.3 *Compare*): side by side
/// when there is room (≥ 640 px), unified otherwise. Removed lines are
/// tinted with `destructive`, added ones with `success`; line numbers in
/// the gutters.
class ScriptDiffView extends StatelessWidget {
  const ScriptDiffView({
    super.key,
    required this.before,
    required this.after,
    required this.beforeLabel,
    required this.afterLabel,
  });

  /// The old text (left).
  final String before;

  /// The new text (right).
  final String after;
  final String beforeLabel;
  final String afterLabel;

  static const _sideBySideWidth = 640.0;

  @override
  Widget build(BuildContext context) {
    final diff = LineDiff.diff(before, after);
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth >= _sideBySideWidth
          ? _sideBySide(context, diff)
          : _unified(context, diff),
    );
  }

  TextStyle _mono(BuildContext context) => TextStyle(
    fontFamily: WonkyTheme.monoFamily,
    fontSize: 12,
    height: 1.5,
    color: ShadTheme.of(context).colorScheme.foreground,
  );

  Color _tint(BuildContext context, DiffOp op) {
    final cs = ShadTheme.of(context).colorScheme;
    return switch (op) {
      DiffOp.insert => cs.success.withValues(alpha: 0.16),
      DiffOp.delete => cs.destructive.withValues(alpha: 0.14),
      DiffOp.equal => const Color(0x00000000),
    };
  }

  Widget _header(BuildContext context, String text) {
    final theme = ShadTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: theme.colorScheme.muted,
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _line(
    BuildContext context, {
    required int? number,
    required String text,
    required DiffOp op,
    String sign = '',
  }) {
    final cs = ShadTheme.of(context).colorScheme;
    final mono = _mono(context);
    return Container(
      color: _tint(context, op),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text(
              number == null ? '' : '$number',
              textAlign: TextAlign.right,
              style: mono.copyWith(color: cs.mutedForeground),
            ),
          ),
          SizedBox(
            width: 16,
            child: Text(
              sign,
              textAlign: TextAlign.center,
              style: mono.copyWith(color: cs.mutedForeground),
            ),
          ),
          Expanded(child: Text(text, softWrap: false, style: mono)),
        ],
      ),
    );
  }

  Widget _unified(BuildContext context, List<DiffLine> diff) {
    final cs = ShadTheme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: cs.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context, '− $beforeLabel   + $afterLabel'),
          Expanded(
            child: ListView.builder(
              key: const ValueKey<String>('script.diff.unified'),
              itemCount: diff.length,
              itemBuilder: (context, i) {
                final d = diff[i];
                return _line(
                  context,
                  number: d.newLine ?? d.oldLine,
                  text: d.text,
                  op: d.op,
                  sign: switch (d.op) {
                    DiffOp.insert => '+',
                    DiffOp.delete => '−',
                    DiffOp.equal => '',
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideBySide(BuildContext context, List<DiffLine> diff) {
    final cs = ShadTheme.of(context).colorScheme;
    // Pair deletions with the insertions that follow them.
    final rows = <(DiffLine?, DiffLine?)>[];
    var i = 0;
    while (i < diff.length) {
      final d = diff[i];
      if (d.op == DiffOp.equal) {
        rows.add((d, d));
        i++;
        continue;
      }
      final dels = <DiffLine>[];
      final ins = <DiffLine>[];
      while (i < diff.length && diff[i].op != DiffOp.equal) {
        (diff[i].op == DiffOp.delete ? dels : ins).add(diff[i]);
        i++;
      }
      final n = dels.length > ins.length ? dels.length : ins.length;
      for (var k = 0; k < n; k++) {
        rows.add((
          k < dels.length ? dels[k] : null,
          k < ins.length ? ins[k] : null,
        ));
      }
    }
    Widget side(DiffLine? d, {required bool left}) => d == null
        ? Container(color: cs.muted.withValues(alpha: 0.4), height: 18)
        : _line(
            context,
            number: left ? d.oldLine : d.newLine,
            text: d.text,
            op: d.op,
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: cs.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _header(context, beforeLabel)),
              Container(width: 1, height: 26, color: cs.border),
              Expanded(child: _header(context, afterLabel)),
            ],
          ),
          Expanded(
            child: ListView.builder(
              key: const ValueKey<String>('script.diff.sideBySide'),
              itemCount: rows.length,
              itemBuilder: (context, i) => IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: side(rows[i].$1, left: true)),
                    Container(width: 1, color: cs.border),
                    Expanded(child: side(rows[i].$2, left: false)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
