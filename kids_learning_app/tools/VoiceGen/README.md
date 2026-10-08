# VoiceGen

Makes every spoken clip in the app as MP3 files. It runs on Windows only, because it uses the Windows MP3 encoder.

- App prompts ("Letters!", "Great job!") come from `app_prompts.json` and go to `assets/audio/voice/`, bundled with the app.
- Pack clips come from `content/<pack>/voice.json` and go to `content/<pack>/audio/`. Their paths are written into the items' `audio` map in `pack.json`.

Each voice file chooses an engine with `"engine"`:

| Engine | Cost | Voice | Letter sounds |
| --- | --- | --- | --- |
| `piper` (used now) | Free, offline, no account | "Cori", British English, public domain | Consonants as "buh", "kuh" (from `soundSay`). Short vowels and x are skipped. |
| `azure` | Free tier, needs an account | `en-IN-NeerjaNeural`, Indian English | Pure sounds from the IPA in `sound` |

## Making the clips

From the project folder:

```
dotnet run --project tools/VoiceGen -- --dry-run   # see what will be said
dotnet run --project tools/VoiceGen                # make new or changed clips
```

- Unchanged clips are skipped, using the record in `cache.json`.
- After a run, raise `"version"` in each changed `pack.json`, then run `dart run tools/pack_builder.dart`.
- `--force` remakes every clip, for example after changing the voice or the speed.

## Piper setup (on a new PC)

`tools/VoiceGen/piper/` is not in git (about 130 MB). To get it back:

1. From https://github.com/rhasspy/piper/releases (release 2023.11.14-2), download `piper_windows_amd64.zip` and unzip it into `tools/VoiceGen/piper/`. This gives `tools/VoiceGen/piper/piper/piper.exe`.
2. From https://huggingface.co/rhasspy/piper-voices/tree/main/en/en_GB/cori/high, download `en_GB-cori-high.onnx` and `en_GB-cori-high.onnx.json` into `tools/VoiceGen/piper/`.

Settings in the voice files:
- `lengthScale` sets the speed. Above 1 is slower; it's 1.15 for toddlers.
- `sentenceSilence` sets the pause after each sentence, in seconds.

## Azure setup (optional, for the Indian English voice)

1. Sign in at https://portal.azure.com.
2. **Create a resource**, choose **Speech**, region **Central India**, tier **Free F0**.
3. Copy **KEY 1** from **Keys and Endpoint**, then run this once in PowerShell and restart VS Code:
   ```
   setx AZURE_SPEECH_KEY "paste-key-here"
   setx AZURE_SPEECH_REGION "centralindia"
   ```
4. Set `"engine": "azure"` in the voice files, then run VoiceGen with `--force`.

The key must never go into git or into the app.

## Changing what is said

- Edit the templates in `voice.json` or the texts in `app_prompts.json`, then run VoiceGen again.
- `{field}` is filled from the pack item, for example `{upper}`, `{word}` or `{label}`.
- `{count}` counts up to the item's number.
- A part in `[square brackets]` is left out when a field inside it is empty.
- Piper texts are plain text. Azure texts are SSML, so they can use `<break>`, `<say-as>` and `<phoneme>`.
- To change a letter's sound, edit `soundSay` (Piper) or `sound` (IPA, Azure) in `pack.json`. For Piper, you can check what it will say by running `piper.exe` with `--debug`, which prints the sounds it makes.
