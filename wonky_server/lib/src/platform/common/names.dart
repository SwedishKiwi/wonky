import 'errors.dart';

/// Validates and normalizes drive item names (specs/05 §2): 1–255 chars,
/// trimmed, no `/`.
String normalizeItemName(String name) {
  final trimmed = name.trim().replaceAll(RegExp(r'[\u0000-\u001f]'), '');
  if (trimmed.isEmpty) throw Errors.invalid('The name cannot be empty.');
  if (trimmed.length > 255) {
    throw Errors.invalid('The name can have at most 255 characters.');
  }
  if (trimmed.contains('/')) {
    throw Errors.invalid('The name cannot contain "/".');
  }
  return trimmed;
}
