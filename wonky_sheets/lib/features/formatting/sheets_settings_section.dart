import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';

import '../../l10n/sheets_l10n.dart';
import 'cell_fonts.dart';
import 'sheets_user_defaults.dart';
import 'spreadsheet_settings_dialog.dart'
    show spreadsheetLocales, timeZoneOptions;

/// Settings › Sheets (04 §11.24): defaults of new spreadsheets (locale,
/// time zone, font and size), editing preferences and custom fill lists,
/// stored in `UserPreferences.sheetsDefaults` (see [SheetsUserDefaults]).
class SheetsSettingsSection extends StatefulWidget {
  const SheetsSettingsSection({super.key, required this.services});

  final ShellServices services;

  @override
  State<SheetsSettingsSection> createState() => _SheetsSettingsSectionState();
}

class _SheetsSettingsSectionState extends State<SheetsSettingsSection> {
  late final SheetsUserDefaults _d = SheetsUserDefaults.of(widget.services);
  late final List<(String, String)> _zones = timeZoneOptions();
  late final TextEditingController _lists = TextEditingController(
    text: SheetsUserDefaults.formatFillLists(_d.customFillLists),
  );
  final FocusNode _listsFocus = FocusNode(debugLabel: 'settings.fillLists');
  String _localeQuery = '';
  String _zoneQuery = '';
  Timer? _save;

  static const fontSizes = <double>[6, 7, 8, 9, 10, 11, 12, 14, 18, 24, 36];

  @override
  void initState() {
    super.initState();
    _listsFocus.addListener(() {
      if (!_listsFocus.hasFocus) _saveLists();
    });
  }

  @override
  void dispose() {
    if (_save?.isActive ?? false) _saveLists();
    _save?.cancel();
    _lists.dispose();
    _listsFocus.dispose();
    super.dispose();
  }

  void _saveLists() {
    _save?.cancel();
    final parsed = SheetsUserDefaults.parseFillLists(_lists.text);
    final current = _d.customFillLists;
    if (SheetsUserDefaults.formatFillLists(parsed) ==
        SheetsUserDefaults.formatFillLists(current)) {
      return;
    }
    unawaited(_d.set(SheetsUserDefaults.keyCustomFillLists, parsed));
  }

