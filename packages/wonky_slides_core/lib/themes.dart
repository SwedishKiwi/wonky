/// Wonky Slides themes, layouts and masters (Slides 05): theme JSON model
/// and codecs, validator, migrations, JSON schemas, resolver, contrast
/// checks, font resolution, slide sizes, the built-in layouts, placeholder
/// inheritance, layout remapping and the 10 built-in themes.
///
/// Pure Dart (client, server, MCP).
library;

export 'src/theme/builtins/builtin_theme_def.dart';
export 'src/theme/builtins/builtin_themes.dart';
export 'src/theme/builtins/theme_package.dart';
export 'src/theme/color/color_ref.dart';
export 'src/theme/color/oklch.dart';
export 'src/theme/fonts/slides_fonts.dart';
export 'src/theme/json/json_util.dart'
    show
        ThemeIssue,
        ThemeIssueSeverity,
        IssueSink,
        JsonMap,
        canonicalJson,
        jsonEquals;
export 'src/theme/layout/layout_library.dart';
export 'src/theme/layout/layout_remap.dart';
export 'src/theme/layout/placeholder_resolver.dart';
export 'src/theme/layout/placeholder_type.dart';
export 'src/theme/layout/slide_size.dart';
export 'src/theme/model/background.dart';
export 'src/theme/model/box_text_style.dart';
export 'src/theme/model/common.dart'
    show SlideAppearance, ThemeFontRole, FontRef, SuRect;
export 'src/theme/model/deck_theme_data.dart';
export 'src/theme/model/object_style_defaults.dart';
export 'src/theme/model/object_styles.dart';
export 'src/theme/model/paint.dart';
export 'src/theme/model/text_styles.dart';
export 'src/theme/model/theme_colors.dart';
export 'src/theme/model/theme_fonts.dart';
export 'src/theme/resolve/contrast.dart';
export 'src/theme/resolve/resolved_theme.dart';
export 'src/theme/resolve/theme_resolver.dart';
export 'src/theme/schema/json_schemas.dart';
export 'src/theme/schema/migrations.dart';
export 'src/theme/schema/validator.dart';
