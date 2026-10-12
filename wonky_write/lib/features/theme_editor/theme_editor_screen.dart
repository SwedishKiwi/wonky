import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show AccessRole, UuidValue;
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_ui/wonky_ui.dart';
import 'package:wonky_write_core/wonky_write_core.dart'
    show BuiltinThemes, Delta, ThemeVariant;

import '../../commands/theme_commands.dart';
import '../document/write_document_session.dart' show WriteDocumentMeta;
import '../themes/document_theme.dart';
import '../themes/theme_picker.dart' show ThemeSwatchPreview;
import '../themes/write_fonts.dart';
import 'theme_dialogs.dart';
import 'theme_editor_controller.dart';
import 'theme_editor_model.dart';
import 'theme_inspector.dart';
import 'theme_preview.dart';

const _lastThemeKey = 'write.themeEditor.last';

/// `/themes` and `/themes/:themeUuid` (Write 06 §10.1): without a theme it
/// opens the last edited theme, else the user's default.
class ThemeEditorRoute extends StatefulWidget {
  const ThemeEditorRoute({
    super.key,
    required this.services,
    required this.themes,
    this.themeUuid,
    this.docItemUuid,
    this.element,
  });

  final ShellServices services;
  final WriteThemeCatalog themes;
  final String? themeUuid;
  final String? docItemUuid;
  final String? element;

  @override
  State<ThemeEditorRoute> createState() => _ThemeEditorRouteState();
}

class _ThemeEditorRouteState extends State<ThemeEditorRoute> {
  @override
  void initState() {
    super.initState();
    if (widget.themeUuid == null) unawaited(_redirect());
  }

  Future<void> _redirect() async {
    final s = widget.services;
    Object? last;
    try {
      last = await s.userStore.read(_lastThemeKey);
    } catch (_) {}
    if (!mounted) return;
    final uuid = last is String
        ? last
        : defaultThemeUuidOf(s.prefs.writeDefaults) ??
              BuiltinThemes.wonkyDefault.uuid;
    s.router.go(themeEditorPath(uuid, docItemUuid: widget.docItemUuid));
  }

  @override
  Widget build(BuildContext context) {
    final uuid = widget.themeUuid;
    if (uuid == null) {
      return ColoredBox(
        color: ShadTheme.of(context).colorScheme.background,
        child: const Center(child: ShadSpinner()),
      );
    }
    return ThemeEditorScreen(
      key: ValueKey<String>('write.themeEditor.$uuid'),
      services: widget.services,
      themes: widget.themes,
      themeUuid: uuid,
      docItemUuid: widget.docItemUuid,
      element: widget.element,
    );
  }
}

/// The full-screen theme editor (Write 06 §10.2): header with save state
/// and actions, theme list + element tree, live preview, inspector.
class ThemeEditorScreen extends StatefulWidget {
  const ThemeEditorScreen({
    super.key,
    required this.services,
    required this.themes,
    required this.themeUuid,
    this.docItemUuid,
    this.element,
  });

  final ShellServices services;
  final WriteThemeCatalog themes;
  final String themeUuid;
  final String? docItemUuid;
  final String? element;

  @override
  State<ThemeEditorScreen> createState() => ThemeEditorScreenState();
}

