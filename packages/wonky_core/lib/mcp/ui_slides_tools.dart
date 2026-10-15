import '../src/commands/json_schema.dart';
import 'mcp_tool.dart';
import 'slides_tools.dart' show SlidesSchemas;

/// (v2) Wonky Slides UI-bridge tools (`ui.slides.*`, Slides 11 §5),
/// executed in the live Wonky Slides window on the open presentation. The
/// server relays them to windows with `app: slides`; the handlers live in
/// `wonky_slides/lib/mcp/` (SL-42).
///
/// Actions are commands (`ui.invoke_command` with `slides.*` ids); these
/// tools cover window state and what isn't a command: reading the
/// selection and view, navigating, offscreen slide screenshots, animation
/// previews, presenting, the agent highlight, the inspector and side
/// panels, dialogs a command opens, and the context menus.
abstract final class UiSlidesTools {
  static const _scopes = {McpScope.uiControl};
  static const _session = JsonSchema.string(
    description:
        'Target window from ui.list_sessions; defaults to the most recently '
        'focused Wonky Slides window.',
  );

  static ObjectSchema _schema([
    Map<String, JsonSchema> props = const {},
    List<String> required = const [],
  ]) => ObjectSchema(
    properties: {'session_id': _session, ...props},
    required: required,
  );

  /// Panel names of [openPanel]: the docked inspector's tabs and the side
  /// panels (Slides 04 §7, §12).
  static const panels = [
    'inspector_format',
    'inspector_animate',
    'inspector_slide',
    'inspector_theme',
    'layers',
    'themes',
    'accessibility',
    'linked_objects',
    'design_ideas',
    'comments',
    'history',
    'assistant',
  ];

  /// Context menu ids of [getContextMenu] (Slides 04 §11).
  static const contextMenus = [
    'context.slide',
    'context.element',
    'context.text',
    'context.table',
    'context.navigatorSlide',
    'context.navigatorGroup',
    'context.navigatorEmpty',
    'context.mastersLayout',
    'context.mastersMaster',
  ];

  static final getSelection = McpToolDefinition(
    name: 'ui.slides.get_selection',
    title: 'Get the selection',
    description:
        'Returns the selection of the open presentation: deck_uuid, the '
        'current slide {slide_id, position} (1-based), the selected slides '
        'and groups of the navigator, the selected elements {element_id, '
        'kind, name}, the text being edited ({element_id, text_selection: '
        '{start, length, text}}), view_mode, inspector_tab and can_edit.',
    inputSchema: _schema(),
    annotations: McpToolAnnotations.read,
    scopes: _scopes,
  );

  static final select = McpToolDefinition(
    name: 'ui.slides.select',
    title: 'Select slides or elements',
    description:
        'Selects slides in the navigator ({"slides": [2, 3]}) or elements on '
        'a slide ({"elements": ["<id>", {"slide": 3, "placeholder": '
        '"title"}]}; their slide becomes the current one) and scrolls them '
        'into view; selected elements flash with the agent tag. Ids come '
        'from slides.get_slide or ui.slides.get_selection.',
    inputSchema: _schema({
      'slides': SlidesSchemas.slideRefs,
      'elements': SlidesSchemas.elementRefs,
      'slide': SlidesSchemas.slideRef,
    }),
    scopes: _scopes,
  );

  static final goToSlide = McpToolDefinition(
    name: 'ui.slides.go_to_slide',
    title: 'Go to a slide',
    description:
        'Shows a slide (by id or 1-based position) in the editor, like a '
        'click in the navigator.',
    inputSchema: _schema({'slide': SlidesSchemas.slideRef}, ['slide']),
    scopes: _scopes,
  );

  static final getView = McpToolDefinition(
    name: 'ui.slides.get_view',
    title: 'Get the view',
    description:
        'Returns the editor view: view_mode (normal, grid, outline, '
        'masters), zoom (percent) and zoom_fit, the visible slide, the '
        'inspector {open, tab}, the open side panel, the navigator and '
        'notes panes, the open dialog (as ui.get_dialog describes it) and '
        'the running presentation {view, slide_id, position, step, '
        'step_count, blank, ended} or null.',
    inputSchema: _schema(),
    annotations: McpToolAnnotations.read,
    scopes: _scopes,
  );

