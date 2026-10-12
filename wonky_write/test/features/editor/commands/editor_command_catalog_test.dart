import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_write/features/editor/commands/editor_command_catalog.dart';
import 'package:wonky_write/features/editor/commands/write_editor_commands.dart';
import 'package:wonky_write/features/editor/paste/editor_clipboard.dart';
import 'package:wonky_write/features/editor/paste/system_clipboard.dart';

import '../support/editor_harness.dart';

void main() {
  final catalog = editorCommandCatalog();

  test('Given the catalog then every id is a valid, unique write.* command id', () {
    final ids = catalog.map((c) => c.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    for (final id in ids) {
      expect(CommandId(id).isValid, isTrue, reason: id);
      expect(id.startsWith('write.'), isTrue, reason: id);
    }
  });

  test('Given a selection when running write.format.bold through the catalog then it is bold and checked', () async {
    final h = EditorHarness(Delta()..insert('abc\n'))..select(0, 3);
    final commands = WriteEditorCommands(h.controller);
    final target = EditorCommandTarget(
      controller: h.controller,
      commands: commands,
      clipboard: EditorClipboard(controller: h.controller, commands: commands, clipboard: MemoryClipboard()),
    );
    final bold = catalog.firstWhere((c) => c.id == 'write.format.bold');
    expect(bold.isEnabled(target, const JsonArgs()), isTrue);
    final result = await bold.run(target, const JsonArgs());
    expect(result.isOk, isTrue);
    expect(bold.checked!(target, const JsonArgs()), isTrue);

    final setLink = catalog.firstWhere((c) => c.id == 'write.link.set');
    final rejected = await setLink.run(target, const JsonArgs({'url': 'javascript:alert(1)'}));
    expect(rejected.status, CommandStatus.failed);
    h.dispose();
  });
}
