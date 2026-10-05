// A tiny pack server for development. Serves the server/ folder made by
// tools/pack_builder.dart, with the CORS header the web version needs.
//
// Run from the project folder and leave it running:
//   dart run tools/dev_server.dart          (port 8787)
//   dart run tools/dev_server.dart 9000     (another port)
//
// The real server later is IIS on your Windows Server (see Technical Design).

import 'dart:io';

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args.first) : 8787;
  final root = Directory('server');
  if (!root.existsSync()) {
    stderr.writeln('server/ not found. First run: dart run tools/pack_builder.dart');
    exit(1);
  }

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('Pack server running.');
  stdout.writeln('  This PC / Chrome:   http://localhost:$port/manifest.json');
  stdout.writeln('  Android emulator:   http://10.0.2.2:$port/manifest.json');
  stdout.writeln('  Phone on same Wi-Fi: http://<this PC\'s IP>:$port/manifest.json');
  stdout.writeln('Press Ctrl+C to stop.\n');

  await for (final req in server) {
    final res = req.response;
    res.headers.set('Access-Control-Allow-Origin', '*');
    res.headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.headers.set('Access-Control-Allow-Headers', '*');

    if (req.method == 'OPTIONS') {
      res.statusCode = HttpStatus.noContent;
      await res.close();
      continue;
    }

    final parts = Uri.decodeComponent(req.uri.path)
        .split('/')
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.any((p) => p == '..' || p.startsWith('.'))) {
      res.statusCode = HttpStatus.forbidden;
      await res.close();
      continue;
    }

    final file = File([root.path, ...parts].join('/'));
    if (parts.isEmpty || !file.existsSync()) {
      res.statusCode = HttpStatus.notFound;
      res.write('Not found');
      await res.close();
      stdout.writeln('404 ${req.uri.path}');
      continue;
    }

    final ext = parts.last.split('.').last.toLowerCase();
    res.headers.contentType = switch (ext) {
      'json' => ContentType.json,
      'zip' => ContentType('application', 'zip'),
      'html' => ContentType.html,
      'mp3' => ContentType('audio', 'mpeg'),
      'png' => ContentType('image', 'png'),
      _ => ContentType.binary,
    };
    res.headers.set(
      'Cache-Control',
      ext == 'json' ? 'no-cache' : 'public, max-age=31536000, immutable',
    );
    res.contentLength = file.lengthSync();
    await res.addStream(file.openRead());
    await res.close();
    stdout.writeln('200 ${req.uri.path}');
  }
}