  static final setView = McpToolDefinition(
    name: 'ui.slides.set_view',
    title: 'Set the view',
    description:
        'Switches the view mode (normal, grid, outline, masters) and/or the '
        'zoom (percent 10–400, or "fit") through the View commands.',
    inputSchema: _schema({
      'view_mode': const JsonSchema.string(
        enumValues: ['normal', 'grid', 'outline', 'masters'],
      ),
      'zoom': const JsonSchema.anyOf([
        JsonSchema.integer(minimum: 10, maximum: 400),
        JsonSchema.string(enumValues: ['fit']),
      ], description: 'Percent, or "fit".'),
    }),
    scopes: _scopes,
  );

  static final screenshotSlide = McpToolDefinition(
    name: 'ui.slides.screenshot_slide',
    title: 'Screenshot a slide',
    description:
        'Returns a PNG of a slide (default: the current one) rendered '
        'offscreen like its thumbnail, independent of zoom and scroll. step: '
        '"edit" (the editing view, default), "final" (after every build) or '
        'a build step (0 = before the first click). scale 0.5, 1 or 2 px '
        'per slide unit (a 1920 × 1080 slide is 1920 × 1080 px at 1).',
    inputSchema: _schema({
      'slide': SlidesSchemas.slideRef,
      'step': const JsonSchema.anyOf([
        JsonSchema.integer(minimum: 0),
        JsonSchema.string(enumValues: ['final', 'edit']),
      ]),
      'scale': const JsonSchema.number(minimum: 0.5, maximum: 2),
    }),
    annotations: McpToolAnnotations.read,
    scopes: _scopes,
  );

  static final previewAnimation = McpToolDefinition(
    name: 'ui.slides.preview_animation',
    title: 'Preview animations',
    description:
        'Plays the builds of a slide (default: the current one) on the '
        'canvas, optionally from a build or with the slide\'s transition, '
        'and resolves when the preview is done (at most 60 s).',
    inputSchema: _schema({
      'slide': SlidesSchemas.slideRef,
      'from_build': const JsonSchema.string(minLength: 1),
      'include_transition': const JsonSchema.boolean(),
    }),
    timeout: const Duration(seconds: 65),
    scopes: _scopes,
  );

  static final present = McpToolDefinition(
    name: 'ui.slides.present',
    title: 'Start presenting',
    description:
        'Starts the presentation in this window from the current slide, '
        'the start or a slide (id or 1-based position), optionally in '
        'presenter view. Full screen needs a user gesture on the web; '
        'without one the presentation fills the window.',
    inputSchema: _schema({
      'from': const JsonSchema.anyOf([
        JsonSchema.string(enumValues: ['current', 'start']),
        SlidesSchemas.slideRef,
      ]),
      'presenter_view': const JsonSchema.boolean(),
    }),
    scopes: _scopes,
  );

  static final presentControl = McpToolDefinition(
    name: 'ui.slides.present_control',
    title: 'Control the presentation',
    description:
        'Drives the running presentation: next / previous (builds, then '
        'slides), next_slide / previous_slide, go_to {slide, step?}, black, '
        'white, unblank, end. Returns {slide_id, position, step, '
        'step_count, blank, ended}.',
    inputSchema: _schema(
      {
        'action': const JsonSchema.string(
          enumValues: [
            'next',
            'previous',
            'next_slide',
            'previous_slide',
            'go_to',
            'black',
            'white',
            'unblank',
            'end',
          ],
        ),
        'slide': SlidesSchemas.slideRef,
        'step': const JsonSchema.integer(minimum: 0),
      },
      ['action'],
    ),
    scopes: _scopes,
  );

  static final highlightElement = McpToolDefinition(
    name: 'ui.slides.highlight_element',
    title: 'Highlight elements',
    description:
        'Flashes a violet outline with the agent\'s name around elements '
        '(their slide becomes the current one) to draw the user\'s '
        'attention; without element_ids, around the slide.',
    inputSchema: _schema({
      'element_ids': const JsonSchema.array(
        JsonSchema.string(minLength: 1),
        minItems: 1,
        maxItems: 50,
      ),
      'slide': SlidesSchemas.slideRef,
      'duration_ms': const JsonSchema.integer(minimum: 200, maximum: 20000),
    }),
    scopes: _scopes,
  );

