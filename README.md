# Folio

Play the HTML and Twine games you download, offline, on your phone.

Folio takes a game's `.zip`, unpacks it, and plays it full screen with no
internet connection. It works with:

- **Twine:** SugarCube 2, Harlowe 3, Snowman
- **RPG Maker MV and MZ** (the `www` / `index.html` web export)
- **Other HTML5 games** that run from an `index.html`

No account. Your games and saves stay on your phone, and Folio doesn't see
what you play.

**Discord:** https://discord.gg/7aDA2AxtgN — downloads, bug reports, and votes
on what gets built next.

**F95zone:** [the Folio thread](https://f95zone.to/threads/folio-play-html-twine-and-rpg-maker-mv-mz-games-offline-on-android-iphone-coming.321256/)
— questions and "does game X work?" reports.

## Install

### Android

1. Download `Folio-<version>.apk` from
   [Releases](https://github.com/AmanBhangre/Folio/releases).
2. Open the file on your phone. Android asks you to allow installs from your
   browser or file manager once; allow it.
3. Updates install over the old version and keep your games and saves.

### iPhone

Coming soon through SideStore. Join the Discord to hear when it's ready.

## Using it

1. **Add a game:** tap Import a game and pick the `.zip` from Files
   (Downloads, iCloud Drive, Google Drive, a USB stick).
2. **Play:** each game gets its own storage, so its saves never mix with
   another game's. Save and load from the game's own menu, as you would on a
   computer.
3. **SugarCube games** also open where you stopped (Resume), and you can jump
   back to an earlier moment.
4. **Updating a game:** import the new version's zip. Folio recognises it and
   keeps every save.
5. **Deleting a game** removes its files, saves and moments from the phone.

## Known limits (0.1)

- RPG Maker games start at their title screen; load your save from their menu.
- Resume and moments work for SugarCube only.
- No sync between devices yet. It's planned for later.

## Building from source

Flutter 3.47.8. Use the committed `pubspec.lock`.

```sh
flutter pub get
flutter test
flutter run                   # offline build
flutter build apk --release   # Android
```

Release APKs are built and signed by GitHub Actions
(`.github/workflows/android.yml`) on every push to `main`; a tag like
`folio-v0.1.0` also publishes a Release.

| Piece | File | What it does |
|---|---|---|
| Import | `lib/services/importer.dart` | Unpacks the zip in the background, finds the game's `index.html` (even nested), reads Twine story data for title, engine and IFID |
| Local server | `lib/services/game_server.dart` | Serves each game on its own `127.0.0.1` port, so each game has its own browser storage. Supports byte ranges (iOS video). Never serves outside the game's folder |
| Save bridge | `lib/services/save_bridge.dart` | Keeps SugarCube's session state for Resume and moments. The game's own saves stay in the game's storage |
| Player | `lib/screens/player_screen.dart` | Full screen web view, inline video, orientation lock, keep awake, text size; links out of the game are blocked |
| Library | `lib/state.dart`, `lib/data/` | JSON on disk, written atomically |

`lib/services/cloud_sync.dart` and `supabase/` are groundwork for future sync;
0.1 builds don't use them.
