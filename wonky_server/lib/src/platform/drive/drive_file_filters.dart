import '../common/models.dart';
import 'kind_masks.dart';

/// (v2) Listing rules of files and folders (Drive 02 §2, suite 05 §2/§3.2).
abstract final class DriveFileFilters {
  /// Whether [item] may appear in lists for [userId]: files still
  /// `uploading` only for their uploader, `failed` files never.
  static bool listable(DriveItem item, int userId) =>
      switch (item.uploadState) {
        null || FileUploadState.ready => true,
        FileUploadState.uploading => item.ownerId == userId,
        FileUploadState.failed => false,
      };

  /// Whether [item] may appear in search results (only ready files).
  static bool searchable(DriveItem item) =>
      item.uploadState == null || item.uploadState == FileUploadState.ready;

  /// Applies the v2 filters: upload visibility (lists) or searchability
  /// ([search]), [categories] on `file` items and [foldersContaining] on
  /// folders.
  static List<DriveItem> apply(
    List<DriveItem> items,
    int userId, {
    List<FileCategory>? categories,
    DriveItemKind? foldersContaining,
    bool search = false,
  }) => [
    for (final i in items)
      if ((search ? searchable(i) : listable(i, userId)) &&
          (categories == null ||
              categories.isEmpty ||
              i.kind != DriveItemKind.file ||
              (i.fileCategory != null &&
                  categories.contains(i.fileCategory))) &&
          (foldersContaining == null ||
              i.kind != DriveItemKind.folder ||
              KindMasks.has(i.kindMask, foldersContaining)))
        i,
  ];
}
