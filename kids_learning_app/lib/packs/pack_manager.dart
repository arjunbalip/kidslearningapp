import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/config.dart';
import '../core/storage/pack_storage.dart';
import 'pack_models.dart';
import 'safe_unzip.dart';

/// Where the server's list of packs stands.
enum ManifestStatus { idle, loading, loaded, offline }

/// What the Packs screen should show for one pack.
enum PackState {
  available, // on the server, not downloaded
  downloading,
  installed, // up to date
  updateAvailable,
  needsAppUpdate, // pack needs a newer app version
  missing, // was installed, but the files are gone (web storage cleared)
}

/// One download in progress.
class DownloadTask {
  DownloadTask(this.entry) : cancel = CancelToken();

  final ManifestEntry entry;
  final CancelToken cancel;
  double progress = 0;
}

/// Downloads, checks, unpacks, stores and loads content packs.
///
/// A single shared instance (`PackManager.instance`). Screens listen to it
/// with ListenableBuilder, much like INotifyPropertyChanged in MAUI.
class PackManager extends ChangeNotifier {
  PackManager._();

  static final PackManager instance = PackManager._();

  static const _indexKey = 'installed_packs_v1';

  final PackStorage _storage = createPackStorage();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(minutes: 5),
  ));

  final Map<String, InstalledPack> _installed = {};
  final Map<String, PackData> _loaded = {};
  final Set<String> _missing = {};
  final Map<String, DownloadTask> _tasks = {};
  final Map<String, Future<Uint8List?>> _fileCache = {};

  List<ManifestEntry> _manifest = const [];
  ManifestStatus manifestStatus = ManifestStatus.idle;

  /// Last error shown on the Packs screen (download failed, etc.).
  String? lastError;

  bool _ready = false;
  bool get isReady => _ready;

  // ---------------------------------------------------------------- start

  /// Call once at app start: reads the list of installed packs and checks
  /// their files are still there.
  Future<void> init() async {
    if (_ready) return;
    try {
      await _storage.init();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_indexKey);
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final v in map.values) {
          final p = InstalledPack.fromJson(v as Map<String, dynamic>);
          _installed[p.id] = p;
        }
      }
      for (final p in _installed.values.toList()) {
        final data = await _loadPackJson(p.installKey);
        if (data == null) {
          _installed.remove(p.id);
          _missing.add(p.id);
        } else {
          _loaded[p.id] = data;
        }
      }
      if (_missing.isNotEmpty) await _saveIndex();
    } catch (e) {
      debugPrint('PackManager.init failed: $e');
    }
    _ready = true;
    notifyListeners();
  }

  // ------------------------------------------------------------- reading

  /// The installed pack of a type ("letters" or "numbers"), or null.
  PackData? packOfType(String type) {
    for (final p in _loaded.values) {
      if (p.type == type) return p;
    }
    return null;
  }

  /// Bytes of one file in an installed pack (cached in memory).
  Future<Uint8List?> fileBytes(String packId, String path) {
    final pack = _loaded[packId];
    if (pack == null) return Future.value(null);
    final key = '${pack.installKey}/$path';
    return _fileCache.putIfAbsent(key, () => _storage.read(pack.installKey, path));
  }

  // ------------------------------------------------------------ manifest

  List<ManifestEntry> get manifest => _manifest;

  /// Fetches manifest.json from the pack server.
  Future<void> refreshManifest() async {
    manifestStatus = ManifestStatus.loading;
    notifyListeners();
    try {
      final res = await _dio.get<String>(
        '$packServerBase/manifest.json',
        // The timestamp stops the browser from using an old cached copy.
        queryParameters: {'t': DateTime.now().millisecondsSinceEpoch},
        options: Options(responseType: ResponseType.plain),
      );
      _manifest = parseManifest(jsonDecode(res.data ?? '{}') as Map<String, dynamic>);
      manifestStatus = ManifestStatus.loaded;
    } catch (e) {
      debugPrint('Manifest failed: $e');
      manifestStatus = ManifestStatus.offline;
    }
    notifyListeners();
  }

  /// Packs to show on the Packs screen: everything on the server, plus
  /// installed packs the server no longer lists.
  List<String> get visiblePackIds {
    final ids = <String>[for (final e in _manifest) e.id];
    for (final id in [..._installed.keys, ..._missing]) {
      if (!ids.contains(id)) ids.add(id);
    }
    return ids;
  }

  ManifestEntry? entryFor(String id) {
    for (final e in _manifest) {
      if (e.id == id) return e;
    }
    return null;
  }

  InstalledPack? installedFor(String id) => _installed[id];

  DownloadTask? taskFor(String id) => _tasks[id];

  String titleFor(String id) =>
      entryFor(id)?.title ?? _installed[id]?.title ?? id;

  String typeFor(String id) => entryFor(id)?.type ?? _installed[id]?.type ?? '';

  PackState stateFor(String id) {
    if (_tasks.containsKey(id)) return PackState.downloading;
    final entry = entryFor(id);
    final installed = _installed[id];
    if (installed == null) {
      if (_missing.contains(id)) return PackState.missing;
      if (entry != null && compareVersions(kAppVersion, entry.minAppVersion) < 0) {
        return PackState.needsAppUpdate;
      }
      return PackState.available;
    }
    if (entry != null && entry.version > installed.version) {
      if (compareVersions(kAppVersion, entry.minAppVersion) < 0) {
        return PackState.installed; // keep the old one until the app updates
      }
      return PackState.updateAvailable;
    }
    return PackState.installed;
  }

  // ------------------------------------------------------------ download

  /// Downloads, verifies and installs the latest version of a pack.
  Future<void> download(String id) async {
    final entry = entryFor(id);
    if (entry == null || _tasks.containsKey(id)) return;
    final task = DownloadTask(entry);
    _tasks[id] = task;
    lastError = null;
    notifyListeners();

    try {
      // The checksum in the address makes every new file a new address,
      // so no browser or server cache can hand back an old copy.
      final base = Uri.parse('$packServerBase/').resolve(entry.url);
      final url = entry.sha256.isEmpty
          ? base.toString()
          : base.replace(queryParameters: {'sha': entry.sha256.substring(0, 16)}).toString();
      final res = await _dio.get<List<int>>(
        url,
        cancelToken: task.cancel,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) {
          final size = total > 0 ? total : entry.sizeBytes;
          if (size > 0) {
            task.progress = (received / size).clamp(0.0, 1.0).toDouble();
            notifyListeners();
          }
        },
      );
      final bytes = res.data ?? const <int>[];

      // 1. The file must match the checksum in the manifest.
      if (entry.sha256.isNotEmpty && sha256.convert(bytes).toString() != entry.sha256) {
        throw const FormatException('The download was damaged. Please try again.');
      }

      // 2. Unzip safely and read pack.json.
      final files = safeUnzip(bytes);
      final packJson = files['pack.json'];
      if (packJson == null) throw const FormatException('This pack has no pack.json.');
      final data = PackData.fromJson(
          jsonDecode(utf8.decode(packJson)) as Map<String, dynamic>);
      if (data.id != entry.id || data.version != entry.version) {
        throw const FormatException('This pack does not match the server list.');
      }

      // 3. Store the new version completely, then switch to it.
      await _storage.writeAll(data.installKey, files);
      final old = _installed[id];
      _installed[id] = InstalledPack(
          id: data.id, version: data.version, title: data.title, type: data.type);
      _loaded[id] = data;
      _missing.remove(id);
      await _saveIndex();

      // 4. Only now remove the previous version.
      if (old != null && old.installKey != data.installKey) {
        await _storage.delete(old.installKey);
        _fileCache.removeWhere((k, _) => k.startsWith('${old.installKey}/'));
      }
    } on DioException catch (e) {
      if (!CancelToken.isCancel(e)) {
        lastError = 'Download failed. Check the internet connection and try again.';
      }
    } catch (e) {
      lastError = e is FormatException ? e.message : 'Download failed: $e';
    } finally {
      _tasks.remove(id);
      notifyListeners();
    }
  }

  void cancelDownload(String id) => _tasks[id]?.cancel.cancel('Cancelled');

  Future<void> remove(String id) async {
    final p = _installed.remove(id);
    _loaded.remove(id);
    _missing.remove(id);
    if (p != null) {
      await _storage.delete(p.installKey);
      _fileCache.removeWhere((k, _) => k.startsWith('${p.installKey}/'));
    }
    await _saveIndex();
    notifyListeners();
  }

  // -------------------------------------------------------------- helpers

  Future<PackData?> _loadPackJson(String installKey) async {
    try {
      if (!await _storage.exists(installKey)) return null;
      final bytes = await _storage.read(installKey, 'pack.json');
      if (bytes == null) return null;
      return PackData.fromJson(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Could not load $installKey: $e');
      return null;
    }
  }

  Future<void> _saveIndex() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _indexKey,
      jsonEncode({for (final p in _installed.values) p.id: p.toJson()}),
    );
  }
}
