import 'package:flutter/widgets.dart';
import 'package:wonky_client/wonky_client.dart';

/// Renders a version in the full-screen history route (suite 07 §5). Write
/// renders the document with changes highlighted per author; Sheets the grid
/// with changed cells outlined.
abstract class VersionRenderer {
  /// Builds the read-only rendering of [version] of [itemUuid].
  /// [showChanges] toggles change highlighting (compared to [previous]).
  Widget build(
    BuildContext context, {
    required UuidValue itemUuid,
    required ItemVersionView version,
    ItemVersionView? previous,
    required bool showChanges,
  });

  /// Downloads a version ("Download as…"); null hides the item.
  Future<void> Function(
    BuildContext context,
    UuidValue itemUuid,
    ItemVersionView version,
  )?
  get download => null;
}
