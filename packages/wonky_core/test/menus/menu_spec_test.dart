import 'package:test/test.dart';
import 'package:wonky_core/wonky_core.dart';

MenuRoot _menus() => MenuSpec.root([
  MenuSpec.submenu('file', 'File', [
    MenuSpec.command('shell.file.open', label: 'Open…'),
    MenuSpec.separator(),
    MenuSpec.command('shell.file.print'),
  ]),
  MenuSpec.submenu('format', 'Format', [
    MenuSpec.submenu('format.text', 'Text', [
      MenuSpec.command('write.format.bold', label: 'Bold'),
    ]),
  ]),
  MenuSpec.submenu('help', 'Help', [MenuSpec.command('shell.help.open')]),
]);

void main() {
  group('Given a menu tree', () {
    test(
      'when computing command paths then submenu labels prefix the item',
      () {
        final paths = _menus().commandPaths(titleOf: (c) => c.commandId);
        expect(paths['write.format.bold'], ['Format', 'Text', 'Bold']);
        expect(paths['shell.file.print'], ['File', 'shell.file.print']);
      },
    );

    test('when listing parameterized items then only items with args are '
        'returned with their paths', () {
      final m = MenuSpec.root([
        MenuSpec.submenu('view', 'View', [
          MenuSpec.submenu('view.theme', 'App theme', [
            MenuSpec.command(
              'shell.view.theme',
              label: 'Dark',
              args: {'mode': 'dark'},
              id: 'theme.dark',
            ),
          ]),
          MenuSpec.command('shell.view.zoomIn'),
        ]),
      ]);
      final items = m.parameterizedItems();
      expect(items, hasLength(1));
      expect(items.single.item.args, {'mode': 'dark'});
      expect(items.single.path, ['View', 'App theme', 'Dark']);
    });

    test('when finding by id then nested nodes are found', () {
      expect(_menus().find('format.text'), isA<MenuSubmenu>());
      expect(_menus().find('write.format.bold'), isA<MenuCommand>());
      expect(_menus().find('nope'), isNull);
    });

    test('when inserting after an item then the order is updated', () {
      final m = _menus().insertAfter('shell.file.open', [
        MenuSpec.command('shell.file.import'),
      ]);
      final file = m.find('file')! as MenuSubmenu;
      expect(file.children.map((c) => c.effectiveId).take(2), [
        'shell.file.open',
        'shell.file.import',
      ]);
    });

    test('when appending to a submenu then the item is last', () {
      final m = _menus().appendTo('format.text', [
        MenuSpec.command('write.format.italic'),
      ]);
      final text = m.find('format.text')! as MenuSubmenu;
      expect(text.children.last.effectiveId, 'write.format.italic');
    });

    test('when inserting top-level menus before Help then they precede it', () {
      final m = _menus().insertMenusBefore('help', [
        MenuSpec.submenu('data', 'Data', const []),
      ]);
      expect(m.children.map((c) => c.effectiveId), [
        'file',
        'format',
        'data',
        'help',
      ]);
    });

    test('when patching an unknown id then a StateError is thrown', () {
      expect(() => _menus().insertBefore('zz', const []), throwsStateError);
      expect(_menus().remove('zz').children, hasLength(3));
    });

    test('when removing an item then it is gone', () {
      expect(
        _menus().remove('shell.file.print').find('shell.file.print'),
        isNull,
      );
    });

    test('when serialized with a resolver then runtime state is included', () {
      final json = _menus().toJson(resolve: (c) => {'enabled': false});
      final file = json.first;
      final open = (file['items'] as List).first as Map;
      expect(open['commandId'], 'shell.file.open');
      expect(open['enabled'], false);
    });

    test(
      'when listing commands then all command items are yielded in order',
      () {
        expect(_menus().commands.map((c) => c.commandId), [
          'shell.file.open',
          'shell.file.print',
          'write.format.bold',
          'shell.help.open',
        ]);
      },
    );
  });
}
