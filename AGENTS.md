# Castle Appraiser Agent Notes

## Project Overview

Castle Appraiser is an unofficial Flutter companion app for scoring castles in
Between Two Castles of Mad King Ludwig. The app lets users take a picture of a
castle, convert detected tiles into an editable castle grid, calculate tile and
score-card totals, and save castles as part of games.

The Flutter package name is `btcc`. The project targets **Dart 3 / null safety**
(`sdk: ^3.5.0`) on the latest stable Flutter SDK.

## Tooling (this machine)

- Flutter SDK: `C:\src\flutter` (stable; Dart is bundled)
- Cursor/VS Code: set `dart.flutterSdkPath` to `C:\\src\\flutter`
  (see `.vscode/settings.json`)
- Android Studio / Android SDK may still be required for device/APK builds;
  `flutter analyze` and `flutter test` work without them

## Important Directories

- `lib/main.dart` initializes Flutter, Firebase/Crashlytics on supported
  platforms, locks portrait orientation, loads assets, and starts `App`.
- `lib/src/app/` wires app-level providers and creates the `MaterialApp`.
- `lib/src/screens/` contains user flows for games, castles, camera capture,
  confirmation, editing, debug ML, and logs.
- `lib/src/widgets/` contains reusable UI for castle grids, tile cards,
  builders, lists, dialogs, and score displays.
- `lib/src/models/` contains core domain objects: `Castle`, `Game`, `Tile`,
  `ScoreCard`, Hive persistence models, enums, and generated tile classes.
- `lib/src/state/` contains `ChangeNotifier` stores for camera access,
  TensorFlow Lite model execution, and Hive-backed data.
- `lib/src/tflite/` runs on-device detection (`tflite_detector.dart` via
  `tflite_flutter`) and converts guesses into castle grids.
- `lib/src/utils/` contains helpers for assets, images, grids, navigation,
  statistics, string handling, logging, and tile lookup.
- `test/` contains scoring and conversion tests for the castle model logic.
- `android/` and `ios/` contain the Flutter platform projects.
- `assets/` contains images, labels, and TensorFlow Lite model assets.

## Runtime Flow

- `App` provides `CameraStore`, `TfStore`, and `DataStore` with `provider`.
- `DataStore` initializes Hive boxes for `HiveCastle` and `HiveGame`, exposes
  saved games, persists castle/game changes, and cleans up unused image files on
  supported platforms.
- `CameraStore` manages permissions, camera discovery, and native camera capture
  through the `com.btcc.app/camera` method channel.
- `TfStore` loads the default scoring model, can switch to the identify model,
  runs detections on images or camera frames via `TfliteDetector`, and returns
  processed guesses.
- `TfliteHelper.convertGuessesToCastle` maps model guesses into a `GridList<Tile>`
  by estimating castle dimensions, placing the throne room and placeholders, and
  assigning bonus cards and royal attendants.
- `Castle.scoreCastle` is the central scoring engine. It resolves secret-room
  duplicates, counts tile and decoration totals, scores each tile, and produces a
  `ScoreCard`.

## Development Commands

- Install dependencies: `flutter pub get`
- Run tests: `flutter test`
- Static analysis: `flutter analyze`
- Regenerate Hive adapters (except `tile_id.g.dart`):  
  `dart run build_runner build`
- Watch generated files: `dart run build_runner watch`

## Working Notes

- Persistence uses **hive_ce** / **hive_ce_flutter** (not the unmaintained
  `hive` package).
- `TileId` has Hive field indices above 255, so `hive_ce_generator` cannot
  regenerate `lib/src/models/enums/tile_id.g.dart`. Keep that adapter
  hand-maintained (or restore from git) when regenerating other adapters.
- Gallery saves use the `gal` package (replaces `image_gallery_saver`).
- The scoring model is heavily covered by tests in `test/castle_scoring_test.dart`;
  update or add focused tests when changing `Castle`, `ScoreCard`, tile classes,
  tile enums, or scoring helpers. `ZZTest` and `corridorsTest` document known
  scoring discrepancies and may fail intentionally.
- Be careful with platform-specific code: Windows and web paths often bypass
  Firebase, Crashlytics, camera, image cleanup, or filesystem behavior.
- This is an unofficial companion app. Do not add language implying affiliation
  with Stonemaier Games.