  Widget _switch(String key, bool value) => ShadSwitch(
    key: ValueKey<String>('settings.sheets.$key'),
    value: value,
    onChanged: (v) => _d.set(key, v),
  );

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final la = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    return ListenableBuilder(
      listenable: widget.services.prefs,
      builder: (context, _) {
        final locale = _d.locale ?? 'en_US';
        final zone = _d.timeZone ?? 'UTC';
        final font = _d.fontFamily ?? CellFonts.inter;
        final size = _d.fontSize ?? 10;
        final lq = _localeQuery.toLowerCase();
        final zq = _zoneQuery.toLowerCase();
        String localeLabel(String id) =>
            spreadsheetLocales.where((x) => x.$1 == id).firstOrNull?.$2 ?? id;
        String zoneLabel(String id) =>
            _zones.where((z) => z.$1 == id).firstOrNull?.$2 ?? id;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsGroup(
              title: la.settingsSheets,
              description: l.sheetsSettingsNewHint,
              children: [
                SettingsRow(
                  label: l.settingsLocale,
                  control: SizedBox(
                    width: 240,
                    child: ShadSelect<String>.withSearch(
                      key: const ValueKey<String>('settings.sheets.locale'),
                      initialValue: locale,
                      minWidth: 240,
                      maxHeight: 320,
                      searchPlaceholder: Text(l.settingsSearch),
                      onSearchChanged: (q) => setState(() => _localeQuery = q),
                      options: [
                        for (final (id, name) in spreadsheetLocales)
                          if (lq.isEmpty ||
                              name.toLowerCase().contains(lq) ||
                              id.toLowerCase().contains(lq))
                            ShadOption(value: id, child: Text(name)),
                      ],
                      selectedOptionBuilder: (context, v) =>
                          Text(localeLabel(v), overflow: TextOverflow.ellipsis),
                      onChanged: (v) {
                        if (v != null) _d.set(SheetsUserDefaults.keyLocale, v);
                      },
                    ),
                  ),
                ),
                SettingsRow(
                  label: l.settingsTimeZone,
                  control: SizedBox(
                    width: 240,
                    child: ShadSelect<String>.withSearch(
                      key: const ValueKey<String>('settings.sheets.timeZone'),
                      initialValue: zone,
                      minWidth: 300,
                      maxHeight: 320,
                      searchPlaceholder: Text(l.settingsSearch),
                      onSearchChanged: (q) => setState(() => _zoneQuery = q),
                      options: [
                        for (final (id, label) in _zones)
                          if (zq.isEmpty || label.toLowerCase().contains(zq))
                            ShadOption(value: id, child: Text(label)),
                      ],
                      selectedOptionBuilder: (context, v) =>
                          Text(zoneLabel(v), overflow: TextOverflow.ellipsis),
                      onChanged: (v) {
                        if (v != null) {
                          _d.set(SheetsUserDefaults.keyTimeZone, v);
                        }
                      },
                    ),
                  ),
                ),
                SettingsRow(
                  label: l.sheetsSettingsFont,
                  control: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      SizedBox(
                        width: 160,
                        child: ShadSelect<String>(
                          key: const ValueKey<String>('settings.sheets.font'),
                          initialValue: font,
                          minWidth: 160,
                          options: [
                            for (final f in CellFonts.bundled)
                              ShadOption(
                                value: f,
                                child: Text(
                                  f,
                                  style: TextStyle(
                                    fontFamily: CellFonts.screenFamily(f),
                                    fontFamilyFallback: CellFonts.fallback,
                                  ),
                                ),
                              ),
                          ],
                          selectedOptionBuilder: (context, v) =>
                              Text(v, overflow: TextOverflow.ellipsis),
                          onChanged: (v) {
                            if (v != null) {
                              _d.set(SheetsUserDefaults.keyFontFamily, v);
                            }
                          },
                        ),
                      ),
                      SizedBox(
                        width: 72,
                        child: ShadSelect<double>(
                          key: const ValueKey<String>(
                            'settings.sheets.fontSize',
                          ),
                          initialValue: size,
                          minWidth: 72,
                          options: [
                            for (final s in fontSizes)
                              ShadOption(value: s, child: Text(_n(s))),
                          ],
                          selectedOptionBuilder: (context, v) => Text(_n(v)),
                          onChanged: (v) {
                            if (v != null) {
                              _d.set(SheetsUserDefaults.keyFontSize, v);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SettingsGroup(
              title: l.sheetsSettingsEditing,
              children: [
                for (final (k, label, v) in [
                  (
                    SheetsUserDefaults.keyEnterStartsEditing,
                    l.sheetsSettingsEnterStartsEditing,
                    _d.enterStartsEditing,
                  ),
                  (
                    SheetsUserDefaults.keyFormulaAutocomplete,
                    la.sheetsAutocomplete,
                    _d.formulaAutocomplete,
                  ),
                  (
                    SheetsUserDefaults.keyFormulaHelp,
                    la.sheetsFormulaHelp,
                    _d.formulaHelp,
                  ),
                  (
                    SheetsUserDefaults.keyColumnAutocomplete,
                    l.sheetsSettingsColumnAutocomplete,
                    _d.columnAutocomplete,
                  ),
                  (
                    SheetsUserDefaults.keyShowEditorMode,
                    l.sheetsSettingsShowEditorMode,
                    _d.showEditorMode,
                  ),
                  (
                    SheetsUserDefaults.keyReduceAnimations,
                    l.sheetsSettingsReduceAnimations,
                    widget.services.prefs.sheetsDefaults[SheetsUserDefaults
                                .keyReduceAnimations]
                            as bool? ??
                        false,
                  ),
                  (
                    SheetsUserDefaults.keyScriptsEnabled,
                    la.sheetsScripts,
                    _d.scriptsEnabled,
                  ),
                  (
                    SheetsUserDefaults.keyChartSeriesByPattern,
                    l.sheetsSettingsChartPatterns,
                    _d.chartSeriesByPattern,
                  ),
                ])
                  SettingsRow(label: label, control: _switch(k, v)),
              ],
            ),
            SettingsGroup(
              title: l.sheetsSettingsFillLists,
              description: l.sheetsSettingsFillListsHint,
              children: [
                ShadTextarea(
                  key: const ValueKey<String>('settings.sheets.fillLists'),
                  controller: _lists,
                  focusNode: _listsFocus,
                  minHeight: 96,
                  maxHeight: 220,
                  placeholder: Text(l.sheetsSettingsFillListsPlaceholder),
                  onChanged: (_) {
                    _save?.cancel();
                    _save = Timer(
                      const Duration(milliseconds: 800),
                      _saveLists,
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l.sheetsSettingsFillListsCount(_d.customFillLists.length),
                    style: theme.textTheme.muted.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
