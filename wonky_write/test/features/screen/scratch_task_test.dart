import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shad/shad.dart';
import 'package:wonky_write/features/editor/controller/write_editor_controller.dart';
import 'package:wonky_write/features/editor/ui/wonky_editor.dart';
import 'package:wonky_write/features/themes/theme_adapter.dart';
import 'package:wonky_write_core/wonky_write_core.dart' hide DeltaSelection;

void main() {
  testWidgets('task renders', (tester) async {
    final delta = const MarkdownCodec().importMarkdown('Hello\n\n- [ ] Write your first document\n- [x] Done\n\n> Tip: quote\n').delta;
    final c = WriteEditorController(initialDelta: delta);
    final theme = const EditorThemeAdapter().adapt(ThemeResolver.instance.resolve(BuiltinThemes.wonkyDefault.theme, ThemeVariant.light));
    await tester.pumpWidget(ShadApp(home: Scaffold(body: WonkyEditor(controller: c, theme: theme))));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
