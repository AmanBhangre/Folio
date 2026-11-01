import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'data/library_store.dart';
import 'data/models.dart';
import 'services/game_server.dart';
import 'services/importer.dart';
import 'services/save_bridge.dart';

/// Long-lived services, built once in main() and handed in as overrides.
class AppServices {
  AppServices({required this.paths, required this.library, required this.server, required this.saves});
  final AppPaths paths;
  final LibraryStore library;
  final GameServer server;
  final SaveStore saves;

  static Future<AppServices> start() async {
    final paths = await AppPaths.resolve();
    final server = GameServer(paths.gamesDir);
    await server.start();
    return AppServices(paths: paths, library: LibraryStore(paths), server: server, saves: SaveStore(paths));
  }
}

final servicesProvider = Provider<AppServices>((ref) => throw UnimplementedError('overridden in main'));
final initialGamesProvider = Provider<List<Game>>((ref) => const []);
final initialPrefsProvider = Provider<Prefs>((ref) => const Prefs());

// ---------------------------------------------------------------- library

class LibraryNotifier extends Notifier<List<Game>> {
  @override
  List<Game> build() => ref.read(initialGamesProvider);

  AppServices get _s => ref.read(servicesProvider);

  Game? byId(String id) => state.where((g) => g.id == id).firstOrNull;

  Future<void> _commit(List<Game> games) async {
    state = games;
    await _s.library.save(games);
  }

  Future<void> replace(Game game) => _commit([for (final g in state) g.id == game.id ? game : g]);

  Future<void> markPlayed(String id) async {
    final g = byId(id);
    if (g == null) return;
    await replace(g.copyWith(lastPlayedAt: DateTime.now(), isNew: false, updated: false));
  }

  Future<void> setOptions(String id, GameOptions options) async {
    final g = byId(id);
    if (g != null) await replace(g.copyWith(options: options));
  }

  /// The game an import would update: same IFID, else same title.
  Game? matchFor(ImportDetection d) {
    if (d.ifid != null) {
      final byIfid = state.where((g) => g.ifid == d.ifid).firstOrNull;
      if (byIfid != null) return byIfid;
    }
    final t = d.title.toLowerCase();
    return state.where((g) => g.title.toLowerCase() == t).firstOrNull;
  }

  Future<Game> addFromImport(ImportDetection d) async {
    final id = const Uuid().v4().substring(0, 8);
    await Directory(d.stagingDir).rename(_s.paths.gameDir(id));
    final game = Game(
      id: id,
      title: d.title,
      version: d.version,
      engine: d.engine,
      ifid: d.ifid,
      entryPath: d.entryPath,
      sizeBytes: d.sizeBytes,
      fileCount: d.fileCount,
      mediaCount: d.mediaCount,
      webmCount: d.webmCount,
      coverIndex: state.length,
      addedAt: DateTime.now(),
      port: await _s.library.claimPort(atLeast: nextFreePort(state)),
    );
    await _commit([game, ...state]);
    return game;
  }

  /// New files, same id and port: the game keeps its origin, so it keeps
  /// every save. Where the player was is dropped: the new version starts at
  /// its title screen.
  Future<Game> updateFromImport(Game existing, ImportDetection d) async {
    await _s.saves.clearSession(existing.id);
    final dir = Directory(_s.paths.gameDir(existing.id));
    final old = Directory('${dir.path}.old');
    if (await dir.exists()) await dir.rename(old.path);
    await Directory(d.stagingDir).rename(dir.path);
    if (await old.exists()) await old.delete(recursive: true);
    final game = existing.copyWith(
      title: d.title,
      version: d.version.isNotEmpty ? d.version : existing.version,
      engine: d.engine,
      ifid: d.ifid ?? existing.ifid,
      entryPath: d.entryPath,
      sizeBytes: d.sizeBytes,
      fileCount: d.fileCount,
      mediaCount: d.mediaCount,
      webmCount: d.webmCount,
      updated: true,
    );
    await replace(game);
    return game;
  }

  /// Removes the game files and what Folio kept for it. Its saves go with
  /// it: a re-import is a new game on a new port.
  Future<void> delete(String id) async {
    final dir = Directory(_s.paths.gameDir(id));
    if (await dir.exists()) await dir.delete(recursive: true);
    await _s.saves.deleteAll(id);
    await _commit(state.where((g) => g.id != id).toList());
  }
}

final libraryProvider = NotifierProvider<LibraryNotifier, List<Game>>(LibraryNotifier.new);

final gameProvider = Provider.family<Game?, String>((ref, id) => ref.watch(libraryProvider).where((g) => g.id == id).firstOrNull);