  static final openPanel = McpToolDefinition(
    name: 'ui.slides.open_panel',
    title: 'Open a panel',
    description:
        'Opens an inspector tab or a side panel: ${panels.join(', ')}. '
        'inspector_theme exists in masters mode; panels of features that '
        'are not available answer unsupported.',
    inputSchema: _schema(
      {
        'panel': const JsonSchema.string(enumValues: panels),
        'section': const JsonSchema.string(
          description:
              'Inspector section to reveal (arrange, text, fill, code, …).',
        ),
      },
      ['panel'],
    ),
    scopes: _scopes,
  );

  static final closePanel = McpToolDefinition(
    name: 'ui.slides.close_panel',
    title: 'Close a panel',
    description:
        'Closes the inspector (an inspector_* name) or collapses the open '
        'side panel (or `panel`) to the icon rail.',
    inputSchema: _schema({
      'panel': const JsonSchema.string(enumValues: panels),
    }),
    scopes: _scopes,
  );

  static const _panelArg = JsonSchema.string(
    description:
        'A panel name of ui.slides.open_panel (inspector_* = the inspector), '
        'or a side panel id; default: the open side panel, else the '
        'inspector.',
  );

  static final describePanel = McpToolDefinition(
    name: 'ui.slides.describe_panel',
    title: 'Describe a panel',
    description:
        'Lists the fields (text inputs, checkboxes, switches with their '
        'values) and buttons of the inspector or the open side panel, like '
        'ui.get_dialog for dialogs. Use the ids with '
        'ui.slides.set_panel_field and ui.slides.press_panel_button; '
        'prefer the slides.* commands for formatting.',
    inputSchema: _schema({'panel': _panelArg}),
    annotations: McpToolAnnotations.read,
    scopes: _scopes,
  );

  static final setPanelField = McpToolDefinition(
    name: 'ui.slides.set_panel_field',
    title: 'Set a panel field',
    description:
        'Sets a field of the inspector or open side panel (ids from '
        'ui.slides.describe_panel): text as if typed, true/false for '
        'checkboxes and switches. Panel edits are commands, so they are '
        'undoable.',
    inputSchema: _schema(
      {
        'panel': _panelArg,
        'field_id': const JsonSchema.string(minLength: 1),
        'value': const JsonSchema.any(),
      },
      ['field_id', 'value'],
    ),
    scopes: _scopes,
  );

  static final pressPanelButton = McpToolDefinition(
    name: 'ui.slides.press_panel_button',
    title: 'Press a panel button',
    description:
        'Presses a button of the inspector or open side panel (ids from '
        'ui.slides.describe_panel).',
    inputSchema: _schema(
      {'panel': _panelArg, 'button_id': const JsonSchema.string(minLength: 1)},
      ['button_id'],
    ),
    scopes: _scopes,
  );

  static final openDialog = McpToolDefinition(
    name: 'ui.slides.open_dialog',
    title: 'Open a command\'s dialog',
    description:
        'Runs a command the way the user does, so that it shows its dialog '
        '(ui.invoke_command runs commands without dialogs and needs their '
        'arguments), and returns once the dialog is open with its '
        'description; then use ui.fill_dialog and ui.press_dialog_button. '
        'Example: {"command_id": "slides.file.pageSetup"}. A command that '
        'needs no dialog just runs (dialog: null).',
    inputSchema: _schema(
      {
        'command_id': const JsonSchema.string(minLength: 1),
        'args': const JsonSchema.object(additionalProperties: true),
      },
      ['command_id'],
    ),
    scopes: _scopes,
  );

  static final getContextMenu = McpToolDefinition(
    name: 'ui.slides.get_context_menu',
    title: 'Get a context menu',
    description:
        'Returns a Slides context menu (${contextMenus.join(', ')}; default: '
        'the one a right-click on the current selection opens) with each '
        'item\'s command id, args, title, enabled and checked state, like '
        'ui.get_menu_tree for the menubar.',
    inputSchema: _schema({
      'menu': const JsonSchema.string(enumValues: contextMenus),
    }),
    annotations: McpToolAnnotations.read,
    scopes: _scopes,
  );

  static final all = [
    getSelection,
    select,
    goToSlide,
    getView,
    setView,
    screenshotSlide,
    previewAnimation,
    present,
    presentControl,
    highlightElement,
    openPanel,
    closePanel,
    describePanel,
    setPanelField,
    pressPanelButton,
    openDialog,
    getContextMenu,
  ];
}
