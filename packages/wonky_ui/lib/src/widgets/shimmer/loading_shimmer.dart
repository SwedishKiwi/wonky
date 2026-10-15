import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../l10n/wonky_ui_localizations.dart';
import '../../theme/wonky_colors.dart';
import '../../theme/wonky_theme.dart';

/// Skeleton layouts (suite 02 §4.18) built from `ShadSkeleton`: drive list,
/// drive grid, document page and spreadsheet grid.
class LoadingShimmer extends StatelessWidget {
  const LoadingShimmer._(this._builder, {super.key});

  /// Drive list rows (icon, name, owner, date).
  factory LoadingShimmer.driveList({Key? key, int rows = 8}) =>
      LoadingShimmer._(
        (context, animate) => _driveList(context, rows, animate),
        key: key,
      );

  /// Drive grid cards.
  factory LoadingShimmer.driveGrid({Key? key, int cards = 8}) =>
      LoadingShimmer._(
        (context, animate) => _driveGrid(context, cards, animate),
        key: key,
      );

  /// A document page with paragraphs.
  factory LoadingShimmer.documentPage({Key? key}) =>
      LoadingShimmer._(_documentPage, key: key);

  /// A spreadsheet grid.
  factory LoadingShimmer.grid({Key? key, int rows = 18, int columns = 8}) =>
      LoadingShimmer._(
        (context, animate) => _grid(context, rows, columns, animate),
        key: key,
      );

  final Widget Function(BuildContext context, bool animate) _builder;

  @override
  Widget build(BuildContext context) {
    final animate =
        WonkyThemeScope.of(context).motion(context) != Duration.zero;
    return Semantics(
      label: WonkyUiLocalizations.of(context).loading,
      liveRegion: true,
      child: ExcludeSemantics(child: _builder(context, animate)),
    );
  }

  static Widget _bar(double w, double h, bool animate, {double r = 4}) =>
      ShadSkeleton(
        width: w,
        height: h,
        animate: animate,
        radius: BorderRadius.circular(r),
      );

  static Widget _driveList(BuildContext context, int rows, bool animate) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _bar(20, 20, animate),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _bar(140.0 + (i * 37) % 120, 14, animate),
                    ),
                  ),
                  _bar(80, 14, animate),
                  const SizedBox(width: 24),
                  _bar(70, 14, animate),
                ],
              ),
            ),
        ],
      );

  static Widget _driveGrid(BuildContext context, int cards, bool animate) =>
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (var i = 0; i < cards; i++)
            SizedBox(
              width: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(200, 140, animate, r: 8),
                  const SizedBox(height: 8),
                  _bar(150, 14, animate),
                ],
              ),
            ),
        ],
      );

  static Widget _documentPage(BuildContext context, bool animate) {
    final c = ShadTheme.of(context).colorScheme;
    // Short windows (360 × 720 with the editor chrome) clip the page
    // instead of overflowing.
    return Center(
      child: SingleChildScrollView(
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        child: Container(
          width: 680,
          padding: const EdgeInsets.fromLTRB(64, 72, 64, 72),
          color: c.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _bar(320, 26, animate),
              const SizedBox(height: 28),
              for (var p = 0; p < 4; p++) ...[
                for (var l = 0; l < 4; l++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _bar(l == 3 ? 300 : 552, 12, animate),
                  ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Widget _grid(BuildContext context, int rows, int cols, bool animate) {
    final c = ShadTheme.of(context).colorScheme;
    return Table(
      border: TableBorder.all(color: c.gridLine),
      defaultColumnWidth: const FixedColumnWidth(96),
      children: [
        for (var r = 0; r < rows; r++)
          TableRow(
            decoration: r == 0 ? BoxDecoration(color: c.gridHeaderBg) : null,
            children: [
              for (var col = 0; col < cols; col++)
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: r == 0 || (r * 7 + col * 3) % 5 == 0
                      ? _bar(40.0 + (r * col * 13) % 40, 10, animate)
                      : const SizedBox(height: 10),
                ),
            ],
          ),
      ],
    );
  }
}
