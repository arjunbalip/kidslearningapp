/// Data classes for the pack system: what the server's manifest.json lists,
/// what a pack.json inside a pack zip contains, and what is installed.
library;

/// One pack listed in the server's manifest.json.
class ManifestEntry {
  const ManifestEntry({
    required this.id,
    required this.version,
    required this.title,
    required this.type,
    required this.minAppVersion,
    required this.sizeBytes,
    required this.sha256,
    required this.url,
  });

  final String id;
  final int version;
  final String title;
  final String type;
  final String minAppVersion;
  final int sizeBytes;
  final String sha256;

  /// Relative to the manifest's address, e.g. "packs/letters-en-v1.zip".
  final String url;

  factory ManifestEntry.fromJson(Map<String, dynamic> j) => ManifestEntry(
        id: j['id'] as String,
        version: (j['version'] as num).toInt(),
        title: j['title'] as String? ?? j['id'] as String,
        type: j['type'] as String? ?? '',
        minAppVersion: j['minAppVersion'] as String? ?? '0.0.0',
        sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
        sha256: (j['sha256'] as String? ?? '').toLowerCase(),
        url: j['url'] as String,
      );
}

List<ManifestEntry> parseManifest(Map<String, dynamic> json) {
  final packs = json['packs'] as List<dynamic>? ?? const [];
  return [
    for (final p in packs) ManifestEntry.fromJson(p as Map<String, dynamic>),
  ];
}

/// One item in a pack: a letter or a number.
class PackItem {
  const PackItem({
    required this.id,
    this.upper,
    this.lower,
    this.number,
    this.word,
    this.label,
    this.image,
    this.audio = const {},
    this.trace = const {},
  });

  final String id;

  // Letters
  final String? upper;
  final String? lower;

  // Numbers
  final int? number;
  final String? label; // "Three balls!"

  // Both
  final String? word; // "Apple" or "Three"
  final String? image; // path inside the pack, e.g. "images/apple.png"
  final Map<String, String> audio; // e.g. {"name": "audio/letter_a_name.mp3"}

  /// Tracing strokes, in writing order, as SVG path strings (one contour
  /// each). Keys: "upper" and "lower" for letters, "number" for numbers.
  /// Coordinates: top line y=0, middle line y=50, base line y=100,
  /// tail line y=150 (capitals and numbers use 0 to 100).
  final Map<String, List<String>> trace;

  factory PackItem.fromJson(Map<String, dynamic> j) => PackItem(
        id: '${j['id']}',
        upper: j['upper'] as String?,
        lower: j['lower'] as String?,
        number: (j['number'] as num?)?.toInt(),
        word: j['word'] as String?,
        label: j['label'] as String?,
        image: j['image'] as String?,
        audio: {
          for (final e in ((j['audio'] as Map<String, dynamic>?) ?? const {}).entries)
            e.key: '${e.value}',
        },
        trace: {
          for (final e in ((j['trace'] as Map<String, dynamic>?) ?? const {}).entries)
            e.key: [for (final s in (e.value as List<dynamic>)) '$s'],
        },
      );
}

/// A pack's pack.json, loaded from storage.
class PackData {
  const PackData({
    required this.id,
    required this.version,
    required this.type,
    required this.title,
    required this.language,
    required this.activities,
    required this.items,
  });

  final String id;
  final int version;
  final String type; // "letters" or "numbers"
  final String title;
  final String language;
  final List<String> activities; // e.g. ["learn_cards", "tracing"]
  final List<PackItem> items;

  /// Key under which this version's files are stored.
  String get installKey => '$id@$version';

  bool supports(String activity) => activities.contains(activity);

  factory PackData.fromJson(Map<String, dynamic> j) => PackData(
        id: j['id'] as String,
        version: (j['version'] as num).toInt(),
        type: j['type'] as String,
        title: j['title'] as String? ?? j['id'] as String,
        language: j['language'] as String? ?? 'en',
        activities: [
          for (final a in (j['activities'] as List<dynamic>? ?? const [])) '$a',
        ],
        items: [
          for (final i in (j['items'] as List<dynamic>? ?? const []))
            PackItem.fromJson(i as Map<String, dynamic>),
        ],
      );
}

/// What the app remembers about an installed pack (saved on the device).
class InstalledPack {
  const InstalledPack({
    required this.id,
    required this.version,
    required this.title,
    required this.type,
  });

  final String id;
  final int version;
  final String title;
  final String type;

  String get installKey => '$id@$version';

  Map<String, dynamic> toJson() =>
      {'id': id, 'version': version, 'title': title, 'type': type};

  factory InstalledPack.fromJson(Map<String, dynamic> j) => InstalledPack(
        id: j['id'] as String,
        version: (j['version'] as num).toInt(),
        title: j['title'] as String? ?? j['id'] as String,
        type: j['type'] as String? ?? '',
      );
}

/// Compares versions like "1.2.0". Returns <0, 0 or >0.
int compareVersions(String a, String b) {
  List<int> parts(String v) =>
      v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final x = parts(a);
  final y = parts(b);
  for (var i = 0; i < 3; i++) {
    final xi = i < x.length ? x[i] : 0;
    final yi = i < y.length ? y[i] : 0;
    if (xi != yi) return xi.compareTo(yi);
  }
  return 0;
}
