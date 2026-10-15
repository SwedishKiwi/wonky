import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Presenting is single-window (Slides 10 §5.2, AC 4, §18; v2 review
/// Q5/Q29): no code path opens a window — no `window.open`, no Window
/// Management API (`getScreenDetails`), no URL launches from presenting.
void main() {
  /// The code of [f] without comments (docs may name the banned APIs).
  String code(File f) => f
      .readAsLinesSync()
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  List<File> dartFiles(String dir) => [
    for (final f in Directory(dir).listSync(recursive: true))
      if (f is File && f.path.endsWith('.dart')) f,
  ];

  test('Given the Slides app sources then nothing opens a window or uses '
      'the Window Management API', () {
    final windowOpen = RegExp(r'window\s*\.\s*open\s*\(');
    final offenders = [
      for (final f in dartFiles('lib'))
        if (windowOpen.hasMatch(code(f)) ||
            code(f).contains('getScreenDetails('))
          f.path,
    ];
    expect(offenders, isEmpty);
  });

  test('Given the present feature and its commands then no URL is launched '
      'and no window or tab is opened', () {
    final banned = RegExp(
      r'launchUrl|launchUrlString|openNewWindow|window\s*\.\s*open|'
      r"getScreenDetails\(|'_blank'",
    );
    final files = [
      ...dartFiles('lib/features/present'),
      File('lib/commands/present_commands.dart'),
    ];
    expect(files.length, greaterThan(5));
    final offenders = [
      for (final f in files)
        if (banned.hasMatch(code(f))) f.path,
    ];
    expect(offenders, isEmpty);
  });
}
