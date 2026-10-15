import '../src/commands/json_schema.dart';
import 'mcp_tool.dart';

/// Shared argument types of the headless `slides.*` tools (Slides 11 §3.1).
/// Enum values are snake_case and mapped to the model's camelCase names by
/// the server (`build_in` ↔ `buildIn`).
abstract final class SlidesSchemas {
  static const deck = JsonSchema.string(
    minLength: 1,
    maxLength: 500,
    description:
        'The presentation: its drive item uuid (as in /slides/p/<uuid> URLs) '
        'or a full app URL.',
  );

  static const slideRef = JsonSchema.anyOf([
    JsonSchema.string(
      minLength: 1,
      maxLength: 64,
      description: 'Slide id (UUID or 22-char base-62 id).',
    ),
    JsonSchema.integer(
      minimum: 1,
      description:
          '1-based position in presentation order (skipped slides '
          'count).',
    ),
  ], description: 'A slide: its id or its 1-based position.');

  static const slideRefs = JsonSchema.array(
    slideRef,
    minItems: 1,
    maxItems: 1000,
    description: 'Slides by id or 1-based position.',
  );

  static const placeholderTypes = [
    'title',
    'subtitle',
    'body',
    'picture',
    'chart',
    'table',
    'code',
    'caption',
    'bigNumber',
    'quote',
    'attribution',
  ];

  static const elementRef = JsonSchema.anyOf(
    [
      JsonSchema.string(
        minLength: 1,
        maxLength: 64,
        description: 'Element id.',
      ),
      JsonSchema.object(
        properties: {
          'slide': slideRef,
          'placeholder': JsonSchema.string(enumValues: placeholderTypes),
          'index': JsonSchema.integer(
            minimum: 1,
            description: 'The nth placeholder of that type (default 1).',
          ),
        },
        required: ['slide', 'placeholder'],
      ),
      JsonSchema.object(
        properties: {
          'slide': slideRef,
          'name': JsonSchema.string(minLength: 1, maxLength: 200),
        },
        required: ['slide', 'name'],
      ),
    ],
    description:
        'An element: its id, {slide, placeholder, index?} '
        '("the title of slide 3": {"slide": 3, "placeholder": "title"}) or '
        '{slide, name} (the Layers name).',
  );

  static const elementRefs = JsonSchema.array(
    elementRef,
    minItems: 1,
    maxItems: 200,
  );

  static const frame = JsonSchema.object(
    description:
        'Frame in slide units (the deck size is in slides.get_deck, '
        'default 1920 × 1080; origin top-left).',
    properties: {
      'x': JsonSchema.number(),
      'y': JsonSchema.number(),
      'w': JsonSchema.number(minimum: 1),
      'h': JsonSchema.number(minimum: 1),
      'rotation': JsonSchema.number(description: 'Degrees, clockwise.'),
    },
  );

  static const placement = JsonSchema.object(
    description:
        'Alternative to a frame for new elements: a preset area inside the '
        'slide margin.',
    properties: {
      'preset': JsonSchema.string(
        enumValues: [
          'center',
          'full',
          'fullBleed',
          'leftHalf',
          'rightHalf',
          'topHalf',
          'bottomHalf',
          'leftThird',
          'centerThird',
          'rightThird',
          'grid',
        ],
      ),
      'grid': JsonSchema.object(
        properties: {
          'columns': JsonSchema.integer(minimum: 1, maximum: 12),
          'rows': JsonSchema.integer(minimum: 1, maximum: 12),
          'cell': JsonSchema.integer(
            minimum: 1,
            description: '1-based cell, row by row.',
          ),
          'gap': JsonSchema.number(minimum: 0),
        },
      ),
      'margin': JsonSchema.number(minimum: 0, defaultValue: 80),
    },
  );

  static const color = JsonSchema.string(
    maxLength: 80,
    description:
        '"#RRGGBB", "#RRGGBBAA", "theme:accent1" (+ "/lum:+0.2", '
        '"/alpha:0.5") or "transparent".',
  );

  static const textInput = JsonSchema.anyOf([
    JsonSchema.string(
      maxLength: 200000,
      description:
          'Markdown: one paragraph per line; "- " bullets (indent 2 spaces '
          'per level), "1. " numbers, "- [ ] " checklists, "#"/"##"/"###" '
          'title/heading/subtitle paragraphs, "> " quotes, **bold**, '
          '*italic*, ~~strike~~, `code`, [text](https://…), '
          '[text](slide:3). A line ending in "\\" continues the paragraph.',
    ),
    JsonSchema.object(
      properties: {'markdown': JsonSchema.string(maxLength: 200000)},
      required: ['markdown'],
    ),
    JsonSchema.object(
      properties: {
        'delta': JsonSchema.array(
          JsonSchema.object(additionalProperties: true),
          description: 'Expert: Slides text Delta (validated).',
        ),
      },
      required: ['delta'],
    ),
  ], description: 'Text as Markdown (a string or {markdown}) or {delta}.');

  static const style = JsonSchema.object(
    description: 'Style (merged into the element\'s current style).',
    properties: {
      'fill': JsonSchema.anyOf([
        color,
        JsonSchema.object(
          additionalProperties: true,
          description: 'A fillJson object (02 §5.2), e.g. a gradient.',
        ),
      ]),
      'stroke': JsonSchema.object(
        properties: {
          'color': color,
          'width': JsonSchema.number(minimum: 0, maximum: 200),
          'dash': JsonSchema.string(
            enumValues: ['solid', 'dash', 'dot', 'dashDot', 'none'],
          ),
        },
      ),
      'opacity': JsonSchema.number(minimum: 0, maximum: 1),
      'corner_radius': JsonSchema.number(
        minimum: 0,
        maximum: 1,
        description: 'Rounded-rectangle radius (0–1 of the short side).',
      ),
      'shadow': JsonSchema.string(enumValues: ['none', 'soft', 'strong']),
      'text': JsonSchema.object(
        properties: {
          'font': JsonSchema.string(
            maxLength: 64,
            description: '"@heading", "@body", "@mono" or a font family.',
          ),
          'size': JsonSchema.number(minimum: 6, maximum: 800),
          'color': color,
          'align': JsonSchema.string(
            enumValues: ['left', 'center', 'right', 'justify'],
          ),
          'anchor': JsonSchema.string(enumValues: ['top', 'middle', 'bottom']),
          'autofit': JsonSchema.string(
            enumValues: ['none', 'shrink', 'resize'],
          ),
          'line_height': JsonSchema.number(minimum: 0.7, maximum: 3),
          'style': JsonSchema.string(
            maxLength: 40,
            description:
                'Theme text style: title, subtitle, heading, body, body2, '
                'caption, quote, attribution, bigNumber, label.',
          ),
        },
      ),
    },
  );