class ThemeEditorScreenState extends State<ThemeEditorScreen>
    implements ThemeEditActions {
  late final ThemeEditorController controller;
  ShellServices get s => widget.services;
  int _narrowTab = 1;

  @override
  void initState() {
    super.initState();
    controller = ThemeEditorController(
      themeUuid: widget.themeUuid,
      catalog: widget.themes,
      undo: s.undo,
      repository: themeRepositoryFor(s),
      myUserUuid: s.me?.uuid.uuid,
      documentItemUuid: widget.docItemUuid,
      loadDocument: _loadDocument,
      setDefault: (uuid) => s.prefs.setWriteDefault(defaultThemeKey, uuid),
      defaultThemeUuid: () =>
          defaultThemeUuidOf(s.prefs.writeDefaults) ??
          BuiltinThemes.wonkyDefault.uuid,
    );
    final node = widget.element == null
        ? null
        : ThemeNode.parse(widget.element!);
    if (node != null) controller.select(node);
    ThemeEditorController.active.value = controller;
    controller.addListener(_onController);
    unawaited(controller.load());
    unawaited(widget.themes.loadMine());
    unawaited(_rememberLast());
    unawaited(
      WriteFonts.ensureLoaded(const [
        WriteFonts.openSans,
        WriteFonts.ebGaramond,
        WriteFonts.jetBrainsMono,
      ]),
    );
    // The document screen being replaced deactivates its stack after this
    // route builds: make the draft stack active once it is gone.
    WidgetsBinding.instance.addPostFrameCallback((_) => _activateStack());
  }

  Future<void> _rememberLast() async {
    try {
      await s.userStore.write(_lastThemeKey, widget.themeUuid);
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The preview follows the app theme until a variant is picked
    // (applied after this frame: listeners must not run during build).
    final v = ShadTheme.of(context).brightness == Brightness.dark
        ? ThemeVariant.dark
        : ThemeVariant.light;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.followAppVariant(v);
    });
  }

  void _activateStack() {
    if (!mounted) return;
    unawaited(s.undo.openStack(controller.draftStack, persist: false));
    s.undo.setActiveDocument(controller.draftStack);
  }

  void _onController() {
    s.registry.notifyStateChanged();
  }

  @override
  void dispose() {
    controller.removeListener(_onController);
    if (s.undo.activeDocumentStack == controller.draftStack) {
      s.undo.setActiveDocument(null);
    }
    unawaited(s.undo.closeStack(controller.draftStack, forget: true));
    controller.dispose();
    s.registry.notifyStateChanged();
    super.dispose();
  }

  Future<ThemeEditorDocument?> _loadDocument(String itemUuid) async {
    final client = s.client;
    if (client == null) return null;
    final item = await s.drive.get(UuidValue.withValidation(itemUuid));
    final docUuid = item.contentRef;
    if (docUuid == null) return null;
    final info = await client.document.getInfo(docUuid);
    final snap = await client.document.getSnapshot(docUuid, null);
    final meta = WriteDocumentMeta.fromView(info.meta);
    final decoded = jsonDecode(snap.deltaJson);
    return ThemeEditorDocument(
      itemUuid: itemUuid,
      documentUuid: docUuid.uuid,
      title: item.name.isEmpty ? 'Untitled document' : item.name,
      delta: Delta.fromJson(decoded is List ? decoded : const []),
      themeUuid: meta.themeUuid,
      canEdit: item.role == AccessRole.editor || item.role == AccessRole.owner,
    );
  }

  // ------------------------------------------------------------ actions

  Future<void> _invoke(String id, [Map<String, Object?> args = const {}]) => s
      .dispatcher
      .invoke(id, args: args, source: InvocationSource.ui, context: context)
      .then((r) {
        if (!r.isOk && r.message != null && r.status.name == 'failed') {
          s.toasts.error(r.message!);
        }
      })
      .catchError((Object e) => s.toasts.error('$e'));

  @override
  void setProperty(
    String path,
    Object? value, {
    ThemeVariant? variant,
    String? gesture,
  }) => unawaited(
    _invoke('write.theme.setProperty', {
      'path': path,
      'value': value,
      if (variant != null) 'variant': variant.name,
      'gesture': ?gesture,
    }),
  );

  @override
  void resetElement(ThemeNode node) =>
      unawaited(_invoke('write.theme.resetElement', {'element': node.id}));

  @override
  void fixContrast(String pairId, ThemeVariant variant) => unawaited(
    _invoke('write.theme.fixContrast', {
      'pairId': pairId,
      'variant': variant.name,
    }),
  );

  @override
  void rename() => unawaited(_invoke('write.theme.rename'));

  @override
  void duplicate() => unawaited(_invoke('write.theme.duplicate'));

  /// Leaves the editor (asks about unsaved changes); true when it left.
  Future<bool> _leave(VoidCallback go) async {
    if (controller.dirty && !controller.readOnly) {
      final choice = await showUnsavedThemeDialog(context, controller.name);
      if (!mounted || choice == null) return false;
      if (choice == UnsavedThemeChoice.save) {
        final r = await controller.save();
        if (!r.isOk) {
          s.toasts.error(r.error ?? 'Saving failed');
          return false;
        }
      } else {
        await controller.revert();
      }
    }
    go();
    return true;
  }

  void _back() => unawaited(
    _leave(() {
      final doc = widget.docItemUuid;
      s.router.go(doc == null ? '/' : '/d/$doc');
    }),
  );

  void _openTheme(String uuid) {
    if (uuid == widget.themeUuid) return;
    unawaited(
      _leave(
        () => s.router.go(
          themeEditorPath(
            uuid,
            docItemUuid: widget.docItemUuid,
            element: controller.selected.id,
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final mod = defaultTargetPlatformIsApple(context);
    return CallbackShortcuts(
      bindings: {
        SingleActivator(
          LogicalKeyboardKey.keyS,
          meta: mod,
          control: !mod,
        ): () =>
            unawaited(_invoke('write.theme.save')),
      },
      child: Focus(
        autofocus: true,
        child: ColoredBox(
          color: theme.colorScheme.background,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              if (controller.loading) {
                return const Center(child: ShadSpinner());
              }
              if (controller.loadError != null) return _error(context);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(state: this),
                  Expanded(child: _body(context)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _error(BuildContext context) => Center(
    child: WonkyEmptyState(
      key: const ValueKey<String>('write.themeEditor.error'),
      illustration: EmptyIllustration.search,
      title: 'This theme can’t be opened',
      description: 'It may have been deleted, or you no longer have access.',
      actions: [
        ShadButton(onPressed: _back, child: const Text('Go back')),
        ShadButton.outline(
          onPressed: () => s.router.go(
            themeEditorPath(
              BuiltinThemes.wonkyDefault.uuid,
              docItemUuid: widget.docItemUuid,
            ),
          ),
          child: const Text('Open Wonky Default'),
        ),
      ],
    ),
  );

  Widget _body(BuildContext context) {
    final theme = ShadTheme.of(context);
    final border = BorderSide(color: theme.colorScheme.border);
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 1180;
        final medium = box.maxWidth >= 880;
        if (!medium) return _narrow(context, box);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: wide ? 256 : 216,
              decoration: BoxDecoration(
                color: theme.colorScheme.card,
                border: Border(right: border),
              ),
              child: _Sidebar(state: this),
            ),
            Expanded(child: _PreviewPane(state: this)),
            Container(
              width: wide ? 352 : 328,
              decoration: BoxDecoration(
                color: theme.colorScheme.card,
                border: Border(left: border),
              ),
              child: ThemeInspector(controller: controller, actions: this),
            ),
          ],
        );
      },
    );
  }

  Widget _narrow(BuildContext context, BoxConstraints box) {
    final theme = ShadTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: ShadTabs<int>(
            value: _narrowTab,
            onChanged: (v) => setState(() => _narrowTab = v),
            tabs: const [
              ShadTab(value: 0, child: Text('Themes')),
              ShadTab(value: 1, child: Text('Elements')),
              ShadTab(value: 2, child: Text('Properties')),
            ],
          ),
        ),
        SizedBox(
          height: (box.maxHeight * 0.48).clamp(200, 520),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.card,
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.border),
              ),
            ),
            child: switch (_narrowTab) {
              0 => _Sidebar(state: this, showTree: false),
              1 => _Sidebar(state: this, showThemes: false),
              _ => ThemeInspector(controller: controller, actions: this),
            },
          ),
        ),
        Expanded(child: _PreviewPane(state: this)),
      ],
    );
  }
}

