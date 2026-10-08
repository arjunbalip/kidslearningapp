import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/audio/audio_service.dart';
import 'packs/pack_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read which packs are installed (and check their files) before the
  // first screen, so the worlds know straight away what they can show.
  await PackManager.instance.init();
  await AudioService.instance.init();

  // All screens adapt to portrait and landscape, phones and tablets,
  // so the orientation is not locked.
  runApp(const KidsApp());
}
