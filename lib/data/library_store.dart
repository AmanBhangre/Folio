import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// On-disk layout, all inside the app's private support directory:
///
/// ```
/// library.json                 the game list
/// next_port                    the port the next imported game gets
/// games/<id>/                  unpacked game files (served by GameServer)
/// saves/<id>/session.json      where the player is (Resume)
/// saves/<id>/moments/          moments the player saved
/// staging/<uuid>/              a zip being imported
/// ```
///
/// The game's own saves are not here: the game keeps them in its browser
/// storage, which is separate per game because each game has its own port.
class AppPaths {
  AppPaths._(this.root);

  /// For tests: a layout rooted anywhere, without creating folders.
  AppPaths.at(this.root);

  final String root;

  static Future<AppPaths> resolve() async {
    final dir = await getApplicationSupportDirectory();
    final paths = AppPaths._(dir.path);
    for (final d in [paths.gamesDir, paths.savesRoot, paths.stagingDir]) {
      await Directory(d).create(recursive: true);
    }
    return paths;
  }

  String get libraryFile => p.join(root, 'library.json');
  String get nextPortFile => p.join(root, 'next_port');
  String get gamesDir => p.join(root, 'games');
  String get savesRoot => p.join(root, 'saves');
  String get stagingDir => p.join(root, 'staging');
  String gameDir(String id) => p.join(gamesDir, id);
  String savesDir(String id) => p.join(savesRoot, id);
}

class LibraryStore {
  LibraryStore(this.paths);
  final AppPaths paths;

  /// Ports below this were the one shared port of earlier builds.
  static const firstPort = 47900;

  /// A port no game has had before. Ports are never reused: a deleted game's
  /// storage stays in the WebView, and a new game on its port would see it.
  /// [atLeast] guards against a lost next_port file.
  Future<int> claimPort({int atLeast = firstPort}) async {
    final f = File(paths.nextPortFile);
    final stored = await f.exists() ? int.tryParse((await f.readAsString()).trim()) : null;
    final port = [stored ?? firstPort, atLeast, firstPort].reduce((a, b) => a > b ? a : b);
    await f.writeAsString('${port + 1}');
    return port;
  }

  Future<List<Game>> load() async {
    final f = File(paths.libraryFile);
    if (!await f.exists()) return [];
    try {
      final raw = jsonDecode(await f.readAsString()) as List;
      final games = raw.map((e) => Game.fromJson((e as Map).cast<String, Object?>())).toList();
      // Games imported before ports were per game get theirs now.
      if (games.any((g) => g.port == 0)) {
        for (var i = 0; i < games.length; i++) {
          if (games[i].port == 0) games[i] = games[i].copyWith(port: await claimPort(atLeast: nextFreePort(games)));
        }
        await save(games);
      }
      return games;
    } on FormatException {
      // A half-written file from a crash. Keep it aside rather than lose it.
      await f.copy('${paths.libraryFile}.corrupt');
      return [];
    }
  }

  /// Write to a temp file then rename, so a crash never leaves a torn library.
  Future<void> save(List<Game> games) async {
    final tmp = File('${paths.libraryFile}.tmp');
    await tmp.writeAsString(jsonEncode(games.map((g) => g.toJson()).toList()));
    await tmp.rename(paths.libraryFile);
  }
}

/// One past the highest port any of [games] has.
int nextFreePort(List<Game> games) => games.fold(LibraryStore.firstPort, (m, g) => g.port >= m ? g.port + 1 : m);