bool defaultTargetPlatformIsApple(BuildContext context) =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;

// ---------------------------------------------------------------- header

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final ThemeEditorScreenState state;

  ThemeEditorController get c => state.controller;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final s = state.s;
    final doc = c.document;
    void run(String id) => unawaited(state._invoke(id));
    final status = c.saving
        ? ('Saving…', cs.mutedForeground)
        : c.isBuiltin
        ? ('Built-in · read-only', cs.mutedForeground)
        : c.isDeleted
        ? ('Deleted', cs.destructive)
        : c.readOnly
        ? ('Read-only', cs.mutedForeground)
        : c.dirty
        ? ('Unsaved changes', cs.warning)
        : ('All changes saved', cs.mutedForeground);
    Widget iconButton(String id, IconData icon, String label, bool enabled) =>
        ShadTooltip(
          builder: (_) => Text(label),
          child: ShadIconButton.ghost(
            key: ValueKey<String>('write.themeEditor.${id.split('.').last}'),
            width: 32,
            height: 32,
            iconSize: 16,
            semanticLabel: label,
            enabled: enabled,
            icon: Icon(icon),
            onPressed: () => run(id),
          ),
        );
    final canApply =
        doc != null &&
        doc.canEdit &&
        !c.isDeleted &&
        doc.themeUuid != c.themeUuid;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: cs.background,
        border: Border(bottom: BorderSide(color: cs.border)),
      ),
      child: Row(
        children: [
          ShadButton.ghost(
            key: const ValueKey<String>('write.themeEditor.back'),
            size: ShadButtonSize.sm,
            leading: const Icon(LucideIcons.arrowLeft, size: 16),
            onPressed: state._back,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                doc == null ? 'Back' : 'Back to “${doc.title}”',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: cs.border,
          ),
          Icon(LucideIcons.palette, size: 18, color: cs.mutedForeground),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  key: const ValueKey<String>('write.themeEditor.name'),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (c.dirty && !c.readOnly) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: cs.warning,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        [
                          status.$1,
                          if (c.isMine && (c.usage ?? 0) > 0)
                            c.usage == 1
                                ? 'Used by 1 of your documents'
                                : 'Used by ${c.usage} of your documents',
                        ].join(' · '),
                        key: const ValueKey<String>('write.themeEditor.status'),
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.muted.copyWith(
                          fontSize: 12,
                          color: status.$2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ValueListenableBuilder<bool>(
            valueListenable: s.undo.canUndo,
            builder: (context, can, _) => iconButton(
              'shell.edit.undo',
              LucideIcons.undo2,
              s.undo.undoLabel.value == null
                  ? 'Undo'
                  : 'Undo ${s.undo.undoLabel.value}',
              can,
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: s.undo.canRedo,
            builder: (context, can, _) => iconButton(
              'shell.edit.redo',
              LucideIcons.redo2,
              s.undo.redoLabel.value == null
                  ? 'Redo'
                  : 'Redo ${s.undo.redoLabel.value}',
              can,
            ),
          ),
          const SizedBox(width: 6),
          if (c.readOnly && !c.isDeleted)
            ShadButton(
              key: const ValueKey<String>('write.themeEditor.duplicate'),
              size: ShadButtonSize.sm,
              leading: const Icon(LucideIcons.copy, size: 14),
              onPressed: () => run('write.theme.duplicate'),
              child: Text(
                c.isBuiltin ? 'Duplicate to customize' : 'Copy to my themes',
              ),
            )
          else if (c.isDeleted && c.isMine)
            ShadButton(
              key: const ValueKey<String>('write.themeEditor.restore'),
              size: ShadButtonSize.sm,
              onPressed: () => run('write.theme.restore'),
              child: const Text('Restore theme'),
            )
          else ...[
            if (c.dirty)
              ShadButton.ghost(
                key: const ValueKey<String>('write.themeEditor.revert'),
                size: ShadButtonSize.sm,
                onPressed: () => run('write.theme.revert'),
                child: const Text('Revert'),
              ),
            ShadButton(
              key: const ValueKey<String>('write.themeEditor.save'),
              size: ShadButtonSize.sm,
              enabled: c.dirty && !c.saving,
              onPressed: () => run('write.theme.save'),
              child: const Text('Save'),
            ),
          ],
          if (canApply) ...[
            const SizedBox(width: 6),
            ShadButton.outline(
              key: const ValueKey<String>('write.themeEditor.apply'),
              size: ShadButtonSize.sm,
              onPressed: () => run('write.theme.applyToDocument'),
              child: const Text('Apply to document'),
            ),
          ],
          const SizedBox(width: 4),
          WonkyDropdownMenu(
            entries: () => _menu(state),
            builder: (context, ctl) => ShadIconButton.ghost(
              key: const ValueKey<String>('write.themeEditor.more'),
              width: 32,
              height: 32,
              iconSize: 16,
              semanticLabel: 'More theme actions',
              icon: const Icon(LucideIcons.ellipsisVertical),
              onPressed: ctl.toggle,
            ),
          ),
        ],
      ),
    );
  }
}

