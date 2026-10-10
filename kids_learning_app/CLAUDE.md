# Kids Learning App: notes for Claude

Free, ad-free, offline learning app for toddlers (2 to 5): English letters A to Z (capital and small) and numbers 1 to 10. Long-term: more age groups, languages (Hindi next) and competitive exams, all delivered as downloadable content packs. Flutter, Android and web first, iOS later (owner has a Mac).

## The owner

- Experienced in C#, WPF and .NET MAUI; new to Flutter. Explain Flutter ideas in C#/MAUI terms when useful.
- Project folder: `C:\AIApps\ChildreaApp\kidslearningapp\kids_learning_app` (the old `C:\AIApps\kids_learning_app` copy is no longer used). Flutter SDK: `C:\src\flutter`.
- Runs the app from VS Code on Windows. End every change with one line saying what to do: hot reload, hot restart, or stop + `flutter pub get` + run.
- Prefers planning and design before code; keep the planning documents in step with decisions.

## Planning documents (claude.ai artifacts, open in a browser)

- Product Plan: https://claude.ai/code/artifact/93a0eca2-89cc-4ad5-a294-65a6e68dfd0b
- Content Plan: https://claude.ai/code/artifact/821d06de-a1f4-43a9-b244-c7afb3b902ca
- Technical Design: https://claude.ai/code/artifact/e86ad390-3770-43d2-9fff-af7a67486b47
- Design System: https://claude.ai/artifact/EZwRogHFdXNTA2NFWetkm8
- Screen Designs: https://claude.ai/artifact/LWPyYsU9eGbeJQFKhVfcMf

## Decisions made since the documents

- **Metro (Windows Phone) tile layout** for Home and the world menus (`lib/widgets/metro.dart`, flutter_staggered_grid_view). New worlds = new tiles.
- **No orientation lock.** Every screen works on phones and tablets, portrait and landscape. Choose layouts from real space with `LayoutBuilder` (`c.maxHeight > c.maxWidth`), not from the window size. Sizes come from `Screen.of(context)` in `lib/app/responsive.dart`.
- **Pack builder is a Dart script** (`tools/pack_builder.dart`), not C#. VoiceGen (Azure TTS) is still planned as C#.
- Content pictures are not bundled: they come only from downloaded packs.
- **Tracing** (`lib/activities/tracing/`): strokes are SVG path strings in each item's `trace` (`upper`/`lower` for letters, `number` for numbers) on writing lines top 0, middle 50, base 100, tail 150. Ball-and-stick school style. `Tracer` is pure logic (unit-tested); the drawn ink is the clean stroke, not the shaky finger. Off the path only pauses (amber hint), progress is kept; a pink dot shows the stroke as soon as a shape appears and after 4 s idle. One star per finished shape, auto-advance, Reward after the last. Separate tiles for capitals and small letters. No swiping on trace screens (it fights with tracing).
- **Audio** (`lib/core/audio/audio_service.dart`): voice channel (one clip at a time, new stops old) + effects channel; **no music**. Voice engine: **Piper** (free, offline, no account) with voice Cori (en_GB-cori-high, public domain), length scale 1.15; Azure `en-IN-NeerjaNeural` kept as an option (`"engine"` in each voice file). Piper cannot say pure short vowels or x, so those cards skip the sound (item `soundSay` empty; consonants as "buh", "kuh"); Azure uses the IPA in `sound`. Letter card says name, phonics sound (IPA in item `sound`), "A is for Apple!"; number card says "Three! One, two, three. Three balls!". Effects (tap, pop, chime, jingle) are generated tones (`tools/sfx_gen.dart`), bundled. App prompts bundled in `assets/audio/voice/`; item clips in packs (`audio` map). Missing clips are skipped silently. Screens start sounds in a post-frame callback so the previous screen's `stopVoice()` in dispose does not cut them off. VoiceGen is C# (`tools/VoiceGen`, net10.0-windows, MP3 via Windows Media Foundation/NAudio; Piper binary and voice in `tools/VoiceGen/piper/`, git-ignored; Azure key only in env var `AZURE_SPEECH_KEY`, never in git).
- **Saved progress** (`lib/core/progress/progress.dart`, shared_preferences, device only): stars, traced items per kind (`upper`/`lower`/`number`), learn cards seen, games finished. Only **tracing** fills the strips in the world menus (outline, world colour = partly, gold = all); learn cards seen are shown only in the parent area (swiping is not learning). Parent area has a Progress section with Reset.
- **Games**: Balloon Cannon (`lib/activities/cannon/`): shoot balloons in order (rounds 3,3,4,4,5), Play tile in each world. Cannon/balloons, not guns (Play Families policy). Memory (`lib/activities/memory/`, both worlds): Letters levels 3 → 4 → 6 same-letter pairs, then 4 → 6 capital-and-small pairs (A and a, **no picture** so the letter shape counts); Numbers levels 3 → 4 → 6. Levels saved per world (`memoryLevels` in Progress, Reset sets back). **Settings** button in the game (anyone, picture buttons): letters ABC / abc / Aa, cards 6 / 8 / 12 / 16, or Auto (the default level ladder; only Auto gets harder). Saved per world as `memoryChoices`. Grid prefers a neat layout (e.g. 4×4) when nearly as big. Mismatches wiggle amber and close after 1.5 s; refresh deals new random cards.
- Planning documents are Claude Docs; when the Docs connector is not connected, record decisions here and update the documents later. **Pending:** add the tracing, audio, progress and games decisions above to the Content Plan and Technical Design.