final momentsProvider = FutureProvider.family<List<Moment>, String>((ref, id) => ref.read(servicesProvider).saves.moments(id));

/// Moments and Resume restore the game's sessionStorage. SugarCube keeps its
/// current moment there; RPG Maker keeps it in memory, and Harlowe and
/// Snowman are untested, so moments are offered for SugarCube only.
bool supportsMoments(Game g) => g.engine.startsWith('SugarCube');

/// Whether opening the game brings the player back where they stopped. Other
/// engines start at their title screen and load from their own save menu.
bool canResume(Game g) => supportsMoments(g) && g.lastPlayedAt != null;

// ---------------------------------------------------------------- import

enum ImportStage { pick, working, review, error }

class ImportState {
  const ImportState({this.stage = ImportStage.pick, this.fileName, this.detection, this.error});
  final ImportStage stage;
  final String? fileName;
  final ImportDetection? detection;
  final String? error;
}

class ImportNotifier extends Notifier<ImportState> {
  @override
  ImportState build() => const ImportState();

  Future<void> start({required String zipPath, required String fileName}) async {
    final s = ref.read(servicesProvider);
    final staging = p.join(s.paths.stagingDir, const Uuid().v4());
    state = ImportState(stage: ImportStage.working, fileName: fileName);
    try {
      final d = await unpackAndDetect(zipPath: zipPath, stagingDir: staging, originalName: fileName);
      state = ImportState(stage: ImportStage.review, fileName: fileName, detection: d);
    } on ImportException catch (e) {
      await _discard(staging);
      state = ImportState(stage: ImportStage.error, fileName: fileName, error: e.message);
    } on Object catch (e) {
      await _discard(staging);
      state = ImportState(stage: ImportStage.error, fileName: fileName, error: 'Import failed: $e');
    }
  }

  Future<void> cancel() async {
    final d = state.detection;
    if (d != null) await _discard(d.stagingDir);
    state = const ImportState();
  }

  void reset() => state = const ImportState();

  Future<void> _discard(String dir) async {
    final d = Directory(dir);
    if (await d.exists()) await d.delete(recursive: true);
  }
}

final importProvider = NotifierProvider<ImportNotifier, ImportState>(ImportNotifier.new);

// ---------------------------------------------------------------- prefs

enum LibrarySort { recent, az }

enum ConflictRule { newest, ask }

class Prefs {
  const Prefs({this.sort = LibrarySort.recent, this.followSystemTheme = true, this.syncOn = false, this.wifiOnly = true, this.conflict = ConflictRule.newest});
  final LibrarySort sort;
  final bool followSystemTheme;
  final bool syncOn;
  final bool wifiOnly;
  final ConflictRule conflict;

  Prefs copyWith({LibrarySort? sort, bool? followSystemTheme, bool? syncOn, bool? wifiOnly, ConflictRule? conflict}) => Prefs(
        sort: sort ?? this.sort,
        followSystemTheme: followSystemTheme ?? this.followSystemTheme,
        syncOn: syncOn ?? this.syncOn,
        wifiOnly: wifiOnly ?? this.wifiOnly,
        conflict: conflict ?? this.conflict,
      );

  Map<String, Object?> toJson() =>
      {'sort': sort.name, 'followSystemTheme': followSystemTheme, 'syncOn': syncOn, 'wifiOnly': wifiOnly, 'conflict': conflict.name};

  factory Prefs.fromJson(Map<String, Object?> j) => Prefs(
        sort: LibrarySort.values.asNameMap()[j['sort']] ?? LibrarySort.recent,
        followSystemTheme: j['followSystemTheme'] as bool? ?? true,
        syncOn: j['syncOn'] as bool? ?? false,
        wifiOnly: j['wifiOnly'] as bool? ?? true,
        conflict: ConflictRule.values.asNameMap()[j['conflict']] ?? ConflictRule.newest,
      );

  static String file(AppPaths paths) => p.join(paths.root, 'prefs.json');

  static Future<Prefs> load(AppPaths paths) async {
    final f = File(file(paths));
    if (!await f.exists()) return const Prefs();
    try {
      return Prefs.fromJson((jsonDecode(await f.readAsString()) as Map).cast<String, Object?>());
    } on FormatException {
      return const Prefs();
    }
  }
}

class PrefsNotifier extends Notifier<Prefs> {
  @override
  Prefs build() => ref.read(initialPrefsProvider);

  Future<void> update(Prefs Function(Prefs) change) async {
    state = change(state);
    await File(Prefs.file(ref.read(servicesProvider).paths)).writeAsString(jsonEncode(state.toJson()));
  }
}

final prefsProvider = NotifierProvider<PrefsNotifier, Prefs>(PrefsNotifier.new);
