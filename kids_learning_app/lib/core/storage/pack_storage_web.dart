import 'dart:typed_data';

import 'package:hive_ce/hive.dart';

import 'pack_storage_base.dart';

PackStorage createPlatformPackStorage() => WebPackStorage();

/// Web: each pack version is a Hive "lazy box" stored in the browser's
/// IndexedDB; keys are file paths, values are the file bytes.
///
/// The browser may clear this storage (low space, "clear site data"),
/// so PackManager checks packs are still present at start.
class WebPackStorage implements PackStorage {
  final Map<String, LazyBox<Uint8List>> _open = {};

  String _boxName(String installKey) => 'pack_${safeStorageName(installKey)}';

  Future<LazyBox<Uint8List>> _box(String installKey) async {
    final name = _boxName(installKey);
    final existing = _open[name];
    if (existing != null && existing.isOpen) return existing;
    final box = await Hive.openLazyBox<Uint8List>(name);
    _open[name] = box;
    return box;
  }

  @override
  Future<void> init() async {
    // Hive needs no folder on the web.
  }

  @override
  Future<void> writeAll(String installKey, Map<String, Uint8List> files) async {
    final box = await _box(installKey);
    await box.clear();
    await box.putAll(files);
  }

  @override
  Future<Uint8List?> read(String installKey, String path) async {
    final box = await _box(installKey);
    return box.get(path);
  }

  @override
  Future<bool> exists(String installKey) async {
    if (!await Hive.boxExists(_boxName(installKey))) return false;
    final box = await _box(installKey);
    return box.containsKey('pack.json');
  }

  @override
  Future<void> delete(String installKey) async {
    final name = _boxName(installKey);
    final box = _open.remove(name);
    if (box != null && box.isOpen) await box.close();
    await Hive.deleteBoxFromDisk(name);
  }
}
