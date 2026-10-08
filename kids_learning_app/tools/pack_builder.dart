// PackBuilder: turns each folder in content/ into a pack zip and writes
// server/manifest.json.
//
// Run from the project folder:
//   dart run tools/pack_builder.dart
//
// For each content/<pack>/ folder with a pack.json it:
//   1. checks pack.json (id, version, type, items) and that every picture
//      and audio file it names exists, and (for packs with "tracing")
//      that every item has valid strokes,
//   2. zips the folder as server/packs/<id>-v<version>.zip,
//   3. records size and SHA-256 in server/manifest.json.
//
// To publish a changed pack: raise its "version" in pack.json, run this
// again, and copy the server/ folder to the IIS packs site.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path_parsing/path_parsing.dart';

const defaultMinAppVersion = '0.2.0';

void main(List<String> args) {
  final contentDir = Directory('content');
  if (!contentDir.existsSync()) {
    stderr.writeln('content/ folder not found. Run this from the project folder.');
    exit(1);
  }
  final packsDir = Directory('server/packs')..createSync(recursive: true);

  final entries = <Map<String, dynamic>>[];
  var failed = 0;

  final folders = contentDir.listSync().whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final dir in folders) {
    final packFile = File('${dir.path}/pack.json');
    if (!packFile.existsSync()) continue;
    stdout.writeln('Pack folder: ${dir.path}');

    Map<String, dynamic> pack;
    try {
      pack = jsonDecode(packFile.readAsStringSync()) as Map<String, dynamic>;
    } catch (e) {
      stderr.writeln('  ERROR: pack.json is not valid JSON: $e');
      failed++;
      continue;
    }

    final problems = _check(pack, dir);
    if (problems.isNotEmpty) {
      for (final p in problems) {
        stderr.writeln('  ERROR: $p');
      }
      failed++;
      continue;
    }

    final id = pack['id'] as String;
    final version = pack['version'] as int;

    final archive = Archive();
    final files = dir.listSync(recursive: true).whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      final rel = f.path.substring(dir.path.length + 1).replaceAll('\\', '/');
      if (rel.split('/').any((part) => part.startsWith('.'))) continue; // hidden files
      if (rel == 'voice.json') continue; // VoiceGen's script, not needed on the phone
      final bytes = f.readAsBytesSync();
      archive.addFile(ArchiveFile(rel, bytes.length, bytes));
    }

    final zip = ZipEncoder().encode(archive)!;
    final zipName = '$id-v$version.zip';
    File('${packsDir.path}/$zipName').writeAsBytesSync(zip);

    entries.add({
      'id': id,
      'version': version,
      'title': pack['title'] ?? id,
      'type': pack['type'],
      'minAppVersion': pack['minAppVersion'] ?? defaultMinAppVersion,
      'sizeBytes': zip.length,
      'sha256': sha256.convert(zip).toString(),
      'url': 'packs/$zipName',
    });
    stdout.writeln('  OK: ${archive.length} files, '
        '${(zip.length / 1024).toStringAsFixed(0)} KB -> server/packs/$zipName');
  }

  final manifest = {
    'schema': 1,
    'updated': DateTime.now().toUtc().toIso8601String().substring(0, 10),
    'packs': entries,
  };
  File('server/manifest.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
  stdout.writeln('\nWrote server/manifest.json with ${entries.length} pack(s).');

  if (failed > 0) {
    stderr.writeln('$failed pack folder(s) had errors and were skipped.');
    exit(1);
  }
}

List<String> _check(Map<String, dynamic> pack, Directory dir) {
  final problems = <String>[];
  final id = pack['id'];
  final version = pack['version'];
  final type = pack['type'];
  final items = pack['items'];

  if (id is! String || id.isEmpty) problems.add('"id" is missing.');
  if (version is! int || version < 1) {
    problems.add('"version" must be a whole number, 1 or more.');
  }
  if (type is! String || type.isEmpty) problems.add('"type" is missing.');
  if (items is! List || items.isEmpty) {
    problems.add('"items" is empty.');
    return problems;
  }

  final activities = pack['activities'];
  final tracing = activities is List && activities.contains('tracing');
  final traceKeys = type == 'numbers' ? ['number'] : ['upper', 'lower'];

  for (final raw in items) {
    if (raw is! Map<String, dynamic>) {
      problems.add('An item is not an object.');
      continue;
    }
    final refs = <String>[
      if (raw['image'] is String) raw['image'] as String,
      if (raw['audio'] is Map)
        for (final v in (raw['audio'] as Map).values) '$v',
    ];
    for (final r in refs) {
      if (r.startsWith('/') || r.contains('..')) {
        problems.add('item "${raw['id']}": unsafe path "$r".');
      } else if (!File('${dir.path}/$r').existsSync()) {
        problems.add('item "${raw['id']}": file not found: $r');
      }
    }
    if (tracing) problems.addAll(_checkTrace(raw, traceKeys));
  }
  return problems;
}

/// Each stroke must be an SVG path string with exactly one starting point.
List<String> _checkTrace(Map<String, dynamic> item, List<String> keys) {
  final problems = <String>[];
  final trace = item['trace'];
  for (final key in keys) {
    final strokes = trace is Map ? trace[key] : null;
    if (strokes is! List || strokes.isEmpty) {
      problems.add('item "${item['id']}": no trace strokes for "$key".');
      continue;
    }
    for (final s in strokes) {
      final counter = _MoveCounter();
      try {
        writeSvgPathDataToPath('$s', counter);
      } catch (_) {
        problems.add('item "${item['id']}" $key: bad stroke "$s".');
        continue;
      }
      if (counter.moves != 1) {
        problems.add('item "${item['id']}" $key: stroke must start with one M: "$s".');
      }
    }
  }
  return problems;
}

class _MoveCounter extends PathProxy {
  int moves = 0;

  @override
  void moveTo(double x, double y) => moves++;

  @override
  void lineTo(double x, double y) {}

  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) {}

  @override
  void close() {}
}
