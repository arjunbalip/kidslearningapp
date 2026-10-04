import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'pack_storage_base.dart';

PackStorage createPlatformPackStorage() => IoPackStorage();

/// Phones: each pack version is a folder in the app's private support
/// folder, e.g. .../packs/letters-en_1/images/apple.png
class IoPackStorage implements PackStorage {
  Directory? _root;

  Directory get _rootDir {
    final r = _root;
    if (r == null) throw StateError('PackStorage.init() was not called.');
    return r;
  }

  Directory _dirFor(String installKey) =>
      Directory('${_rootDir.path}/${safeStorageName(installKey)}');

  @override
  Future<void> init() async {
    final base = await getApplicationSupportDirectory();
    final root = Directory('${base.path}/packs');
    await root.create(recursive: true);
    _root = root;
  }

  @override
  Future<void> writeAll(String installKey, Map<String, Uint8List> files) async {
    final dir = _dirFor(installKey);
    if (await dir.exists()) await dir.delete(recursive: true);
    for (final entry in files.entries) {
      final file = File('${dir.path}/${entry.key}');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.value, flush: false);
    }
  }

  @override
  Future<Uint8List?> read(String installKey, String path) async {
    final file = File('${_dirFor(installKey).path}/$path');
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<bool> exists(String installKey) =>
      File('${_dirFor(installKey).path}/pack.json').exists();

  @override
  Future<void> delete(String installKey) async {
    final dir = _dirFor(installKey);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