## Rules that do not change

- No ads, analytics, tracking, crash reporting or accounts. Collect no personal data (Play Families policy, COPPA, India DPDP).
- Everything a child does is spoken (voice-first); no reading needed on child screens.
- Kind feedback only: never red or a buzzer for mistakes (use `AppColors.hintAmber`).
- Child tap targets at least 60 px on phones, 80 on tablets (`Screen.tap`).
- Parent area only behind the parent gate (`ParentAccess`).
- Colours, spacing and radii only from `lib/app/theme.dart` (matches the Design System). Text via `baloo(size, weight:)` because Baloo 2 is a variable font.

## Structure

- `lib/packs/` PackManager (manifest, download, SHA-256 check, safe unzip, install, remove), models.
- `lib/core/storage/` PackStorage: files on phones (`_io`), Hive/IndexedDB on web (`_web`), chosen by conditional import.
- `lib/activities/learn_cards/` swipeable cards; `lib/features/` screens; `lib/widgets/` shared widgets.
- `content/<pack>/pack.json` + images: source of each pack. `server/` is build output (git-ignored).

## Commands

- `flutter pub get`, `flutter run -d chrome`, `flutter test`
- `dart run tools/pack_builder.dart` builds `server/manifest.json` and `server/packs/*.zip`
- `dart run tools/sfx_gen.dart` makes the sound effects; `dotnet run --project tools/VoiceGen` makes voice clips (see its README)
- `dart run tools/dev_server.dart` serves packs at http://localhost:8787 (emulator: 10.0.2.2:8787)
- Real phone: `flutter run --dart-define=PACK_SERVER=http://<PC-IP>:8787`

## Milestones

1. App shell. Done.
2. Responsive Metro layout + pack system. Done (tested in Chrome and on an Android phone).
3. Audio: clips generated by the C# VoiceGen tool (Piper, Azure optional), stored in packs and app assets; `AudioService` with voice and effects channels (just_audio). Done (packs v4).
4. Tracing engine (checkpoints along strokes from pack.json, forgiving tolerance; touch 9%, mouse 6%). Done (packs v2, app 0.3.0).
5. Saved progress (built, being tested), Pip Rive animations, polish, Play Store release.