List<WonkyMenuEntry> _menu(ThemeEditorScreenState state) {
  final c = state.controller;
  void run(String id, [Map<String, Object?> args = const {}]) =>
      unawaited(state._invoke(id, args));
  return [
    if (c.isMine && !c.isDeleted)
      WonkyMenuItem(
        key: const ValueKey<String>('write.themeEditor.menu.rename'),
        label: 'Rename…',
        icon: LucideIcons.pencil,
        onSelected: () => run('write.theme.rename'),
      ),
    WonkyMenuItem(
      key: const ValueKey<String>('write.themeEditor.menu.duplicate'),
      label: 'Duplicate',
      icon: LucideIcons.copy,
      onSelected: () => run('write.theme.duplicate'),
    ),
    if (c.isMine)
      WonkyMenuItem(
        key: const ValueKey<String>('write.themeEditor.menu.history'),
        label: 'Version history…',
        icon: LucideIcons.history,
        onSelected: () => run('write.theme.showRevisions'),
      ),
    WonkyMenuCheckItem(
      key: const ValueKey<String>('write.themeEditor.menu.default'),
      label: 'My default theme',
      checked: c.isDefault,
      onSelected: () => run('write.theme.setAsDefault'),
    ),
    const WonkyMenuSeparator(),
    WonkyMenuItem(
      label: 'Export as JSON…',
      icon: LucideIcons.fileJson,
      onSelected: () => run('write.theme.exportJson'),
    ),
    WonkyMenuItem(
      label: 'Export as CSS…',
      icon: LucideIcons.fileCode,
      onSelected: () => run('write.theme.exportCss'),
    ),
    WonkyMenuItem(
      label: 'Import theme…',
      icon: LucideIcons.upload,
      onSelected: () => run('write.theme.importJson'),
    ),
    if (c.isMine) ...[
      const WonkyMenuSeparator(),
      if (c.isDeleted)
        WonkyMenuItem(
          label: 'Restore theme',
          icon: LucideIcons.archiveRestore,
          onSelected: () => run('write.theme.restore'),
        )
      else
        WonkyMenuItem(
          key: const ValueKey<String>('write.themeEditor.menu.delete'),
          label: 'Delete theme',
          icon: LucideIcons.trash2,
          destructive: true,
          onSelected: () => run('write.theme.delete'),
        ),
    ],
  ];
}