  static const transition = JsonSchema.object(
    description:
        'A slide transition (06 §7), e.g. {"type": "push", "duration_ms": '
        '700, "params": {"direction": "left"}} or {"type": "magicMove"}. '
        'Types: none, fade, fadeThroughColor, dissolve, push, slide, '
        'reveal, wipe, zoom, flip, cube, … (unknown types play as fade).',
    properties: {
      'type': JsonSchema.string(minLength: 1, maxLength: 40),
      'duration_ms': JsonSchema.integer(minimum: 0, maximum: 10000),
      'easing': JsonSchema.string(maxLength: 80),
      'params': JsonSchema.object(additionalProperties: true),
      'reverse_on_back': JsonSchema.boolean(),
      'advance': JsonSchema.object(
        properties: {
          'mode': JsonSchema.string(enumValues: ['on_click', 'auto']),
          'after_ms': JsonSchema.integer(minimum: 0, maximum: 600000),
        },
      ),
      'magic_move': JsonSchema.object(
        properties: {
          'text_matching': JsonSchema.string(
            enumValues: ['object', 'word', 'character'],
          ),
          'match_by_content': JsonSchema.boolean(),
        },
      ),
    },
    required: ['type'],
  );

  static const buildKind = JsonSchema.string(
    enumValues: ['build_in', 'build_out', 'emphasis', 'motion'],
  );

  static const trigger = JsonSchema.string(
    enumValues: ['on_click', 'with_previous', 'after_previous'],
  );

  static const delivery = JsonSchema.object(
    properties: {
      'by': JsonSchema.string(
        enumValues: [
          'all',
          'paragraph',
          'paragraph_group',
          'word',
          'character',
          'series',
          'category',
          'point',
          'chart_element',
        ],
      ),
      'order': JsonSchema.string(
        enumValues: ['forward', 'backward', 'center', 'edges', 'random'],
      ),
      'parts': JsonSchema.object(
        properties: {
          'from': JsonSchema.integer(minimum: 1),
          'to': JsonSchema.integer(minimum: 1),
        },
      ),
      'part_trigger': trigger,
      'stagger_ms': JsonSchema.integer(minimum: 0, maximum: 60000),
    },
  );

  static const afterBuild = JsonSchema.object(
    properties: {
      'mode': JsonSchema.string(enumValues: ['none', 'dim', 'hide']),
      'dim_opacity': JsonSchema.number(minimum: 0, maximum: 1),
    },
  );

  static const buildSpec = JsonSchema.object(
    description:
        'A build (06 §2–§4): element, kind, effect id (catalog: resource '
        'wonky://schemas/slides-effects.json; e.g. build_in "fade", '
        '"rise", "pop", "chartGrow", emphasis "pulse", "codeHighlight").',
    properties: {
      'element': elementRef,
      'kind': buildKind,
      'effect': JsonSchema.string(minLength: 1, maxLength: 60),
      'trigger': trigger,
      'delay_ms': JsonSchema.integer(minimum: 0, maximum: 60000),
      'duration_ms': JsonSchema.integer(minimum: 0, maximum: 20000),
      'easing': JsonSchema.string(maxLength: 80),
      'params': JsonSchema.object(additionalProperties: true),
      'delivery': delivery,
      'after_build': afterBuild,
    },
    required: ['element', 'kind', 'effect'],
  );

  static const at = JsonSchema.object(
    description:
        'Where new slides go: {"position": 3} (becomes slide 3), {"after": '
        'SlideRef}, {"before": SlideRef} or {"end": true} (default).',
    properties: {
      'position': JsonSchema.integer(minimum: 1),
      'after': slideRef,
      'before': slideRef,
      'end': JsonSchema.boolean(),
    },
  );

  static const force = JsonSchema.boolean(
    description:
        'Write text other people are editing right now (default false: '
        'being_edited).',
  );

  static const codeState = JsonSchema.object(
    properties: {
      'code': JsonSchema.string(maxLength: 20000),
      'label': JsonSchema.string(maxLength: 80),
      'title': JsonSchema.string(maxLength: 200),
      'language': JsonSchema.string(maxLength: 40),
      'highlight': JsonSchema.string(
        maxLength: 500,
        description:
            'Highlight steps: "1-3 | 5" (each "|" separates a step; line '
            'ranges are 1-based).',
      ),
      'callouts': JsonSchema.object(
        additionalProperties: true,
        description: '{"<step>": "text"} (1-based step → callout).',
      ),
      'arrive': JsonSchema.object(
        additionalProperties: true,
        description:
            'How the code arrives at this state: {"mode": "type" | "morph" '
            '| "instant", "cps"?: number}.',
      ),
    },
    required: ['code'],
  );

  static const codeOptions = JsonSchema.object(
    properties: {
      'line_numbers': JsonSchema.boolean(),
      'start_line': JsonSchema.integer(minimum: 1),
      'wrap': JsonSchema.boolean(),
      'chrome': JsonSchema.string(enumValues: ['none', 'macos', 'tab']),
      'title': JsonSchema.string(maxLength: 200),
      'font_size': JsonSchema.number(minimum: 6, maximum: 200),
      'palette': JsonSchema.string(maxLength: 40),
      'copy_button': JsonSchema.string(
        enumValues: ['never', 'hover', 'always'],
      ),
    },
  );

  /// An object schema with the required `deck` argument plus [props].
  static ObjectSchema of(
    Map<String, JsonSchema> props, {
    List<String> required = const [],
  }) => ObjectSchema(
    properties: {'deck': deck, ...props},
    required: ['deck', ...required],
  );
}

const _changeNote =
    ' Every mutating call is one change with a change_id that '
    'changes.revert undoes for 24 h; results list created ids and '
    'warnings.';

/// Headless `slides.*` tools (Slides 11 §3) and `drive.create_presentation`
/// (suite 09 §4).
abstract final class SlidesTools {
  static const _read = {McpScope.slidesRead};
  static const _edit = {McpScope.slidesEdit};
  static const _destructive = McpToolAnnotations(destructive: true);

  // --------------------------------------------------------------- reading

  static final getDeck = McpToolDefinition(
    name: 'slides.get_deck',
    title: 'Presentation info',
    description:
        'Returns a presentation: title, url, your role, size (slide units), '
        'appearance, theme, sync_version, groups and slides (id, 1-based '
        'position, title, layout key, group, skipped, element and build '
        'counts, transition, has_notes). include adds themes, layouts '
        '(keys and placeholders), notes_preview and timings. Call it first.',
    inputSchema: SlidesSchemas.of({
      'include': const JsonSchema.array(
        JsonSchema.string(
          enumValues: [
            'groups',
            'slides',
            'themes',
            'layouts',
            'notes_preview',
            'timings',
          ],
        ),
      ),
      'limit': const JsonSchema.integer(minimum: 1, maximum: 1000),
      'cursor': McpSchemas.cursor,
    }),
    annotations: McpToolAnnotations.read,
    scopes: _read,
  );

