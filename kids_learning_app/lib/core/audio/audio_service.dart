import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../packs/pack_manager.dart';

/// Sound effects bundled with the app (made by tools/sfx_gen.dart).
enum Sfx { tap, pop, chime, jingle, boom }

/// Spoken prompts bundled with the app (made by VoiceGen from
/// tools/VoiceGen/app_prompts.json into assets/audio/voice/).
enum Prompt {
  letters,
  numbers,
  traceStart,
  hint,
  reward,
  askGrownUp,
  askUpdate,
  shootInOrder,
  tryAgain,
  findPairs;

  /// File name: traceStart -> trace_start.
  String get file =>
      name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
}

/// Plays everything the child hears, on two channels:
/// - voice: one clip at a time; a new clip stops the one before.
/// - effects: short sounds that can play over the voice.
///
/// Missing clips are skipped quietly, so the app still works before the
/// voice clips are generated. No music channel (decided in milestone 3).
///
/// Usage: `AudioService.instance.effect(Sfx.tap)`.
class AudioService {
  AudioService._();

  static final instance = AudioService._();

  final _voice = AudioPlayer();
  final Map<Sfx, AudioPlayer> _effects = {};
  Set<String> _assets = const {};
  int _turn = 0; // bumps on every new voice request, cancelling older ones
  final _random = math.Random();

  static const _praiseCount = 5;

  /// Call once at start: learns which sound files the app includes and
  /// loads the effects so they play without delay.
  Future<void> init() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _assets = manifest.listAssets().where((a) => a.startsWith('assets/audio/')).toSet();
      for (final s in Sfx.values) {
        final path = 'assets/audio/sfx/${s.name}.wav';
        if (!_assets.contains(path)) continue;
        final player = AudioPlayer();
        await player.setAsset(path);
        _effects[s] = player;
      }
    } catch (e) {
      debugPrint('AudioService.init failed: $e');
    }
  }

  /// Plays a short effect from the start.
  Future<void> effect(Sfx s) async {
    final p = _effects[s];
    if (p == null) return;
    try {
      await p.seek(Duration.zero);
      p.play(); // not awaited: play() only completes when the sound ends
    } catch (e) {
      debugPrint('Effect ${s.name} failed: $e');
    }
  }

  /// Says an app prompt.
  Future<void> say(Prompt p) => _sayAll([_AppClip('assets/audio/voice/${p.file}.mp3')]);

  /// Says a random "well done" line.
  Future<void> praise() => _sayAll(
      [_AppClip('assets/audio/voice/praise_${_random.nextInt(_praiseCount) + 1}.mp3')]);

  /// Says one of a pack item's clips, e.g. clip "card" of letter A.
  /// [path] is the item's `audio[clip]` value from pack.json.
  Future<void> sayPack(String packId, String? path) =>
      _sayAll([if (path != null) _PackClip(packId, path)]);

  /// Says an app prompt, then a pack clip (e.g. "Let's trace!" then "A").
  Future<void> sayThen(Prompt p, String packId, String? path) => _sayAll([
        _AppClip('assets/audio/voice/${p.file}.mp3'),
        if (path != null) _PackClip(packId, path),
      ]);

  Future<void> stopVoice() async {
    _turn++;
    try {
      await _voice.stop();
    } catch (_) {}
  }

  Future<void> _sayAll(List<_Clip> clips) async {
    final turn = ++_turn;
    try {
      await _voice.stop();
      for (final clip in clips) {
        if (turn != _turn) return;
        final source = await clip.source(this);
        if (source == null || turn != _turn) continue;
        await _voice.setAudioSource(source);
        if (turn != _turn) return;
        await _voice.play(); // completes when the clip ends or is stopped
      }
    } catch (e) {
      // Browsers block sound until the first tap; a missing or broken
      // clip must never stop the child playing.
      debugPrint('Voice failed: $e');
    }
  }
}

abstract class _Clip {
  Future<AudioSource?> source(AudioService a);
}

class _AppClip implements _Clip {
  _AppClip(this.asset);

  final String asset;

  @override
  Future<AudioSource?> source(AudioService a) async =>
      a._assets.contains(asset) ? AudioSource.asset(asset) : null;
}

class _PackClip implements _Clip {
  _PackClip(this.packId, this.path);

  final String packId;
  final String path;

  @override
  Future<AudioSource?> source(AudioService a) async {
    final bytes = await PackManager.instance.fileBytes(packId, path);
    if (bytes == null) return null;
    // Pack files live in app storage (IndexedDB on the web), so they are
    // handed to the player as a data URI; works on phones and the web.
    return AudioSource.uri(Uri.dataFromBytes(bytes, mimeType: 'audio/mpeg'));
  }
}