// --------------------------------------------------------------- sidebar

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.state,
    this.showThemes = true,
    this.showTree = true,
  });

  final ThemeEditorScreenState state;
  final bool showThemes;
  final bool showTree;

  ThemeEditorController get c => state.controller;

  @override
  Widget build(BuildContext context) {
    final catalog = state.widget.themes;
    return ListenableBuilder(
      listenable: Listenable.merge([catalog, state.s.prefs]),
      builder: (context, _) {
        final defaultUuid =
            defaultThemeUuidOf(state.s.prefs.writeDefaults) ??
            BuiltinThemes.wonkyDefault.uuid;
        final mine = catalog.mine;
        final builtins = WriteThemeCatalog.builtins;
        final docTheme = c.document?.themeUuid;
        final foreign =
            docTheme != null &&
                !mine.any((t) => t.uuid == docTheme) &&
                !builtins.any((t) => t.uuid == docTheme)
            ? catalog.lookup(docTheme)
            : null;
        final defaultOption = catalog.lookup(defaultUuid);
        final children = <Widget>[];
        if (showThemes) {
          children.addAll([
            const _SideTitle('Themes'),
            if (defaultOption != null) ...[
              const _SideSubtitle('My default'),
              _ThemeRow(state: state, option: defaultOption, isDefault: true),
            ],
            if (foreign != null) ...[
              const _SideSubtitle('Used by this document'),
              _ThemeRow(state: state, option: foreign),
            ],
            const _SideSubtitle('My themes'),
            if (mine.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 12, 6),
                child: Text(
                  'Duplicate a built-in theme to make it your own.',
                  style: ShadTheme.of(
                    context,
                  ).textTheme.muted.copyWith(fontSize: 12),
                ),
              ),
            for (final t in mine)
              _ThemeRow(
                state: state,
                option: t,
                isDefault: t.uuid == defaultUuid,
              ),
            const _SideSubtitle('Built-in'),
            for (final t in builtins)
              _ThemeRow(
                state: state,
                option: t,
                isDefault: t.uuid == defaultUuid,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  ShadButton.ghost(
                    key: const ValueKey<String>('write.themeEditor.new'),
                    size: ShadButtonSize.sm,
                    leading: const Icon(LucideIcons.plus, size: 14),
                    onPressed: () =>
                        unawaited(state._invoke('write.theme.create')),
                    child: const Text('New theme'),
                  ),
                  ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    leading: const Icon(LucideIcons.upload, size: 14),
                    onPressed: () =>
                        unawaited(state._invoke('write.theme.importJson')),
                    child: const Text('Import'),
                  ),
                ],
              ),
            ),
          ]);
        }
        if (showTree) {
          children.add(const _SideTitle('Elements'));
          children.add(_ElementTree(c: c));
        }
        return ListView(
          key: ValueKey<String>(
            'write.themeEditor.sidebar.${showThemes ? 't' : ''}${showTree ? 'e' : ''}',
          ),
          padding: const EdgeInsets.only(bottom: 24),
          children: children,
        );
      },
    );
  }
}