  static final getSlide = McpToolDefinition(
    name: 'slides.get_slide',
    title: 'Read a slide',
    description:
        'Returns one slide: layout, group, background, notes (Markdown), '
        'transition and its elements (id, kind, name, placeholder, frame, '
        'z, text as Markdown, overflow, data summary per kind). include: '
        'elements, text, style, builds, timeline, notes, data (default '
        'elements + text + notes). text_format: markdown (default), rich '
        '(runs and paragraph attributes) or plain.',
    inputSchema: SlidesSchemas.of(
      {
        'slide': SlidesSchemas.slideRef,
        'include': const JsonSchema.array(
          JsonSchema.string(
            enumValues: [
              'elements',
              'text',
              'style',
              'builds',
              'timeline',
              'notes',
              'data',
            ],
          ),
        ),
        'text_format': const JsonSchema.string(
          enumValues: ['markdown', 'rich', 'plain'],
        ),
      },
      required: ['slide'],
    ),
    annotations: McpToolAnnotations.read,
    scopes: _read,
  );

  static final getElement = McpToolDefinition(
    name: 'slides.get_element',
    title: 'Read an element',
    description:
        'Returns one element with its style and full data (table cells, '
        'code states, chart link, image source, children of groups).',
    inputSchema: SlidesSchemas.of(
      {
        'element': SlidesSchemas.elementRef,
        'text_format': const JsonSchema.string(
          enumValues: ['markdown', 'rich', 'plain'],
        ),
      },
      required: ['element'],
    ),
    annotations: McpToolAnnotations.read,
    scopes: _read,
  );

  static final listLayouts = McpToolDefinition(
    name: 'slides.list_layouts',
    title: 'List layouts',
    description:
        'Lists the layouts of the deck\'s themes (default: the deck '
        'theme): key, name, master and placeholders (type, index, frame, '
        'default text). Use the keys in add_slides / update_slide.',
    inputSchema: SlidesSchemas.of({
      'theme_id': const JsonSchema.string(maxLength: 64),
    }),
    annotations: McpToolAnnotations.read,
    scopes: _read,
  );

  static final listThemes = McpToolDefinition(
    name: 'slides.list_themes',
    title: 'List themes',
    description:
        'Lists the themes of the deck (id, name, fonts, colors) and, with '
        'include_builtin, the built-in theme keys for apply_theme.',
    inputSchema: SlidesSchemas.of({
      'include_builtin': const JsonSchema.boolean(),
    }),
    annotations: McpToolAnnotations.read,
    scopes: _read,
  );

  static final search = McpToolDefinition(
    name: 'slides.search',
    title: 'Search a presentation',
    description:
        'Finds text in slide bodies, table cells, notes and code: matches '
        'with slide id, position, element id, where (text, notes, code), '
        'the matched text and context. regex uses Dart/JavaScript syntax.',
    inputSchema: SlidesSchemas.of(
      {
        'query': const JsonSchema.string(minLength: 1, maxLength: 1000),
        'regex': const JsonSchema.boolean(),
        'match_case': const JsonSchema.boolean(),
        'whole_word': const JsonSchema.boolean(),
        'in': const JsonSchema.array(
          JsonSchema.string(enumValues: ['text', 'notes', 'code']),
        ),
        'limit': const JsonSchema.integer(
          minimum: 1,
          maximum: 1000,
          defaultValue: 100,
        ),
      },
      required: ['query'],
    ),
    annotations: McpToolAnnotations.read,
    scopes: _read,
  );

  static final renderSlide = McpToolDefinition(
    name: 'slides.render_slide',
    title: 'Render a slide (PNG)',
    description:
        'P1: renders a slide as PNG. Not available yet on the server: use '
        'ui.slides.screenshot_slide with an open presentation window, or '
        'slides.export_pdf.',
    inputSchema: SlidesSchemas.of(
      {
        'slide': SlidesSchemas.slideRef,
        'step': const JsonSchema.any(),
        'width': const JsonSchema.integer(minimum: 16, maximum: 1920),
        'dark_canvas': const JsonSchema.boolean(),
      },
      required: ['slide'],
    ),
    annotations: McpToolAnnotations.read,
    scopes: _read,
  );

  // -------------------------------------------------------- deck & themes

  static final createPresentation = McpToolDefinition(
    name: 'drive.create_presentation',
    title: 'Create a presentation',
    description:
        'Creates a Wonky Slides presentation (blank with a title slide, or a '
        'copy of template_uuid), optionally with a built-in theme, size, '
        'appearance and an outline: outline_markdown builds the slides '
        '(slides separated by "---" lines; "#"/"##" title, then body '
        'Markdown; "Notes:" starts speaker notes; <!-- layout: titleBody '
        '-->, <!-- group: Intro -->, <!-- skip --> directives; ```fences``` '
        'become code blocks; tables, ![alt](wonky-file://<uuid>) images, '
        '"|||" second column). Returns the item, deck_uuid and slide_ids.',
    inputSchema: ObjectSchema(
      properties: {
        'name': const JsonSchema.string(minLength: 1, maxLength: 255),
        'parent_uuid': const JsonSchema.nullable(McpSchemas.uuid),
        'template_uuid': McpSchemas.uuid,
        'theme': const JsonSchema.string(
          maxLength: 40,
          description: 'Built-in theme key (slides.list_themes).',
        ),
        'size': const JsonSchema.anyOf([
          JsonSchema.string(
            enumValues: [
              'widescreen',
              'standard',
              'wide',
              'square',
              'portrait',
              'a4',
              'letter',
            ],
          ),
          JsonSchema.object(
            properties: {
              'width': JsonSchema.number(minimum: 100, maximum: 20000),
              'height': JsonSchema.number(minimum: 100, maximum: 20000),
            },
            required: ['width', 'height'],
          ),
        ]),
        'appearance': const JsonSchema.string(enumValues: ['light', 'dark']),
        'outline_markdown': const JsonSchema.string(maxLength: 200000),
      },
      required: ['name'],
    ),
    outputSchema: McpSchemas.changeResult,
    scopes: {McpScope.driveWrite},
  );

  static final setDeckProperties = McpToolDefinition(
    name: 'slides.set_deck_properties',
    title: 'Set presentation properties',
    description:
        'Sets the deck title, size (a preset or {width, height, '
        'scale_content}), appearance (light/dark), slide numbers, footer '
        'text, language and the default transition.$_changeNote',
    inputSchema: SlidesSchemas.of({
      'title': const JsonSchema.string(minLength: 1, maxLength: 255),
      'size': const JsonSchema.object(
        properties: {
          'preset': JsonSchema.string(
            enumValues: [
              'widescreen',
              'standard',
              'wide',
              'square',
              'portrait',
              'a4',
              'letter',
            ],
          ),
          'width': JsonSchema.number(minimum: 100, maximum: 20000),
          'height': JsonSchema.number(minimum: 100, maximum: 20000),
          'scale_content': JsonSchema.string(enumValues: ['scale', 'keep']),
        },
      ),
      'appearance': const JsonSchema.string(enumValues: ['light', 'dark']),
      'slide_numbers': const JsonSchema.object(
        properties: {
          'show': JsonSchema.boolean(),
          'hide_on_title': JsonSchema.boolean(),
          'first': JsonSchema.integer(minimum: 0, maximum: 100000),
        },
      ),
      'footer_text': const JsonSchema.nullable(
        JsonSchema.string(maxLength: 500),
      ),
      'language': const JsonSchema.nullable(JsonSchema.string(maxLength: 35)),
      'default_transition': const JsonSchema.nullable(SlidesSchemas.transition),
    }),
    scopes: _edit,
  );

