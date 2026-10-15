/// Code elements of Wonky Slides (specs/wonky_slides/07, 12 §5.6): the
/// element settings (`CodeElementData`, `dataJson`), states
/// (`CodeStateModel`: highlight steps, arrival settings, callouts),
/// `CodeElementModel` (typing scripts, morph plans, transition durations),
/// `CodeSceneComposer` (scenes of a state/step and transition frames) and
/// `CodeElementLayout` (the scene builder's `CodeSceneSource`).
///
/// The grid, tokenizer, steps, edit scripts, typing and morph live in
/// `package:wonky_code`. Pure Dart.
library;

export 'src/code/code_annotations.dart';
export 'src/code/code_element_data.dart';
export 'src/code/code_element_layout.dart';
export 'src/code/code_element_model.dart';
export 'src/code/code_scene_composer.dart';
