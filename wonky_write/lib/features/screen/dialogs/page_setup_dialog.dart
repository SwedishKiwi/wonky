import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_ui/wonky_ui.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

/// Result of the page setup dialog.
@immutable
class PageSetupResult {
  const PageSetupResult(this.setup, {this.setAsDefault = false});
  final PageSetup setup;
  final bool setAsDefault;
}

/// Page setup (`write.dialog.pageSetup`, Write 05 §12.6, 07 §6.2).
Future<PageSetupResult?> showPageSetupDialog(
  BuildContext context, {
  required PageSetup setup,
  required PageMargins themeMargins,
  bool readOnly = false,
  int initialTab = 0,
}) => showShadDialog<PageSetupResult>(
  context: context,
  builder: (_) => PageSetupDialog(
    setup: setup,
    themeMargins: themeMargins,
    readOnly: readOnly,
    initialTab: initialTab,
  ),
);

enum _Unit { inches, mm }

class PageSetupDialog extends StatefulWidget {
  const PageSetupDialog({
    super.key,
    required this.setup,
    required this.themeMargins,
    this.readOnly = false,
    this.initialTab = 0,
  });

  final PageSetup setup;
  final PageMargins themeMargins;
  final bool readOnly;
  final int initialTab;

  @override
  State<PageSetupDialog> createState() => _PageSetupDialogState();
}

class _PageSetupDialogState extends State<PageSetupDialog> {
  late PageLayoutMode _layout = widget.setup.layout;
  late PaperSize _paper = widget.setup.paper;
  late double _customW = widget.setup.customWidthPt;
  late double _customH = widget.setup.customHeightPt;
  late PageOrientation _orientation = widget.setup.orientation;
  late bool _themeMargins = widget.setup.margins == null;
  late PageMargins _margins = widget.setup.margins ?? widget.themeMargins;
  late HeaderFooterSpec _header = widget.setup.header;
  late HeaderFooterSpec _footer = widget.setup.footer;
  late bool _differentFirst = widget.setup.differentFirstPage;
  late HeaderFooterSpec _firstHeader = widget.setup.firstPageHeader;
  late HeaderFooterSpec _firstFooter = widget.setup.firstPageFooter;
  late String _tab = widget.initialTab == 1 ? 'headerFooter' : 'page';
  _Unit _unit = _Unit.inches;

  PageSetup get _result => PageSetup(
    layout: _layout,
    paper: _paper,
    customWidthPt: _customW,
    customHeightPt: _customH,
    orientation: _orientation,
    margins: _themeMargins ? null : _margins,
    header: _header,
    footer: _footer,
    differentFirstPage: _differentFirst,
    firstPageHeader: _firstHeader,
    firstPageFooter: _firstFooter,
    pageNumberStart: widget.setup.pageNumberStart,
    pageNumberFormat: widget.setup.pageNumberFormat,
  );

  double _toUnit(double pt) => _unit == _Unit.inches ? pt / 72 : pt / 72 * 25.4;
  double _fromUnit(num v) => _unit == _Unit.inches ? v * 72.0 : v / 25.4 * 72;

  static const _paperLabels = {
    PaperSize.letter: 'Letter (8.5" × 11")',
    PaperSize.legal: 'Legal (8.5" × 14")',
    PaperSize.tabloid: 'Tabloid (11" × 17")',
    PaperSize.a3: 'A3 (297 × 420 mm)',
    PaperSize.a4: 'A4 (210 × 297 mm)',
    PaperSize.a5: 'A5 (148 × 210 mm)',
    PaperSize.custom: 'Custom…',
  };

  void _preset(double topBottom, double leftRight) => setState(() {
    _themeMargins = false;
    _margins = PageMargins(
      top: topBottom,
      bottom: topBottom,
      left: leftRight,
      right: leftRight,
    );
  });

