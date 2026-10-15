/// Built-in presentation templates of Wonky Slides (04 §15): the
/// `SlidesTemplate` decks (planner operations on a built-in theme and the
/// built-in layouts), the registry `SlidesTemplates` with the gallery
/// uuids, and the builder the decks are written with.
///
/// Pure Dart (client: offline creation and card previews; server: the
/// template gallery and `drive.createPresentation(templateUuid)`).
library;

export 'src/templates/slides_template.dart';
export 'src/templates/template_builder.dart';
export 'src/templates/template_text.dart';
