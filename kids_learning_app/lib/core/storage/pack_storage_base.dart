import 'dart:typed_data';

/// Where unpacked pack files live on the device.
///
/// Files are grouped by an install key such as "letters-en@1", so a new
/// version can be written completely before the old one is removed.
///
/// Two versions exist (picked automatically at build time):
/// - phones: files in the app's private folder (pack_storage_io.dart)
/// - web: the browser's IndexedDB (pack_storage_web.dart)
abstract class PackStorage {
  Future<void> init();

  /// Writes all files of one pack version, replacing anything under [installKey].
  Future<void> writeAll(String installKey, Map<String, Uint8List> files);

  /// Reads one file, or null when it is missing.
  Future<Uint8List?> read(String installKey, String path);

  /// True when this pack version is present (its pack.json exists).
  Future<bool> exists(String installKey);

  Future<void> delete(String installKey);
}

/// Turns "letters-en@1" into a name safe for folders and database boxes.
String safeStorageName(String installKey) =>
    installKey.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
