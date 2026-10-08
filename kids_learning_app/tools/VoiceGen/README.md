# VoiceGen

Makes every spoken clip in the app with Azure Neural TTS (voice `en-IN-NeerjaNeural`, Indian English).

- App prompts ("Letters!", "Great job!") come from `app_prompts.json` and go to `assets/audio/voice/`, bundled with the app.
- Pack clips come from `content/<pack>/voice.json` and go to `content/<pack>/audio/`. Their paths are written into the items' `audio` map in `pack.json`.

## One-time setup (about 10 minutes)

1. Sign in at https://portal.azure.com. A free account is enough.
2. **Create a resource**, search for **Speech**, then click **Create**.
   - Region: **Central India**.
   - Pricing tier: **Free F0**. It gives 0.5 million characters a month; a full run of this app uses well under 50,000.
3. Open the new resource, go to **Keys and Endpoint**, and copy **KEY 1**.
4. In PowerShell, run this once. It saves the key for your Windows user, not in the project:
   ```
   setx AZURE_SPEECH_KEY "paste-key-here"
   setx AZURE_SPEECH_REGION "centralindia"
   ```
   Close and reopen VS Code so it sees them.

The key must never go into git or into the app. VoiceGen runs only on your PC.

## Making the clips

From the project folder:

```
dotnet run --project tools/VoiceGen -- --dry-run   # see what will be said, no Azure calls
dotnet run --project tools/VoiceGen                # make new or changed clips
```

- The free tier allows 20 requests a minute, so a full run of 84 clips takes about 5 minutes.
- Unchanged clips are skipped, using the record in `cache.json`.
- After a run, raise `"version"` in each changed `pack.json`, then run `dart run tools/pack_builder.dart`.

## Changing what is said

- Edit the text in `voice.json` or `app_prompts.json`, then run VoiceGen again. It remakes only the changed clips.
- `{field}` is filled from the pack item (`{upper}`, `{word}`, `{label}` and so on). `{count}` counts up to the item's number.
- Letter sounds are IPA in each item's `"sound"` in `pack.json` (for example `æ` for "a"). If one sounds wrong, change it there; `ː` holds a sound longer.
- `--force` remakes every clip, for example after changing the voice.