  @override
  Widget build(BuildContext context) {
    final ro = widget.readOnly;
    return ShadDialog(
      key: const ValueKey<String>('write.dialog.pageSetup'),
      title: const Text('Page setup'),
      description: ro
          ? const Text('You need edit access to change the page setup.')
          : null,
      constraints: const BoxConstraints(maxWidth: 680),
      actions: [
        if (!ro)
          ShadButton.ghost(
            key: const ValueKey<String>('write.dialog.pageSetup.default'),
            onPressed: () => Navigator.of(
              context,
            ).pop(PageSetupResult(_result, setAsDefault: true)),
            child: const Text('Set as default'),
          ),
        ShadButton.outline(
          key: const ValueKey<String>('write.dialog.pageSetup.cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(ro ? 'Close' : 'Cancel'),
        ),
        if (!ro)
          ShadButton(
            key: const ValueKey<String>('write.dialog.pageSetup.ok'),
            onPressed: () =>
                Navigator.of(context).pop(PageSetupResult(_result)),
            child: const Text('OK'),
          ),
      ],
      child: IgnorePointer(
        ignoring: ro,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ShadTabs<String>(
                value: _tab,
                onChanged: (v) => setState(() => _tab = v),
                tabs: [
                  ShadTab(
                    value: 'page',
                    content: _pageTab(context),
                    child: const Text('Page'),
                  ),
                  ShadTab(
                    value: 'headerFooter',
                    content: _headerFooterTab(context),
                    child: const Text('Header & footer'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: _PagePreview(
                setup: _result,
                themeMargins: widget.themeMargins,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 6),
    child: Text(text, style: ShadTheme.of(context).textTheme.small),
  );

  Widget _pageTab(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(context, 'Layout'),
        ShadRadioGroup<PageLayoutMode>(
          initialValue: _layout,
          axis: Axis.horizontal,
          spacing: 16,
          onChanged: (v) => setState(() => _layout = v ?? _layout),
          items: const [
            ShadRadio(
              key: ValueKey<String>('write.dialog.pageSetup.pages'),
              value: PageLayoutMode.pages,
              label: Text('Pages'),
            ),
            ShadRadio(
              key: ValueKey<String>('write.dialog.pageSetup.pageless'),
              value: PageLayoutMode.pageless,
              label: Text('Pageless'),
            ),
          ],
        ),
        _label(context, 'Paper size'),
        ShadSelect<PaperSize>(
          key: const ValueKey<String>('write.dialog.pageSetup.paper'),
          initialValue: _paper,
          minWidth: 240,
          options: [
            for (final e in _paperLabels.entries)
              ShadOption(value: e.key, child: Text(e.value)),
          ],
          selectedOptionBuilder: (context, v) => Text(_paperLabels[v]!),
          onChanged: (v) => setState(() => _paper = v ?? _paper),
        ),
        if (_paper == PaperSize.custom) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: WonkyNumberStepper(
                  value: _toUnit(_customW),
                  min: _unit == _Unit.inches ? 2 : 50,
                  max: _unit == _Unit.inches ? 40 : 1000,
                  step: _unit == _Unit.inches ? 0.25 : 5,
                  fractionDigits: _unit == _Unit.inches ? 2 : 0,
                  suffix: _unit == _Unit.inches ? 'in' : 'mm',
                  semanticLabel: 'Width',
                  onChanged: (v) => setState(() => _customW = _fromUnit(v)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('×'),
              ),
              Expanded(
                child: WonkyNumberStepper(
                  value: _toUnit(_customH),
                  min: _unit == _Unit.inches ? 2 : 50,
                  max: _unit == _Unit.inches ? 40 : 1000,
                  step: _unit == _Unit.inches ? 0.25 : 5,
                  fractionDigits: _unit == _Unit.inches ? 2 : 0,
                  suffix: _unit == _Unit.inches ? 'in' : 'mm',
                  semanticLabel: 'Height',
                  onChanged: (v) => setState(() => _customH = _fromUnit(v)),
                ),
              ),
            ],
          ),
        ],
        _label(context, 'Orientation'),
        ShadRadioGroup<PageOrientation>(
          initialValue: _orientation,
          axis: Axis.horizontal,
          spacing: 16,
          onChanged: (v) => setState(() => _orientation = v ?? _orientation),
          items: const [
            ShadRadio(value: PageOrientation.portrait, label: Text('Portrait')),
            ShadRadio(
              value: PageOrientation.landscape,
              label: Text('Landscape'),
            ),
          ],
        ),
        Row(
          children: [
            _label(context, 'Margins'),
            const Spacer(),
            ShadSelect<_Unit>(
              initialValue: _unit,
              minWidth: 90,
              options: const [
                ShadOption(value: _Unit.inches, child: Text('inches')),
                ShadOption(value: _Unit.mm, child: Text('mm')),
              ],
              selectedOptionBuilder: (context, v) =>
                  Text(v == _Unit.inches ? 'inches' : 'mm'),
              onChanged: (v) => setState(() => _unit = v ?? _unit),
            ),
          ],
        ),
        ShadCheckbox(
          key: const ValueKey<String>('write.dialog.pageSetup.themeMargins'),
          value: _themeMargins,
          onChanged: (v) => setState(() {
            _themeMargins = v;
            if (v) _margins = widget.themeMargins;
          }),
          label: const Text('Use the theme’s margins'),
        ),
        const SizedBox(height: 8),
        Opacity(
          opacity: _themeMargins ? 0.5 : 1,
          child: IgnorePointer(
            ignoring: _themeMargins,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _margin('Top', _margins.top, (v) {
                        _margins = PageMargins(
                          top: v,
                          right: _margins.right,
                          bottom: _margins.bottom,
                          left: _margins.left,
                        );
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _margin('Bottom', _margins.bottom, (v) {
                        _margins = PageMargins(
                          top: _margins.top,
                          right: _margins.right,
                          bottom: v,
                          left: _margins.left,
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _margin('Left', _margins.left, (v) {
                        _margins = PageMargins(
                          top: _margins.top,
                          right: _margins.right,
                          bottom: _margins.bottom,
                          left: v,
                        );
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _margin('Right', _margins.right, (v) {
                        _margins = PageMargins(
                          top: _margins.top,
                          right: v,
                          bottom: _margins.bottom,
                          left: _margins.left,
                        );
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            Text('Presets:', style: theme.textTheme.muted),
            ShadButton.link(
              size: ShadButtonSize.sm,
              onPressed: () => _preset(72, 72),
              child: const Text('Normal'),
            ),
            ShadButton.link(
              size: ShadButtonSize.sm,
              onPressed: () => _preset(36, 36),
              child: const Text('Narrow'),
            ),
            ShadButton.link(
              size: ShadButtonSize.sm,
              onPressed: () => _preset(72, 144),
              child: const Text('Wide'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _margin(String label, double pt, void Function(double) set) => Row(
    children: [
      SizedBox(width: 52, child: Text(label)),
      Expanded(
        child: WonkyNumberStepper(
          key: ValueKey<String>('write.dialog.pageSetup.margin.$label'),
          value: double.parse(_toUnit(pt).toStringAsFixed(2)),
          min: 0,
          max: _unit == _Unit.inches ? 4 : 100,
          step: _unit == _Unit.inches ? 0.1 : 1,
          fractionDigits: _unit == _Unit.inches ? 2 : 0,
          suffix: _unit == _Unit.inches ? 'in' : 'mm',
          semanticLabel: '$label margin',
          onChanged: (v) => setState(() => set(_fromUnit(v))),
        ),
      ),
    ],
  );

  Widget _headerFooterTab(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Text(
          'Tokens: {page} {pages} {title} {date} {author}',
          style: theme.textTheme.muted.copyWith(
            fontSize: 12,
            fontFamily: WonkyTheme.monoFamily,
          ),
        ),
        _HeaderFooterEditor(
          keyPrefix: 'header',
          label: 'Header',
          spec: _header,
          onChanged: (s) => setState(() => _header = s),
        ),
        _HeaderFooterEditor(
          keyPrefix: 'footer',
          label: 'Footer',
          spec: _footer,
          onChanged: (s) => setState(() => _footer = s),
        ),
        const SizedBox(height: 12),
        ShadCheckbox(
          key: const ValueKey<String>('write.dialog.pageSetup.differentFirst'),
          value: _differentFirst,
          onChanged: (v) => setState(() => _differentFirst = v),
          label: const Text('Different first page'),
        ),
        if (_differentFirst) ...[
          _HeaderFooterEditor(
            keyPrefix: 'firstHeader',
            label: 'First page header',
            spec: _firstHeader,
            onChanged: (s) => setState(() => _firstHeader = s),
          ),
          _HeaderFooterEditor(
            keyPrefix: 'firstFooter',
            label: 'First page footer',
            spec: _firstFooter,
            onChanged: (s) => setState(() => _firstFooter = s),
          ),
        ],
        const SizedBox(height: 8),
        ShadButton.outline(
          key: const ValueKey<String>('write.dialog.pageSetup.pageNumbers'),
          size: ShadButtonSize.sm,
          leading: const Icon(LucideIcons.hash, size: 14),
          onPressed: () => setState(
            () => _footer = HeaderFooterSpec(
              enabled: true,
              left: _footer.left,
              center: '{page} / {pages}',
              right: _footer.right,
              distancePt: _footer.distancePt,
            ),
          ),
          child: const Text('Show page numbers'),
        ),
      ],
    );
  }
}

class _HeaderFooterEditor extends StatefulWidget {
  const _HeaderFooterEditor({
    required this.keyPrefix,
    required this.label,
    required this.spec,
    required this.onChanged,
  });

  final String keyPrefix;
  final String label;
  final HeaderFooterSpec spec;
  final ValueChanged<HeaderFooterSpec> onChanged;

  @override
  State<_HeaderFooterEditor> createState() => _HeaderFooterEditorState();
}

class _HeaderFooterEditorState extends State<_HeaderFooterEditor> {
  late final _left = TextEditingController(text: widget.spec.left);
  late final _center = TextEditingController(text: widget.spec.center);
  late final _right = TextEditingController(text: widget.spec.right);

  @override
  void didUpdateWidget(_HeaderFooterEditor old) {
    super.didUpdateWidget(old);
    if (_center.text != widget.spec.center) _center.text = widget.spec.center;
  }

  @override
  void dispose() {
    _left.dispose();
    _center.dispose();
    _right.dispose();
    super.dispose();
  }

  void _emit({bool? enabled}) => widget.onChanged(
    HeaderFooterSpec(
      enabled: enabled ?? widget.spec.enabled,
      left: _left.text,
      center: _center.text,
      right: _right.text,
      distancePt: widget.spec.distancePt,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    Widget field(String key, TextEditingController c, String hint) => Expanded(
      child: ShadInput(
        key: ValueKey<String>(
          'write.dialog.pageSetup.${widget.keyPrefix}.$key',
        ),
        controller: c,
        enabled: widget.spec.enabled,
        placeholder: Text(hint),
        onChanged: (_) => _emit(),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShadCheckbox(
            key: ValueKey<String>(
              'write.dialog.pageSetup.${widget.keyPrefix}.enabled',
            ),
            value: widget.spec.enabled,
            onChanged: (v) => _emit(enabled: v),
            label: Text(widget.label, style: theme.textTheme.small),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              field('left', _left, 'Left'),
              const SizedBox(width: 6),
              field('center', _center, 'Center'),
              const SizedBox(width: 6),
              field('right', _right, 'Right'),
            ],
          ),
        ],
      ),
    );
  }
}

/// A live thumbnail of the page geometry.
class _PagePreview extends StatelessWidget {
  const _PagePreview({required this.setup, required this.themeMargins});

  final PageSetup setup;
  final PageMargins themeMargins;

  @override
  Widget build(BuildContext context) {
    final cs = ShadTheme.of(context).colorScheme;
    final w = setup.pageWidthPt;
    final h = setup.pageHeightPt;
    final scale = 150 / (w > h ? w : h);
    final m = setup.marginsOr(themeMargins);
    return Container(
      width: w * scale,
      height: h * scale,
      decoration: BoxDecoration(
        color: cs.page,
        border: Border.all(color: cs.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1a000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          m.left * scale,
          m.top * scale,
          m.right * scale,
          m.bottom * scale,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: cs.ring.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 8; i++)
                Container(
                  margin: const EdgeInsets.fromLTRB(3, 3, 3, 0),
                  height: 2,
                  width: i == 0 ? 30 : null,
                  color: cs.mutedForeground.withValues(
                    alpha: i == 0 ? 0.6 : 0.25,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