  static final applyTheme = McpToolDefinition(
    name: 'slides.apply_theme',
    title: 'Apply a theme',
    description:
        'Applies a theme to slides (default all; then it also becomes the '
        'deck theme): a built-in key ("wonky", …; slides.list_themes), '
        '{"theme_id"} of this deck or {"deck": uuid, "theme_id"} from '
        'another presentation you can read. Layouts are remapped by key '
        '(layout_mapping overrides: {old_key: new_key}).$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'theme': const JsonSchema.anyOf([
          JsonSchema.string(minLength: 1, maxLength: 40),
          JsonSchema.object(
            properties: {
              'theme_id': JsonSchema.string(maxLength: 64),
              'deck': SlidesSchemas.deck,
            },
            required: ['theme_id'],
          ),
        ]),
        'slides': SlidesSchemas.slideRefs,
        'layout_mapping': const JsonSchema.object(additionalProperties: true),
      },
      required: ['theme'],
    ),
    scopes: _edit,
  );

  // ---------------------------------------------------------------- slides

  static final addSlides = McpToolDefinition(
    name: 'slides.add_slides',
    title: 'Add slides',
    description:
        'Adds 1–100 slides: each with a layout key (default titleBody; '
        'list_layouts), title, body, placeholders ({"subtitle": "…", '
        '"body:2": "…"}; type[:n]), notes, background, skipped and '
        'transition; text is Markdown. at places them (default: the end), '
        'group puts them into a group (id) or a new one ({"new": {title, '
        'color?}}).$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'slides': JsonSchema.array(
          JsonSchema.object(
            properties: {
              'layout': const JsonSchema.string(maxLength: 64),
              'title': SlidesSchemas.textInput,
              'body': SlidesSchemas.textInput,
              'placeholders': const JsonSchema.object(
                additionalProperties: true,
                description: '{"<type>[:n]": TextInput}',
              ),
              'notes': SlidesSchemas.textInput,
              'background': const JsonSchema.anyOf([
                SlidesSchemas.color,
                JsonSchema.object(additionalProperties: true),
              ]),
              'skipped': const JsonSchema.boolean(),
              'transition': SlidesSchemas.transition,
            },
          ),
          minItems: 1,
          maxItems: 100,
        ),
        'at': SlidesSchemas.at,
        'group': const JsonSchema.anyOf([
          JsonSchema.string(maxLength: 64),
          JsonSchema.object(
            properties: {
              'new': JsonSchema.object(
                properties: {
                  'title': JsonSchema.string(maxLength: 200),
                  'color': JsonSchema.string(maxLength: 40),
                },
              ),
            },
            required: ['new'],
          ),
        ]),
      },
      required: ['slides'],
    ),
    scopes: _edit,
  );

  static final addSlidesFromMarkdown = McpToolDefinition(
    name: 'slides.add_slides_from_markdown',
    title: 'Add slides from Markdown',
    description:
        'Adds slides from a deck outline (≤ 200 slides, ≤ 200 KB): slides '
        'separated by "---" lines; the first "#"/"##" heading is the title, '
        'the following lines the body (Markdown); "Notes:" or "???" starts '
        'the speaker notes; directives <!-- layout: key -->, <!-- group: '
        'Title color=blue --> (<!-- group: none --> ends it), <!-- skip -->, '
        '<!-- transition: fade -->; ```lang fences``` become code blocks, '
        'GFM tables tables, ![alt](wonky-file://<uuid>) images, a "|||" '
        'line starts the second column. Without a layout directive the '
        'layout is chosen from the content (title, section, titleBody, '
        'twoColumns, bigNumber, quote, code, imageRight).$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'markdown': const JsonSchema.string(minLength: 1, maxLength: 204800),
        'at': SlidesSchemas.at,
      },
      required: ['markdown'],
    ),
    scopes: _edit,
  );

  static final updateSlide = McpToolDefinition(
    name: 'slides.update_slide',
    title: 'Update a slide',
    description:
        'Changes a slide: layout (key or id; content moves to the new '
        'placeholders), background (color, fillJson or null), skipped, '
        'notes, hide_master_elements, transition (null = the deck '
        'default).$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'slide': SlidesSchemas.slideRef,
        'layout': const JsonSchema.string(maxLength: 64),
        'keep_content': const JsonSchema.boolean(),
        'background': const JsonSchema.nullable(
          JsonSchema.anyOf([
            SlidesSchemas.color,
            JsonSchema.object(additionalProperties: true),
          ]),
        ),
        'skipped': const JsonSchema.boolean(),
        'notes': SlidesSchemas.textInput,
        'hide_master_elements': const JsonSchema.nullable(JsonSchema.boolean()),
        'transition': const JsonSchema.nullable(SlidesSchemas.transition),
        'force': SlidesSchemas.force,
      },
      required: ['slide'],
    ),
    scopes: _edit,
  );

  static final setSpeakerNotes = McpToolDefinition(
    name: 'slides.set_speaker_notes',
    title: 'Set speaker notes',
    description:
        'Sets the speaker notes of up to 200 slides (Markdown: paragraphs, '
        'bullets, numbers, bold, italic, links); mode replace (default) or '
        'append.$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'notes': JsonSchema.array(
          JsonSchema.object(
            properties: {
              'slide': SlidesSchemas.slideRef,
              'notes': SlidesSchemas.textInput,
              'mode': const JsonSchema.string(
                enumValues: ['replace', 'append'],
              ),
            },
            required: ['slide', 'notes'],
          ),
          minItems: 1,
          maxItems: 200,
        ),
        'force': SlidesSchemas.force,
      },
      required: ['notes'],
    ),
    scopes: _edit,
  );

  static final moveSlides = McpToolDefinition(
    name: 'slides.move_slides',
    title: 'Move slides',
    description:
        'Moves slides (kept in their order) to {"position": n} (the first '
        'moved slide becomes slide n), {"after": SlideRef}, {"before": '
        'SlideRef}, {"group": group_id, "position"?: 1-based in the group} '
        'or {"top_level": true} (out of their group, in place).$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'slides': SlidesSchemas.slideRefs,
        'to': const JsonSchema.object(
          properties: {
            'position': JsonSchema.integer(minimum: 1),
            'after': SlidesSchemas.slideRef,
            'before': SlidesSchemas.slideRef,
            'group': JsonSchema.string(maxLength: 64),
            'top_level': JsonSchema.boolean(),
          },
        ),
      },
      required: ['slides', 'to'],
    ),
    scopes: _edit,
  );

  static final duplicateSlides = McpToolDefinition(
    name: 'slides.duplicate_slides',
    title: 'Duplicate slides',
    description:
        'Duplicates slides (each right after its source; match keys are '
        'kept so Magic Move pairs the copies).$_changeNote',
    inputSchema: SlidesSchemas.of(
      {'slides': SlidesSchemas.slideRefs},
      required: ['slides'],
    ),
    scopes: _edit,
  );

  static final deleteSlides = McpToolDefinition(
    name: 'slides.delete_slides',
    title: 'Delete slides',
    description: 'Deletes slides (with their elements and builds).$_changeNote',
    inputSchema: SlidesSchemas.of(
      {'slides': SlidesSchemas.slideRefs},
      required: ['slides'],
    ),
    annotations: _destructive,
    scopes: _edit,
  );

  // ---------------------------------------------------------------- groups

  static final createGroup = McpToolDefinition(
    name: 'slides.create_group',
    title: 'Create a slide group',
    description:
        'Creates a slide group (a section) with title and color; slides '
        '(contiguous or not) are moved into it at the first one\'s '
        'position.$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'title': const JsonSchema.string(minLength: 1, maxLength: 200),
        'color': const JsonSchema.string(maxLength: 40),
        'slides': SlidesSchemas.slideRefs,
      },
      required: ['title'],
    ),
    scopes: _edit,
  );

  static final updateGroup = McpToolDefinition(
    name: 'slides.update_group',
    title: 'Update a slide group',
    description: 'Renames, recolors or skips a group.$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'group_id': const JsonSchema.string(maxLength: 64),
        'title': const JsonSchema.string(minLength: 1, maxLength: 200),
        'color': const JsonSchema.nullable(JsonSchema.string(maxLength: 40)),
        'skipped': const JsonSchema.boolean(),
      },
      required: ['group_id'],
    ),
    scopes: _edit,
  );

  static final moveGroup = McpToolDefinition(
    name: 'slides.move_group',
    title: 'Move a slide group',
    description:
        'Moves a group with its slides: to {"position": n} (its first '
        'slide becomes slide n), {"after_group"}, {"before_group"}, '
        '{"after_slide"} or {"before_slide"} (top-level slides).$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'group_id': const JsonSchema.string(maxLength: 64),
        'to': const JsonSchema.object(
          properties: {
            'position': JsonSchema.integer(minimum: 1),
            'after_group': JsonSchema.string(maxLength: 64),
            'before_group': JsonSchema.string(maxLength: 64),
            'after_slide': SlidesSchemas.slideRef,
            'before_slide': SlidesSchemas.slideRef,
          },
        ),
      },
      required: ['group_id', 'to'],
    ),
    scopes: _edit,
  );

  static final duplicateGroup = McpToolDefinition(
    name: 'slides.duplicate_group',
    title: 'Duplicate a slide group',
    description: 'Duplicates a group with its slides after it.$_changeNote',
    inputSchema: SlidesSchemas.of(
      {'group_id': const JsonSchema.string(maxLength: 64)},
      required: ['group_id'],
    ),
    scopes: _edit,
  );

  static final ungroup = McpToolDefinition(
    name: 'slides.ungroup',
    title: 'Ungroup slides',
    description:
        'Dissolves a group; its slides stay in place at the top level.'
        '$_changeNote',
    inputSchema: SlidesSchemas.of(
      {'group_id': const JsonSchema.string(maxLength: 64)},
      required: ['group_id'],
    ),
    scopes: _edit,
  );

  static final deleteGroup = McpToolDefinition(
    name: 'slides.delete_group',
    title: 'Delete a slide group',
    description:
        'Deletes a group: delete_slides true deletes its slides too, false '
        'keeps them ungrouped.$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'group_id': const JsonSchema.string(maxLength: 64),
        'delete_slides': const JsonSchema.boolean(),
      },
      required: ['group_id', 'delete_slides'],
    ),
    annotations: _destructive,
    scopes: _edit,
  );

  // ------------------------------------------------------ elements & text

  static final addElements = McpToolDefinition(
    name: 'slides.add_elements',
    title: 'Add elements',
    description:
        'Adds 1–200 elements to a slide: text boxes, shapes (geometry: '
        'rect, roundRect, ellipse, triangle, diamond, star5, arrowRight, '
        '…), lines (from/to points or {element, site}), images (file_uuid '
        'of an image you can read), tables (rows of Markdown cells) and '
        'icons (Lucide name or emoji). Position with frame or placement. '
        'Example: {"kind": "text", "text": "Hello", "placement": '
        '{"preset": "center"}}.$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'slide': SlidesSchemas.slideRef,
        'elements': JsonSchema.array(
          JsonSchema.object(
            properties: {
              'kind': const JsonSchema.string(
                enumValues: ['text', 'shape', 'line', 'image', 'table', 'icon'],
              ),
              'frame': SlidesSchemas.frame,
              'placement': SlidesSchemas.placement,
              'name': const JsonSchema.string(maxLength: 200),
              'text': SlidesSchemas.textInput,
              'style': SlidesSchemas.style,
              'shape': const JsonSchema.object(
                properties: {
                  'geometry': JsonSchema.string(maxLength: 40),
                  'adjust': JsonSchema.object(additionalProperties: true),
                },
              ),
              'line': JsonSchema.object(
                properties: {
                  'from': const JsonSchema.object(additionalProperties: true),
                  'to': const JsonSchema.object(additionalProperties: true),
                  'routing': const JsonSchema.string(
                    enumValues: ['straight', 'elbow', 'curved'],
                  ),
                  'arrows': const JsonSchema.object(
                    properties: {
                      'start': JsonSchema.string(maxLength: 20),
                      'end': JsonSchema.string(maxLength: 20),
                    },
                  ),
                },
              ),
              'image': const JsonSchema.object(
                properties: {
                  'file_uuid': McpSchemas.uuid,
                  'crop': JsonSchema.object(additionalProperties: true),
                  'mask': JsonSchema.string(maxLength: 40),
                  'fit': JsonSchema.string(enumValues: ['fill', 'fit']),
                },
                required: ['file_uuid'],
              ),
              'table': JsonSchema.object(
                properties: {
                  'rows': JsonSchema.array(
                    JsonSchema.array(SlidesSchemas.textInput),
                    minItems: 1,
                    maxItems: 50,
                  ),
                  'header_row': const JsonSchema.boolean(),
                  'column_widths': const JsonSchema.array(
                    JsonSchema.number(minimum: 1),
                  ),
                },
                required: ['rows'],
              ),
              'icon': const JsonSchema.object(
                properties: {
                  'name': JsonSchema.string(maxLength: 80),
                  'emoji': JsonSchema.string(maxLength: 16),
                },
              ),
              'alt_text': const JsonSchema.string(maxLength: 2000),
              'decorative': const JsonSchema.boolean(),
              'link': const JsonSchema.object(
                properties: {
                  'url': JsonSchema.string(maxLength: 2000),
                  'slide': SlidesSchemas.slideRef,
                },
              ),
              'match_key': const JsonSchema.string(maxLength: 64),
              'z': const JsonSchema.string(enumValues: ['front', 'back']),
            },
            required: ['kind'],
          ),
          minItems: 1,
          maxItems: 200,
        ),
      },
      required: ['slide', 'elements'],
    ),
    scopes: _edit,
  );

  static final updateElements = McpToolDefinition(
    name: 'slides.update_elements',
    title: 'Update elements',
    description:
        'Updates up to 200 elements: frame, rotation, style (merged), text '
        '(Markdown), name, alt_text, decorative, locked, hidden, link (null '
        'removes), match_key, z (front, back, forward, backward), flip.'
        '$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'updates': JsonSchema.array(
          JsonSchema.object(
            properties: {
              'element': SlidesSchemas.elementRef,
              'frame': SlidesSchemas.frame,
              'rotation': const JsonSchema.number(),
              'style': SlidesSchemas.style,
              'text': SlidesSchemas.textInput,
              'name': const JsonSchema.nullable(
                JsonSchema.string(maxLength: 200),
              ),
              'alt_text': const JsonSchema.nullable(
                JsonSchema.string(maxLength: 2000),
              ),
              'decorative': const JsonSchema.boolean(),
              'locked': const JsonSchema.boolean(),
              'hidden': const JsonSchema.boolean(),
              'link': const JsonSchema.nullable(
                JsonSchema.object(
                  properties: {
                    'url': JsonSchema.string(maxLength: 2000),
                    'slide': SlidesSchemas.slideRef,
                  },
                ),
              ),
              'match_key': const JsonSchema.string(maxLength: 64),
              'z': const JsonSchema.string(
                enumValues: ['front', 'back', 'forward', 'backward'],
              ),
              'flip': const JsonSchema.object(
                properties: {
                  'h': JsonSchema.boolean(),
                  'v': JsonSchema.boolean(),
                },
              ),
            },
            required: ['element'],
          ),
          minItems: 1,
          maxItems: 200,
        ),
        'force': SlidesSchemas.force,
      },
      required: ['updates'],
    ),
    scopes: _edit,
  );

  static final setText = McpToolDefinition(
    name: 'slides.set_text',
    title: 'Set text',
    description:
        'Sets the text of a text box, shape or placeholder (Markdown, see '
        'TextInput): mode replace (default), append or prepend; '
        'keep_formatting (default true) keeps the first run\'s font, size '
        'and color and each paragraph\'s alignment and spacing. Fails with '
        'being_edited while someone types in it unless force.$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'element': SlidesSchemas.elementRef,
        'text': SlidesSchemas.textInput,
        'mode': const JsonSchema.string(
          enumValues: ['replace', 'append', 'prepend'],
        ),
        'keep_formatting': const JsonSchema.boolean(),
        'force': SlidesSchemas.force,
      },
      required: ['element', 'text'],
    ),
    scopes: _edit,
  );

  static final formatText = McpToolDefinition(
    name: 'slides.format_text',
    title: 'Format text',
    description:
        'Formats text of an element: range {"quote": "…", "occurrence"?: '
        'n} (1-based), {"paragraphs": [0-based indexes]} or "all" '
        '(default). format: bold, italic, underline, strike, code, font, '
        'size, color, highlight, style, align, list (bullet, ordered, '
        'check, unchecked, none), indent, line_height; null removes.'
        '$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'element': SlidesSchemas.elementRef,
        'range': const JsonSchema.anyOf([
          JsonSchema.string(enumValues: ['all']),
          JsonSchema.object(
            properties: {
              'quote': JsonSchema.string(minLength: 1, maxLength: 20000),
              'occurrence': JsonSchema.integer(minimum: 1),
            },
            required: ['quote'],
          ),
          JsonSchema.object(
            properties: {
              'paragraphs': JsonSchema.array(
                JsonSchema.integer(minimum: 0),
                minItems: 1,
              ),
            },
            required: ['paragraphs'],
          ),
        ]),
        'format': const JsonSchema.object(
          properties: {
            'bold': JsonSchema.nullable(JsonSchema.boolean()),
            'italic': JsonSchema.nullable(JsonSchema.boolean()),
            'underline': JsonSchema.nullable(JsonSchema.boolean()),
            'strike': JsonSchema.nullable(JsonSchema.boolean()),
            'code': JsonSchema.nullable(JsonSchema.boolean()),
            'font': JsonSchema.nullable(JsonSchema.string(maxLength: 64)),
            'size': JsonSchema.nullable(
              JsonSchema.number(minimum: 6, maximum: 800),
            ),
            'color': JsonSchema.nullable(SlidesSchemas.color),
            'highlight': JsonSchema.nullable(SlidesSchemas.color),
            'style': JsonSchema.nullable(JsonSchema.string(maxLength: 40)),
            'align': JsonSchema.nullable(
              JsonSchema.string(
                enumValues: ['left', 'center', 'right', 'justify'],
              ),
            ),
            'list': JsonSchema.nullable(
              JsonSchema.string(
                enumValues: ['bullet', 'ordered', 'check', 'unchecked', 'none'],
              ),
            ),
            'indent': JsonSchema.nullable(
              JsonSchema.integer(minimum: 0, maximum: 8),
            ),
            'line_height': JsonSchema.nullable(
              JsonSchema.number(minimum: 0.7, maximum: 3),
            ),
          },
        ),
        'force': SlidesSchemas.force,
      },
      required: ['element', 'format'],
    ),
    scopes: _edit,
  );

  static final replaceText = McpToolDefinition(
    name: 'slides.replace_text',
    title: 'Find and replace',
    description:
        'Replaces text in slide bodies, table cells, notes and (with "code" '
        'in in) code: regex (\$1 groups), match_case, whole_word, scope '
        '{slides}. Returns the number of replacements.$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'find': const JsonSchema.string(minLength: 1, maxLength: 1000),
        'replace': const JsonSchema.string(maxLength: 20000),
        'regex': const JsonSchema.boolean(),
        'match_case': const JsonSchema.boolean(),
        'whole_word': const JsonSchema.boolean(),
        'scope': JsonSchema.object(
          properties: {'slides': SlidesSchemas.slideRefs},
        ),
        'in': const JsonSchema.array(
          JsonSchema.string(enumValues: ['text', 'notes', 'code']),
        ),
        'force': SlidesSchemas.force,
      },
      required: ['find', 'replace'],
    ),
    scopes: _edit,
  );

  static final deleteElements = McpToolDefinition(
    name: 'slides.delete_elements',
    title: 'Delete elements',
    description:
        'Deletes elements (with their builds, table cells, code states and '
        'chart links).$_changeNote',
    inputSchema: SlidesSchemas.of(
      {'elements': SlidesSchemas.elementRefs},
      required: ['elements'],
    ),
    annotations: _destructive,
    scopes: _edit,
  );

  static final duplicateElements = McpToolDefinition(
    name: 'slides.duplicate_elements',
    title: 'Duplicate elements',
    description:
        'Duplicates elements, offset by {x, y} (default 24, 24), on their '
        'slide or to_slide.$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'elements': SlidesSchemas.elementRefs,
        'offset': const JsonSchema.object(
          properties: {'x': JsonSchema.number(), 'y': JsonSchema.number()},
        ),
        'to_slide': SlidesSchemas.slideRef,
      },
      required: ['elements'],
    ),
    scopes: _edit,
  );

  static final groupElements = McpToolDefinition(
    name: 'slides.group_elements',
    title: 'Group elements',
    description:
        'Groups elements of one slide into an element group.$_changeNote',
    inputSchema: SlidesSchemas.of(
      {'elements': SlidesSchemas.elementRefs},
      required: ['elements'],
    ),
    scopes: _edit,
  );

  static final ungroupElements = McpToolDefinition(
    name: 'slides.ungroup_elements',
    title: 'Ungroup elements',
    description: 'Dissolves an element group.$_changeNote',
    inputSchema: SlidesSchemas.of(
      {'element': SlidesSchemas.elementRef},
      required: ['element'],
    ),
    scopes: _edit,
  );

  static final alignElements = McpToolDefinition(
    name: 'slides.align_elements',
    title: 'Align elements',
    description:
        'Aligns or distributes elements of one slide relative to their '
        'bounds (selection) or the slide.$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'elements': SlidesSchemas.elementRefs,
        'op': const JsonSchema.string(
          enumValues: [
            'left',
            'center',
            'right',
            'top',
            'middle',
            'bottom',
            'distribute_h',
            'distribute_v',
          ],
        ),
        'relative_to': const JsonSchema.string(
          enumValues: ['selection', 'slide'],
        ),
      },
      required: ['elements', 'op'],
    ),
    scopes: _edit,
  );

  static final setTableCells = McpToolDefinition(
    name: 'slides.set_table_cells',
    title: 'Edit a table',
    description:
        'Edits a table element: inserts/deletes rows and columns (0-based '
        'indexes, applied first: inserts, then deletes), then writes cells '
        '(0-based row/column; text Markdown, fill color).$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'element': SlidesSchemas.elementRef,
        'cells': JsonSchema.array(
          JsonSchema.object(
            properties: {
              'row': const JsonSchema.integer(minimum: 0),
              'column': const JsonSchema.integer(minimum: 0),
              'text': SlidesSchemas.textInput,
              'fill': const JsonSchema.nullable(SlidesSchemas.color),
            },
            required: ['row', 'column'],
          ),
          maxItems: 1000,
        ),
        'insert_rows': const JsonSchema.array(
          JsonSchema.object(
            properties: {
              'at': JsonSchema.integer(minimum: 0),
              'count': JsonSchema.integer(minimum: 1, maximum: 50),
            },
            required: ['at'],
          ),
        ),
        'insert_columns': const JsonSchema.array(
          JsonSchema.object(
            properties: {
              'at': JsonSchema.integer(minimum: 0),
              'count': JsonSchema.integer(minimum: 1, maximum: 20),
            },
            required: ['at'],
          ),
        ),
        'delete_rows': const JsonSchema.array(JsonSchema.integer(minimum: 0)),
        'delete_columns': const JsonSchema.array(
          JsonSchema.integer(minimum: 0),
        ),
        'force': SlidesSchemas.force,
      },
      required: ['element'],
    ),
    scopes: _edit,
  );

  // ---------------------------------------------------------------- charts

  static final listSheetCharts = McpToolDefinition(
    name: 'slides.list_sheet_charts',
    title: 'List spreadsheet charts',
    description:
        'Lists the charts of a Wonky Sheets spreadsheet (chart_id, title, '
        'type, 3D, sheet) for insert_linked_chart, and whether you may copy '
        'its data. Needs the sheets:read scope too.',
    inputSchema: const ObjectSchema(
      properties: {
        'spreadsheet': JsonSchema.string(
          minLength: 1,
          maxLength: 500,
          description: 'Spreadsheet uuid or URL.',
        ),
      },
      required: ['spreadsheet'],
    ),
    annotations: McpToolAnnotations.read,
    scopes: _read,
  );

  static final insertLinkedChart = McpToolDefinition(
    name: 'slides.insert_linked_chart',
    title: 'Insert a chart from Sheets',
    description:
        'Inserts a chart of a spreadsheet (list_sheet_charts) on a slide: '
        'link (default true) keeps it updatable from the spreadsheet, '
        'use_deck_theme (default true) restyles it with the deck theme. The '
        'chart\'s data is copied into the deck: a broader_audience warning '
        'says when the deck is shared more widely than the spreadsheet. '
        'Needs the sheets:read scope too.$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'slide': SlidesSchemas.slideRef,
        'spreadsheet': const JsonSchema.string(minLength: 1, maxLength: 500),
        'chart_id': const JsonSchema.string(minLength: 1, maxLength: 64),
        'frame': SlidesSchemas.frame,
        'placement': SlidesSchemas.placement,
        'link': const JsonSchema.boolean(),
        'use_deck_theme': const JsonSchema.boolean(),
        'auto_update': const JsonSchema.boolean(),
      },
      required: ['slide', 'spreadsheet', 'chart_id'],
    ),
    scopes: _edit,
  );

  static final refreshLinkedCharts = McpToolDefinition(
    name: 'slides.refresh_linked_charts',
    title: 'Update linked charts',
    description:
        'Updates linked charts (default: all of the deck) from their '
        'spreadsheets: updated, up_to_date and failed ({element_id, code}). '
        'Needs the sheets:read scope too.$_changeNote',
    inputSchema: SlidesSchemas.of({'elements': SlidesSchemas.elementRefs}),
    scopes: _edit,
  );

  static final updateChartStyle = McpToolDefinition(
    name: 'slides.update_chart_style',
    title: 'Style a chart',
    description:
        'Changes a chart element\'s deck-side style: use_deck_theme, the 3D '
        'camera ({azimuth, elevation, perspective, preset}), overrides (a '
        'JSON merge patch over the allowed style paths) and background.'
        '$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'element': SlidesSchemas.elementRef,
        'use_deck_theme': const JsonSchema.boolean(),
        'camera': const JsonSchema.object(
          properties: {
            'azimuth': JsonSchema.number(),
            'elevation': JsonSchema.number(),
            'perspective': JsonSchema.number(),
            'preset': JsonSchema.string(maxLength: 40),
          },
        ),
        'overrides': const JsonSchema.object(additionalProperties: true),
        'background': const JsonSchema.nullable(SlidesSchemas.color),
      },
      required: ['element'],
    ),
    scopes: _edit,
  );

  static final unlinkChart = McpToolDefinition(
    name: 'slides.unlink_chart',
    title: 'Unlink a chart',
    description:
        'Unlinks a chart from its spreadsheet (keeps the current picture as '
        'a static chart).$_changeNote',
    inputSchema: SlidesSchemas.of(
      {'element': SlidesSchemas.elementRef},
      required: ['element'],
    ),
    scopes: _edit,
  );

  // ------------------------------------------------------------------ code

  static final addCodeBlock = McpToolDefinition(
    name: 'slides.add_code_block',
    title: 'Add a code block',
    description:
        'Adds a syntax-highlighted code block with 1–50 states (the code '
        'morphs or types from one state to the next while presenting) and '
        'highlight steps ("1-3 | 5"). builds "all_steps" adds one click per '
        'state and highlight step. Default frame: the slide\'s code or body '
        'placeholder area.$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'slide': SlidesSchemas.slideRef,
        'language': const JsonSchema.string(minLength: 1, maxLength: 40),
        'states': const JsonSchema.array(
          SlidesSchemas.codeState,
          minItems: 1,
          maxItems: 50,
        ),
        'frame': SlidesSchemas.frame,
        'placement': SlidesSchemas.placement,
        'options': SlidesSchemas.codeOptions,
        'builds': const JsonSchema.string(enumValues: ['all_steps', 'none']),
      },
      required: ['slide', 'language', 'states'],
    ),
    scopes: _edit,
  );

  static final setCodeStates = McpToolDefinition(
    name: 'slides.set_code_states',
    title: 'Replace code states',
    description:
        'Replaces all states of a code block. builds: "all_steps" rebuilds '
        'the step builds, "keep" (default) keeps the existing builds, '
        '"none" removes the code block\'s builds.$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'element': SlidesSchemas.elementRef,
        'states': const JsonSchema.array(
          SlidesSchemas.codeState,
          minItems: 1,
          maxItems: 50,
        ),
        'builds': const JsonSchema.string(
          enumValues: ['all_steps', 'keep', 'none'],
        ),
        'force': SlidesSchemas.force,
      },
      required: ['element', 'states'],
    ),
    scopes: _edit,
  );

  static final updateCodeBlock = McpToolDefinition(
    name: 'slides.update_code_block',
    title: 'Update a code block',
    description:
        'Changes a code block\'s options (language, line numbers, start '
        'line, wrap, window chrome, title, font size, palette, copy button).'
        '$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'element': SlidesSchemas.elementRef,
        'language': const JsonSchema.string(minLength: 1, maxLength: 40),
        'options': SlidesSchemas.codeOptions,
      },
      required: ['element'],
    ),
    scopes: _edit,
  );

  // -------------------------------------------------------------- builds

  static final setBuilds = McpToolDefinition(
    name: 'slides.set_builds',
    title: 'Set builds (animations)',
    description:
        'Sets the builds of a slide (≤ 200), replacing them (default) or '
        'appending. Effects are validated against the catalog; out-of-range '
        'params are clamped with a warning. Returns build ids and the '
        'timeline summary (clicks, duration).$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'slide': SlidesSchemas.slideRef,
        'builds': const JsonSchema.array(
          SlidesSchemas.buildSpec,
          maxItems: 200,
        ),
        'mode': const JsonSchema.string(enumValues: ['replace', 'append']),
      },
      required: ['slide', 'builds'],
    ),
    scopes: _edit,
  );

  static final updateBuild = McpToolDefinition(
    name: 'slides.update_build',
    title: 'Update a build',
    description:
        'Changes one build: kind, effect, trigger, delay_ms, duration_ms, '
        'easing, params (merged), delivery, after_build.$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'build_id': const JsonSchema.string(maxLength: 64),
        'patch': const JsonSchema.object(
          properties: {
            'kind': SlidesSchemas.buildKind,
            'effect': JsonSchema.string(minLength: 1, maxLength: 60),
            'trigger': SlidesSchemas.trigger,
            'delay_ms': JsonSchema.integer(minimum: 0, maximum: 60000),
            'duration_ms': JsonSchema.integer(minimum: 0, maximum: 20000),
            'easing': JsonSchema.string(maxLength: 80),
            'params': JsonSchema.object(additionalProperties: true),
            'delivery': SlidesSchemas.delivery,
            'after_build': SlidesSchemas.afterBuild,
          },
        ),
      },
      required: ['build_id', 'patch'],
    ),
    scopes: _edit,
  );

  static final deleteBuilds = McpToolDefinition(
    name: 'slides.delete_builds',
    title: 'Delete builds',
    description: 'Deletes builds by id, or every build of a slide.$_changeNote',
    inputSchema: SlidesSchemas.of({
      'build_ids': const JsonSchema.array(
        JsonSchema.string(maxLength: 64),
        minItems: 1,
      ),
      'slide': SlidesSchemas.slideRef,
    }),
    scopes: _edit,
  );

  static final setTransition = McpToolDefinition(
    name: 'slides.set_transition',
    title: 'Set transitions',
    description:
        'Sets the transition into slides (null = the deck default); slides '
        '"all" sets the deck default and clears every slide\'s own '
        'transition. Example: {"slides": [2], "transition": {"type": '
        '"magicMove"}}.$_changeNote',
    inputSchema: SlidesSchemas.of(
      {
        'slides': const JsonSchema.anyOf([
          JsonSchema.string(enumValues: ['all']),
          SlidesSchemas.slideRefs,
        ]),
        'transition': const JsonSchema.nullable(SlidesSchemas.transition),
      },
      required: ['slides', 'transition'],
    ),
    scopes: _edit,
  );

  // ---------------------------------------------------------------- export

  static final exportPdf = McpToolDefinition(
    name: 'slides.export_pdf',
    title: 'Export as PDF',
    description:
        'Exports the presentation as PDF and returns a signed download_url '
        '(15 min), file name, size and page count. options (10 §11.1): '
        'layout (slides, notes, handouts), handouts_per_page, '
        'include_skipped, range ({from, to} positions), page_size, '
        'orientation, frame_slides, bookmarks, quality. '
        'refresh_linked_charts (editors) updates linked charts first.',
    inputSchema: SlidesSchemas.of({
      'options': const JsonSchema.object(additionalProperties: true),
      'refresh_linked_charts': const JsonSchema.boolean(),
    }),
    annotations: const McpToolAnnotations(idempotent: true),
    scopes: _read,
  );

  /// Every tool, in catalog order.
  static final List<McpToolDefinition> all = [
    getDeck,
    getSlide,
    getElement,
    listLayouts,
    listThemes,
    search,
    renderSlide,
    createPresentation,
    setDeckProperties,
    applyTheme,
    addSlides,
    addSlidesFromMarkdown,
    updateSlide,
    setSpeakerNotes,
    moveSlides,
    duplicateSlides,
    deleteSlides,
    createGroup,
    updateGroup,
    moveGroup,
    duplicateGroup,
    ungroup,
    deleteGroup,
    addElements,
    updateElements,
    setText,
    formatText,
    replaceText,
    deleteElements,
    duplicateElements,
    groupElements,
    ungroupElements,
    alignElements,
    setTableCells,
    listSheetCharts,
    insertLinkedChart,
    refreshLinkedCharts,
    updateChartStyle,
    unlinkChart,
    addCodeBlock,
    setCodeStates,
    updateCodeBlock,
    setBuilds,
    updateBuild,
    deleteBuilds,
    setTransition,
    exportPdf,
  ];
}
