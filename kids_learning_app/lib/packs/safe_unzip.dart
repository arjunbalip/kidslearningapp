import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Unzips a pack into memory as {relative path: bytes}.
///
/// Rejects any path that could escape the pack's folder ("..", a leading
/// "/", a drive letter), so a damaged or malicious zip cannot write
/// anywhere else on the device.
Map<String, Uint8List> safeUnzip(List<int> zipBytes) {
  final archive = ZipDecoder().decodeBytes(zipBytes);
  final files = <String, Uint8List>{};
  for (final entry in archive.files) {
    if (!entry.isFile) continue;
    final name = entry.name.replaceAll('\\', '/');
    if (!isSafePackPath(name)) {
      throw FormatException('Unsafe path in pack: $name');
    }
    final content = entry.content;
    files[name] = content is Uint8List
        ? content
        : Uint8List.fromList(List<int>.from(content as List));
  }
  return files;
}

bool isSafePackPath(String path) {
  if (path.isEmpty || path.startsWith('/') || path.contains(':')) return false;
  final parts = path.split('/');
  return !parts.any((p) => p == '..' || p == '.');
}
