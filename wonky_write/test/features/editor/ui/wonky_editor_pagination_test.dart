import 'dart:async';

import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:wonky_write/features/editor/components/editor_services.dart';
import 'package:wonky_write/features/editor/components/image_size_cache.dart';
import 'package:wonky_write/features/editor/pagination/pagination.dart';
import 'package:wonky_write/features/editor/ui/wonky_editor.dart';
import 'package:wonky_write/features/editor/controller/editor_types.dart';

import '../support/editor_harness.dart';

/// Write 04 §29.3: in Pages mode no block (up to a page tall) straddles a
/// page boundary, also when heights change after the editor was built.
Future<EditorHarness> _pumpPages(
  WidgetTester tester,
  Delta delta, {
  EditorImageServices images = const NetworkImageServices(),
  LayoutMode layout = LayoutMode.pages,
}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final h = EditorHarness(delta);
  h.controller.view.layout = layout;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WonkyEditor(
          controller: h.controller,
          documentTitle: 'Test doc',
          imageServices: images,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(h.dispose);
  return h;
}

WonkyEditorState _state(WidgetTester tester) =>
    tester.state<WonkyEditorState>(find.byType(WonkyEditor));

/// The laid-out rect of [nodeId] in document-layout coordinates.
Rect _rectOf(EditorHarness h, String nodeId) {
  final node = h.controller.document.getNodeById(nodeId)!;
  return h.controller.documentLayout!.getRectForSelection(
    DocumentPosition(nodeId: node.id, nodePosition: node.beginningPosition),
    DocumentPosition(nodeId: node.id, nodePosition: node.endPosition),
  )!;
}

/// Ids of the blocks that cross a page's content boundary (blocks taller
/// than a page may overflow and are skipped).
List<String> _straddling(WidgetTester tester, EditorHarness h) {
  final pagination = _state(tester).pagination;
  return [
    for (final node in h.controller.document)
      if (_rectOf(h, node.id) case final rect
          when rect.height <= pagination.contentHeight &&
              !_insideOnePage(pagination, rect))
        node.id,
  ];
}

bool _insideOnePage(PaginationController pagination, Rect rect) {
  final page = (rect.top / pagination.pageStride).floor();
  return rect.top >= pagination.contentTopOf(page) - 1 &&
      rect.bottom <= pagination.contentBottomOf(page) + 1;
}

String _imageId(EditorHarness h) =>
    h.controller.document.firstWhere((node) => node is ImageNode).id;

Delta _paragraphs(int count, {int seed = 0}) {
  final delta = Delta();
  for (var i = 0; i < count; i += 1) {
    final words = (i * 7 + seed) % 23 + 1;
    delta.insert('${List.filled(words, 'Lorem ipsum').join(' ')}.\n');
  }
  return delta;
}

Delta _image(String src) => Delta()
  ..insert({
    'image': {'id': 'embed-$src', 'src': src, 'alt': ''},
  })
  ..insert('\n');

/// An image that finishes loading when [complete] is called.
class _DelayedImage extends ImageProvider<_DelayedImage> {
  final _info = Completer<ImageInfo>();

  void complete(ImageInfo info) => _info.complete(info);

  @override
  Future<_DelayedImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _DelayedImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(_info.future);
}

class _TestImages extends EditorImageServices {
  _TestImages(this.providers);

  final Map<String, ImageProvider> providers;

  @override
  FutureOr<ImageProvider?> resolve(String src, {double? displayWidth}) =>
      providers[src];
}

Future<ImageInfo> _decoded(WidgetTester tester, int width, int height) async {
  final image = await tester.runAsync(
    () => createTestImage(width: width, height: height),
  );
  return ImageInfo(image: image!);
}

void main() {
  setUp(ImageSizeCache.instance.clear);
  tearDown(ImageSizeCache.instance.clear);

  group('Given the Pages layout', () {
    testWidgets(
      'when rendering paragraphs of varied lengths then none straddles a page boundary',
      (tester) async {
        final h = await _pumpPages(tester, _paragraphs(120));

        expect(_state(tester).pagination.pageCount, greaterThan(2));
        expect(_straddling(tester, h), isEmpty);
      },
    );

    testWidgets(
      'when a collaborator inserts many paragraphs then none straddles a page boundary',
      (tester) async {
        final h = await _pumpPages(tester, Delta()..insert('Start\n'));

        h.controller.applyRemote(_paragraphs(90, seed: 5));
        await tester.pumpAndSettle();

        expect(_state(tester).pagination.pageCount, greaterThan(2));
        expect(_straddling(tester, h), isEmpty);
      },
    );

    testWidgets(
      'when an image is taller than a page then it is scaled down to the page content height',
      (tester) async {
        final provider = _DelayedImage();
        final h = await _pumpPages(
          tester,
          _image('https://x.dev/tall.png'),
          images: _TestImages({'https://x.dev/tall.png': provider}),
        );

        provider.complete(await _decoded(tester, 400, 3000));
        await tester.pumpAndSettle();

        final contentHeight = _state(tester).pagination.contentHeight;
        final size = _rectOf(h, _imageId(h)).size;
        expect(size.height, closeTo(contentHeight, 0.5));
        expect(size.width, closeTo(400 * contentHeight / 3000, 0.5));
        expect(_straddling(tester, h), isEmpty);
      },
    );

    testWidgets(
      'when an image finishes loading taller than its placeholder then it moves to the next page',
      (tester) async {
        final provider = _DelayedImage();
        final h = await _pumpPages(
          tester,
          _paragraphs(6).concat(_image('https://x.dev/photo.png')),
          images: _TestImages({'https://x.dev/photo.png': provider}),
        );
        final pagination = _state(tester).pagination;
        // The 16:9 placeholder fits on page 1; the loaded image won't.
        final placeholder = _rectOf(h, _imageId(h));
        expect(placeholder.bottom, lessThan(pagination.contentBottomOf(0)));
        expect(
          placeholder.top + 800,
          greaterThan(pagination.contentBottomOf(0)),
        );

        provider.complete(await _decoded(tester, 600, 800));
        await tester.pumpAndSettle();

        final loaded = _rectOf(h, _imageId(h));
        expect(loaded.size, const Size(600, 800));
        expect(loaded.top, closeTo(pagination.contentTopOf(1), 0.5));
        expect(pagination.pageCount, 2);
      },
    );

    testWidgets(
      'when an image was loaded before then its placeholder has the loaded size',
      (tester) async {
        ImageSizeCache.instance['https://x.dev/known.png'] = const Size(
          300,
          500,
        );
        final h = await _pumpPages(
          tester,
          _image('https://x.dev/known.png'),
          images: _TestImages({'https://x.dev/known.png': _DelayedImage()}),
        );

        expect(_rectOf(h, _imageId(h)).size, const Size(300, 500));
      },
    );
  });

  group('Given the Pageless layout', () {
    testWidgets(
      'when an image is taller than a page then it keeps its natural height',
      (tester) async {
        final provider = _DelayedImage();
        final h = await _pumpPages(
          tester,
          _image('https://x.dev/tall.png'),
          images: _TestImages({'https://x.dev/tall.png': provider}),
          layout: LayoutMode.pageless,
        );

        provider.complete(await _decoded(tester, 400, 3000));
        await tester.pumpAndSettle();

        expect(_rectOf(h, _imageId(h)).size, const Size(400, 3000));
      },
    );
  });
}
