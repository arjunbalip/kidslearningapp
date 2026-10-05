# Kids Learning App

A free, ad-free, offline learning app for toddlers: letters A to Z and numbers 1 to 10 in English. Built with Flutter for Android and the web first, iOS later. Works on phones and tablets, in portrait and landscape.

New here? Start with **SETUP.md**.

## Status

| Milestone | What | State |
| --- | --- | --- |
| 1 | App shell: Home, Letters and Numbers worlds, learn cards, Reward, parent gate | Done |
| 2 | Responsive layouts; pack system: manifest, download, verify, unzip, offline storage (phone and web); pack builder and dev server | Done |
| 3 | Audio: voice clips, sound effects, replay button | Next |
| 4 | Tracing engine for capital and small letters and numbers | Planned |
| 5 | Saved progress, Pip animations, polish, Play Store release | Planned |

## Folders

```
lib/
  main.dart                 app start; loads installed packs
  app/                      theme, routes, responsive rules, config (pack server address)
  packs/                    pack models, safe unzip, PackManager (download, verify, install)
  core/storage/             where pack files live: files on phones, IndexedDB on web
  core/progress/            stars
  activities/learn_cards/   swipeable learn cards
  features/                 home, world menus, reward, parent gate, packs screen
  widgets/                  shared buttons, star counter, Pip, pack images
content/
  letters-en/               pack.json + pictures for the Letters pack
  numbers-en/               pack.json + pictures for the Numbers pack
tools/
  pack_builder.dart         builds server/manifest.json and server/packs/*.zip
  dev_server.dart           serves server/ on http://localhost:8787 for testing
assets/
  fonts/                    Baloo 2 (variable font)
  images/pip.svg            Pip the owl (concept)
```

## Making a pack change

1. Edit files in `content/<pack>/` and raise `"version"` in its `pack.json`.
2. `dart run tools/pack_builder.dart`
3. Test with `dart run tools/dev_server.dart`, then copy `server/` to the IIS packs site.

## Planning documents

Product Plan, Content Plan, Design System, Screen Designs and Technical Design live in the claude.ai Project "Children Learning App".

## Credits

- Pictures: Microsoft Fluent Emoji, MIT licence (`content/LICENSE-FluentEmoji.txt`).
- Font: Baloo 2 by Ek Type, SIL Open Font License (`assets/fonts/OFL-Baloo2.txt`).