class _SideTitle extends StatelessWidget {
  const _SideTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.muted.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

class _SideSubtitle extends StatelessWidget {
  const _SideSubtitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 12, 2),
    child: Text(
      text,
      style: ShadTheme.of(
        context,
      ).textTheme.muted.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
    ),
  );
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    required this.state,
    required this.option,
    this.isDefault = false,
  });

  final ThemeEditorScreenState state;
  final ThemeOption option;
  final bool isDefault;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final current = option.uuid == state.widget.themeUuid;
    final mine =
        !option.isBuiltin &&
        state.widget.themes.mine.any((t) => t.uuid == option.uuid);
    void run(String id, [Map<String, Object?> args = const {}]) =>
        unawaited(state._invoke(id, {'themeUuid': option.uuid, ...args}));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: WonkyContextMenuRegion(
        entries: () => [
          WonkyMenuItem(
            label: 'Duplicate',
            icon: LucideIcons.copy,
            onSelected: () => run('write.theme.duplicate'),
          ),
          if (mine)
            WonkyMenuItem(
              label: 'Rename…',
              icon: LucideIcons.pencil,
              onSelected: () => run('write.theme.rename'),
            ),
          WonkyMenuCheckItem(
            label: 'My default theme',
            checked: isDefault,
            onSelected: () => run('write.theme.setAsDefault'),
          ),
          WonkyMenuItem(
            label: 'Export as JSON…',
            icon: LucideIcons.fileJson,
            onSelected: () => run('write.theme.exportJson'),
          ),
          if (mine) ...[
            const WonkyMenuSeparator(),
            WonkyMenuItem(
              label: 'Delete',
              icon: LucideIcons.trash2,
              destructive: true,
              onSelected: () => run('write.theme.delete'),
            ),
          ],
        ],
        child: ShadButton.ghost(
          key: ValueKey<String>(
            'write.themeEditor.theme.${option.builtinKey ?? option.uuid}',
          ),
          height: 32,
          width: double.infinity,
          mainAxisAlignment: MainAxisAlignment.start,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          backgroundColor: current ? cs.accent : null,
          onPressed: () => state._openTheme(option.uuid),
          leading: ThemeSwatchPreview(option: option, size: 16),
          trailing: isDefault
              ? Icon(LucideIcons.star, size: 13, color: cs.mutedForeground)
              : null,
          child: Expanded(
            child: Text(
              option.name,
              textAlign: TextAlign.start,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.small.copyWith(
                fontSize: 13,
                fontWeight: current ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ElementTree extends StatelessWidget {
  const _ElementTree({required this.c});

  final ThemeEditorController c;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    Widget row(ThemeNode node, {int depth = 0, bool group = false}) {
      final selected = c.selected == node;
      final warn = c.warningsOf(node).isNotEmpty;
      final overridden = c.hasOverrides(node);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        child: Semantics(
          selected: selected,
          child: ShadButton.ghost(
            key: ValueKey<String>('write.themeEditor.node.${node.id}'),
            height: 30,
            width: double.infinity,
            mainAxisAlignment: MainAxisAlignment.start,
            padding: EdgeInsets.only(left: 10.0 + depth * 14, right: 8),
            backgroundColor: selected ? cs.accent : null,
            onPressed: () => c.select(node),
            child: Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      node.label,
                      textAlign: TextAlign.start,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.small.copyWith(
                        fontSize: 13,
                        fontWeight: selected || group
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (warn)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: ShadTooltip(
                        builder: (_) => const Text('Low contrast'),
                        child: Icon(
                          LucideIcons.triangleAlert,
                          size: 13,
                          color: cs.warning,
                        ),
                      ),
                    ),
                  if (overridden)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Semantics(
                        label: 'Customized',
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in themeTree) ...[
          if (g.node != null)
            row(g.node!, group: true)
          else if (g.label.isNotEmpty)
            _SideSubtitle(g.label),
          for (final n in g.nodes) row(n, depth: g.node == null ? 0 : 1),
        ],
      ],
    );
  }
}

// --------------------------------------------------------------- preview

class _PreviewPane extends StatelessWidget {
  const _PreviewPane({required this.state});

  final ThemeEditorScreenState state;

  @override
  Widget build(BuildContext context) {
    final c = state.controller;
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    void run(String id, Map<String, Object?> args) =>
        unawaited(state._invoke(id, args));
    final warnings = c.contrastWarnings;
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 680;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: cs.background,
                border: Border(bottom: BorderSide(color: cs.border)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (!compact) ...[
                      Text(
                        'Preview',
                        style: theme.textTheme.small.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (c.document != null) ...[
                      _Segmented(
                        keyPrefix: 'source',
                        values: const ['sample', 'document'],
                        labels: compact
                            ? const ['Sample', 'Document']
                            : const ['Sample', 'This document'],
                        value: c.source.name,
                        onChanged: (v) =>
                            run('write.theme.setPreviewSource', {'source': v}),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _Segmented(
                      keyPrefix: 'variant',
                      values: const ['light', 'dark'],
                      icons: const [LucideIcons.sun, LucideIcons.moon],
                      labels: const ['Light', 'Dark'],
                      iconsOnly: compact,
                      value: c.variant.name,
                      onChanged: (v) =>
                          run('write.theme.setPreviewVariant', {'variant': v}),
                    ),
                    const SizedBox(width: 8),
                    _Segmented(
                      keyPrefix: 'layout',
                      values: const ['pageless', 'pages'],
                      labels: const ['Pageless', 'Pages'],
                      icons: const [LucideIcons.panelTop, LucideIcons.fileText],
                      iconsOnly: compact,
                      value: c.layout.name,
                      onChanged: (v) =>
                          run('write.theme.setPreviewLayout', {'layout': v}),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 84,
                      child: ShadSelect<double>(
                        key: ValueKey<String>(
                          'write.themeEditor.zoom.${c.zoom}',
                        ),
                        initialValue: c.zoom,
                        minWidth: 84,
                        selectedOptionBuilder: (context, z) =>
                            Text('${(z * 100).round()}%'),
                        onChanged: (z) {
                          if (z != null) c.setZoom(z);
                        },
                        options: [
                          for (final z in const [
                            0.5,
                            0.75,
                            0.9,
                            1.0,
                            1.25,
                            1.5,
                          ])
                            ShadOption(
                              value: z,
                              child: Text('${(z * 100).round()}%'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (warnings.isNotEmpty)
                      ShadButton.ghost(
                        key: const ValueKey<String>(
                          'write.themeEditor.contrastSummary',
                        ),
                        size: ShadButtonSize.sm,
                        leading: Icon(
                          LucideIcons.triangleAlert,
                          size: 14,
                          color: cs.warning,
                        ),
                        onPressed: () =>
                            c.select(nodeOfPair(warnings.first.pairId)),
                        child: Text(
                          compact
                              ? '${warnings.length}'
                              : warnings.length == 1
                              ? '1 contrast warning'
                              : '${warnings.length} contrast warnings',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(child: ThemePreview(controller: c)),
          ],
        );
      },
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.keyPrefix,
    required this.values,
    required this.labels,
    required this.value,
    required this.onChanged,
    this.icons,
    this.iconsOnly = false,
  });

  final bool iconsOnly;
  final String keyPrefix;
  final List<String> values;
  final List<String> labels;
  final List<IconData>? icons;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: cs.muted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < values.length; i++)
            Semantics(
              selected: values[i] == value,
              button: true,
              label: labels[i],
              child: ShadButton.raw(
                key: ValueKey<String>(
                  'write.themeEditor.$keyPrefix.${values[i]}',
                ),
                variant: ShadButtonVariant.ghost,
                size: ShadButtonSize.sm,
                height: 28,
                padding: EdgeInsets.symmetric(horizontal: iconsOnly ? 8 : 10),
                backgroundColor: values[i] == value ? cs.background : null,
                hoverBackgroundColor: values[i] == value
                    ? cs.background
                    : cs.background.withValues(alpha: 0.6),
                leading: icons == null || iconsOnly
                    ? null
                    : Icon(icons![i], size: 14),
                onPressed: () => onChanged(values[i]),
                child: iconsOnly && icons != null
                    ? ShadTooltip(
                        builder: (_) => Text(labels[i]),
                        child: Icon(icons![i], size: 15),
                      )
                    : Text(
                        labels[i],
                        style: theme.textTheme.small.copyWith(
                          fontSize: 12,
                          fontWeight: values[i] == value
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
