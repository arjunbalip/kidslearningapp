# Setup guide (Windows)

Do this once on your PC. It takes about 30 to 45 minutes, mostly downloads.

## 1. Install the tools

1. **Git for Windows** from https://git-scm.com (default options are fine).
2. **VS Code** from https://code.visualstudio.com.
3. In VS Code, open Extensions (Ctrl+Shift+X), search **Flutter** and install the one by Dart Code. It also installs Dart.
4. **Flutter SDK**: follow the official Windows guide at https://docs.flutter.dev/get-started/install/windows.
   - Put Flutter in a simple path such as `C:\src\flutter` (not in Program Files).
   - Add `C:\src\flutter\bin` to your PATH, then close and reopen terminals.
5. **Android Studio** from https://developer.android.com/studio.
   - Open it once and let it install the Android SDK.
   - In *More Actions > SDK Manager > SDK Tools*, tick **Android SDK Command-line Tools**.
   - In *Device Manager*, create an emulator (a tablet or a Pixel phone is fine).

## 2. Check everything

Open a new terminal (PowerShell) and run:

```
flutter doctor
flutter doctor --android-licenses
```

Accept all licences. Run `flutter doctor` again until Flutter, Android toolchain, Chrome and VS Code show a green tick. Visual Studio (the C++ one) is not needed: we are not building a Windows desktop app.

If Flutter asks you to turn on **Developer Mode** for symlinks, run `start ms-settings:developers` and switch it on.

## 3. First run of the app

In a terminal:

```
cd C:\AIApps\ChildreaApp\kidslearningapp\kids_learning_app

git init
git add .
git commit -m "Milestone 1: app shell"

flutter create . --project-name kids_learning_app --org com.example.kidslearning --platforms android,web
flutter pub get
flutter run -d chrome
```

- `flutter create .` adds the `android` and `web` folders around the code that is already here. It does not overwrite existing files.
- If `git status` ever shows `lib/`, `pubspec.yaml` or `test/` as changed after that step, restore them with `git checkout -- lib pubspec.yaml test`.
- `com.example.kidslearning` is a placeholder. We will change it to your real app id before the first Play Store upload.

## 4. Run from VS Code

1. *File > Open Folder* and choose `C:\AIApps\ChildreaApp\kidslearningapp\kids_learning_app`.
2. Bottom-right of VS Code, pick a device: **Chrome** or your **Android emulator**.
3. Press **F5**. While it runs, save a file and the app updates instantly (hot reload).

## 5. Milestone 2: test pack downloads

The app no longer has pictures built in: they arrive in downloaded packs.

1. In a terminal in the project folder, get the new packages:
   ```
   flutter pub get
   ```
2. Build the packs (makes `server\manifest.json` and `server\packs\*.zip`):
   ```
   dart run tools/pack_builder.dart
   ```
3. Start the local pack server in a **second terminal** and leave it running:
   ```
   dart run tools/dev_server.dart
   ```
   Check it works: open http://localhost:8787/manifest.json in Chrome.
4. Run the app (F5). Then:
   - Tap **Letters**: Pip says "Ask a grown-up to download this!"
   - Tap the **gear**, answer the sum, then **Download** Letters and Numbers.
   - Go back: both worlds now open with pictures.
   - Refresh the browser or restart the app: the packs are still there.
   - Stop the pack server (Ctrl+C): everything still works offline.

**Android emulator:** works with the same server (the app uses `10.0.2.2:8787`, the emulator's name for your PC).
**Real phone on your Wi-Fi:** find your PC's IP with `ipconfig`, allow port 8787 in Windows Firewall when asked, and run
`flutter run --dart-define=PACK_SERVER=http://YOUR-PC-IP:8787`.

## 6. What to try in milestone 1

- Home: tap **Letters** or **Numbers**.
- Letters: **Learn** swipes A to Z with pictures; going past Z opens the Reward screen and adds a star.
- Numbers: **Learn** counts 1 to 10 with objects.
- **Trace** shows a "coming next" screen for now.
- Gear icon (top right of Home): the parent gate sum, then the Packs page.
- Not yet: sound, tracing, real pack downloads, saving stars after closing the app.

If anything shows an error, copy the red text from the terminal or VS Code's Debug Console and paste it to Claude.
