import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/data/library_store.dart';
import 'package:folio/data/models.dart';
import 'package:folio/services/game_server.dart';
import 'package:folio/services/importer.dart';
import 'package:folio/services/save_bridge.dart';
import 'package:folio/state.dart';
import 'package:path/path.dart' as p;

/// Builds a zip shaped like a real release: the game nested one folder deep,
/// plus macOS junk that must be ignored.
String _makeZip(Directory tmp, {required String html, Map<String, List<int>> extra = const {}}) {
  final archive = Archive()
    ..add(ArchiveFile.string('Night_Shift_v0.2.6/index.html', html))
    ..add(ArchiveFile.string('__MACOSX/Night_Shift_v0.2.6/._index.html', 'junk'));
  extra.forEach((name, bytes) => archive.add(ArchiveFile.bytes('Night_Shift_v0.2.6/$name', bytes)));
  final path = p.join(tmp.path, 'night_shift_v0.2.6.zip');
  File(path).writeAsBytesSync(ZipEncoder().encode(archive));
  return path;
}

// Runs the injected script in node against a fake localStorage and
// sessionStorage, so the JavaScript is tested for real and not just as a
// string. [then] is the game's code after the script. [afterReload], when
// given, runs the script again on the same storage, as a page reload does,
// followed by that code.
Future<Map<String, dynamic>> runScriptFor(Directory tmp, String script, Map<String, String> before,
    {Map<String, String> session = const {}, String then = "ls.setItem('game.new', 'x');", String? afterReload}) async {
  final reload = afterReload == null
      ? ''
      : 'Storage.prototype.setItem = orig.setItem; Storage.prototype.removeItem = orig.removeItem; '
          'Storage.prototype.clear = orig.clear;\n$script\n$afterReload';
  final harness = '''
var sent = [];
function Storage(s) { this.s = s; }
Storage.prototype.getItem = function (k) { return k in this.s ? this.s[k] : null; };
Storage.prototype.setItem = function (k, v) { this.s[k] = String(v); };
Storage.prototype.removeItem = function (k) { delete this.s[k]; };
Storage.prototype.clear = function () { for (var k in this.s) delete this.s[k]; };
var orig = { setItem: Storage.prototype.setItem, removeItem: Storage.prototype.removeItem, clear: Storage.prototype.clear };
var ls = new Storage(${jsonEncode(before)}), ss = new Storage(${jsonEncode(session)});
global.Storage = Storage;
global.window = { localStorage: ls, sessionStorage: ss, addEventListener: function () {},
  flutter_inappwebview: { callHandler: function (n, op, k, v) { sent.push([op, k, v]); } } };
$script
$then
$reload
console.log(JSON.stringify({ store: ls.s, session: ss.s, sent: sent }));
''';
  final file = File(p.join(tmp.path, 'h.js'))..writeAsStringSync(harness);
  final r = await Process.run('node', [file.path]);
  expect(r.exitCode, 0, reason: '${r.stderr}');
  return jsonDecode(r.stdout as String) as Map<String, dynamic>;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('folio_test_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('importer', () {
    test('finds nested index.html, Twine story data, media and webm', () async {
      final zip = _makeZip(tmp,
          html: '<html><head><title>Night Shift v0.2.6</title></head><body>'
              '<tw-storydata name="Night Shift" ifid="ab12cd34-0000-4000-8000-000000000001" format="SugarCube" format-version="2.37.3"></tw-storydata>'
              '</body></html>',
          extra: {'videos/a.mp4': List.filled(100, 1), 'videos/b.webm': List.filled(50, 2), 'img/c.jpg': [1, 2, 3]});
      final d = await unpackAndDetect(zipPath: zip, stagingDir: p.join(tmp.path, 'stage'), originalName: 'night_shift_v0.2.6.zip');
      expect(d.title, 'Night Shift');
      expect(d.engine, 'SugarCube 2');
      expect(d.version, '0.2.6');
      expect(d.ifid, 'AB12CD34-0000-4000-8000-000000000001');
      expect(d.entryPath, 'Night_Shift_v0.2.6/index.html');
      expect(d.fileCount, 4, reason: '__MACOSX entry must not count');
      expect(d.mediaCount, 3);
      expect(d.webmCount, 1);
    });

    test('real game from this repo: First Term', () async {
      final html = File('../games/first_term/output/index.html');
      if (!html.existsSync()) return markTestSkipped('first_term not built');
      final zip = _makeZip(tmp, html: html.readAsStringSync());
      final d = await unpackAndDetect(zipPath: zip, stagingDir: p.join(tmp.path, 'stage'), originalName: 'first_term.zip');
      expect(d.title, 'First Term');
      expect(d.engine, 'SugarCube 2');
      expect(d.ifid, '83330C3F-9AB4-53E4-9750-35AFF86B9150');
    });

    test('zip without html is refused with a readable message', () async {
      final archive = Archive()..add(ArchiveFile.string('readme.txt', 'hi'));
      final path = p.join(tmp.path, 'x.zip');
      File(path).writeAsBytesSync(ZipEncoder().encode(archive));
      expect(() => unpackAndDetect(zipPath: path, stagingDir: p.join(tmp.path, 's'), originalName: 'x.zip'),
          throwsA(isA<ImportException>().having((e) => e.message, 'message', contains('No index.html'))));
    });
  });

  group('game server', () {
    late GameServer server;
    late HttpClient client;
    const port = 47990;
    setUp(() async {
      for (final id in ['g1', 'g2']) {
        final game = Directory(p.join(tmp.path, 'games', id, 'Sub'))..createSync(recursive: true);
        File(p.join(game.path, 'index.html')).writeAsStringSync('<h1>$id</h1>');
      }
      File(p.join(tmp.path, 'games', 'g1', 'Sub', 'clip.mp4')).writeAsBytesSync(List.generate(1000, (i) => i % 256));
      File(p.join(tmp.path, 'secret.txt')).writeAsStringSync('nope');
      server = GameServer(p.join(tmp.path, 'games'));
      await server.serve('g1', port);
      client = HttpClient();
    });
    tearDown(() async {
      client.close(force: true);
      await server.stop();
    });

    Future<HttpClientResponse> get(String path, {String? range, int onPort = port}) async {
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:$onPort$path'));
      if (range != null) req.headers.set(HttpHeaders.rangeHeader, range);
      return req.close();
    }

    test('serves the entry page as html with no-store', () async {
      final url = server.entryUrl('g1', 'Sub/index.html', port);
      expect(url.toString(), 'http://127.0.0.1:$port/g/g1/Sub/index.html');
      final res = await get(url.path);
      expect(res.statusCode, 200);
      expect(res.headers.contentType?.mimeType, 'text/html');
      expect(res.headers.value(HttpHeaders.cacheControlHeader), 'no-store');
      expect(await utf8.decodeStream(res), '<h1>g1</h1>');
    });

    test('each game has its own port, which serves only that game', () async {
      await server.serve('g2', port + 1);
      final other = await get('/g/g2/Sub/index.html', onPort: port + 1);
      expect(await utf8.decodeStream(other), '<h1>g2</h1>');
      final wrong = await get('/g/g2/Sub/index.html');
      expect(wrong.statusCode, 404, reason: "g1's port never serves g2");
      await wrong.drain<void>();
    });

    test('a stop then start serves the same games again, as after iOS suspends the app', () async {
      await server.stop();
      await server.start();
      final res = await get('/g/g1/Sub/index.html');
      expect(res.statusCode, 200);
      await res.drain<void>();
    });

    test('answers byte ranges, which iOS needs to play video', () async {
      final res = await get('/g/g1/Sub/clip.mp4', range: 'bytes=10-19');
      expect(res.statusCode, 206);
      expect(res.headers.value(HttpHeaders.contentRangeHeader), 'bytes 10-19/1000');
      final body = await res.fold<List<int>>([], (a, b) => a..addAll(b));
      expect(body, List.generate(10, (i) => i + 10));
      final open = await get('/g/g1/Sub/clip.mp4', range: 'bytes=990-');
      expect(open.headers.value(HttpHeaders.contentRangeHeader), 'bytes 990-999/1000');
      await open.drain<void>();
    });

    test('matches file names case-insensitively, like Windows-made zips expect', () async {
      final res = await get('/g/g1/sub/CLIP.MP4');
      expect(res.statusCode, 200);
      await res.drain<void>();
    });

    test('never serves outside the game folder', () async {
      final res = await get('/g/g1/..%2F..%2Fsecret.txt');
      expect(res.statusCode, anyOf(403, 404));
      await res.drain<void>();
    });
  });

  group('library ports', () {
    Game game(String id, int port) => Game(id: id, title: id, version: '', engine: 'HTML5', entryPath: 'index.html', sizeBytes: 0, fileCount: 1, mediaCount: 0, webmCount: 0, coverIndex: 0, addedAt: DateTime(2026), port: port);

    test('ports are handed out once and never reused', () async {
      final store = LibraryStore(AppPaths.at(tmp.path));
      final a = await store.claimPort();
      final b = await store.claimPort();
      expect(a, LibraryStore.firstPort);
      expect(b, a + 1);
      // Deleting the newest game does not give its port back.
      expect(await store.claimPort(atLeast: nextFreePort([game('x', a)])), b + 1);
    });

    test('games from before per-game ports get one each on load, kept after', () async {
      final store = LibraryStore(AppPaths.at(tmp.path));
      await store.save([game('old1', 0), game('old2', 0)]);
      final loaded = await store.load();
      expect(loaded.map((g) => g.port).toSet(), hasLength(2));
      expect(loaded.every((g) => g.port >= LibraryStore.firstPort), isTrue);
      expect((await store.load()).map((g) => g.port), loaded.map((g) => g.port));
    });
  });

  group('save store', () {
    late SaveStore saves;
    setUp(() => saves = SaveStore(AppPaths.at(tmp.path)));

    Future<Map<String, dynamic>> runScript(String script, Map<String, String> before,
            {Map<String, String> session = const {}, String then = "ls.setItem('game.new', 'x');", String? afterReload}) =>
        runScriptFor(tmp, script, before, session: session, then: then, afterReload: afterReload);

    test("the game's own saves are left to the game: localStorage writes are never reported", () async {
      final hasNode = (await Process.run('which', ['node'])).exitCode == 0;
      if (!hasNode) return markTestSkipped('node not installed');
      final out = await runScript(await saves.injectionScript('g1'), {'game.saves': 'slot1'});
      expect(out['store'], {'game.saves': 'slot1', 'game.new': 'x'});
      expect(out['sent'], isEmpty);
    });

    test('saves an earlier build kept move to the new origin once, never over newer ones', () async {
      final hasNode = (await Process.run('which', ['node'])).exitCode == 0;
      if (!hasNode) return markTestSkipped('node not installed');
      final dir = Directory(AppPaths.at(tmp.path).savesDir('g1'))..createSync(recursive: true);
      File(p.join(dir.path, 'current.json')).writeAsStringSync(jsonEncode({'RPG File1': 'old', 'RPG Global': 'g'}));
      final script = await saves.injectionScript('g1');
      final out = await runScript(script, {'RPG Global': 'newer'}, then: "ls.removeItem('RPG File1');", afterReload: '');
      // Seeded on the first load; the game deleting a slot later sticks.
      expect(out['store'], {'RPG Global': 'newer', '__folio_seeded': '1'});
      expect(out['sent'], isEmpty);
    });

    test('where the player is goes to session.json', () async {
      await saves.onStorageEvent('g1', 'session-set', 'game.state', 'passage 12');
      await saves.flushAll();
      final file = File(p.join(AppPaths.at(tmp.path).savesDir('g1'), 'session.json'));
      expect(jsonDecode(file.readAsStringSync()), {'game.state': 'passage 12'});

      // A fresh store (the app was killed) reads it back from disk.
      expect(await SaveStore(AppPaths.at(tmp.path)).session('g1'), {'game.state': 'passage 12'});

      await saves.clearSession('g1');
      expect(await saves.session('g1'), isEmpty);
      expect(file.existsSync(), isFalse);
    });

    test('a new WebView resumes where the player was, and session writes mirror', () async {
      final hasNode = (await Process.run('which', ['node'])).exitCode == 0;
      if (!hasNode) return markTestSkipped('node not installed');
      await saves.onStorageEvent('g1', 'session-set', 'game.state', 'passage 12');
      final out = await runScript(await saves.injectionScript('g1'), {}, then: "ss.setItem('game.state', 'passage 13');");
      expect(out['session'], {'game.state': 'passage 13', '__folio_resumed': '1'});
      // The marker is Folio's own and is never mirrored.
      expect(out['sent'], [
        ['session-set', 'game.state', 'passage 13']
      ]);
    });

    test("the game's own Restart is not undone by the resume", () async {
      final hasNode = (await Process.run('which', ['node'])).exitCode == 0;
      if (!hasNode) return markTestSkipped('node not installed');
      await saves.onStorageEvent('g1', 'session-set', 'game.state', 'passage 12');
      // SugarCube's Restart deletes its moment and reloads the page.
      final out = await runScript(await saves.injectionScript('g1'), {},
          then: "ss.removeItem('game.state');", afterReload: '');
      expect(out['session'], {'__folio_resumed': '1'});
      expect(out['sent'], [
        ['session-remove', 'game.state', null]
      ]);
    });
  });

  test('only SugarCube games that were played before resume', () {
    Game game(String engine, {DateTime? played}) => Game(id: 'g1', title: 'T', version: '1', engine: engine, entryPath: 'index.html', sizeBytes: 0, fileCount: 1, mediaCount: 0, webmCount: 0, coverIndex: 0, addedAt: DateTime(2026), lastPlayedAt: played);
    expect(canResume(game('SugarCube 2', played: DateTime(2026))), isTrue);
    expect(canResume(game('SugarCube 2')), isFalse);
    expect(canResume(game('HTML5', played: DateTime(2026))), isFalse);
  });

  group('moments', () {
    late SaveStore saves;
    setUp(() => saves = SaveStore(AppPaths.at(tmp.path)));

    test('nothing to save before the game has written its state', () async {
      expect(await saves.saveMoment('g1', gameVersion: '1'), isNull);
    });

    test('a moment keeps where the player is, with its screenshot, newest first', () async {
      await saves.onStorageEvent('g1', 'session-set', 'game.state', 'A');
      final a = await saves.saveMoment('g1', gameVersion: '0.2.4', thumbnail: [1, 2, 3], now: DateTime(2026, 10, 30, 10));
      await saves.onStorageEvent('g1', 'session-set', 'game.state', 'B');
      await saves.saveMoment('g1', gameVersion: '0.2.5', now: DateTime(2026, 10, 30, 11));
      final list = await saves.moments('g1');
      expect(list.map((m) => m.gameVersion), ['0.2.5', '0.2.4']);
      expect(File(list.last.thumbPath!).readAsBytesSync(), [1, 2, 3]);
      expect(list.first.thumbPath, isNull);
      await saves.deleteMoment('g1', a!.id);
      expect(await saves.moments('g1'), hasLength(1));
    });

    test('keeps at most 30 moments', () async {
      await saves.onStorageEvent('g1', 'session-set', 'game.state', 'A');
      for (var i = 0; i < SaveStore.maxMoments + 3; i++) {
        await saves.saveMoment('g1', gameVersion: '1', now: DateTime(2026, 1, 1).add(Duration(minutes: i)));
      }
      final list = await saves.moments('g1');
      expect(list, hasLength(SaveStore.maxMoments));
      expect(list.last.createdAt, DateTime(2026, 1, 1).add(const Duration(minutes: 3)));
    });

    test('going back changes where the player is, and the old page cannot undo it', () async {
      await saves.onStorageEvent('g1', 'session-set', 'game.state', 'A');
      final a = await saves.saveMoment('g1', gameVersion: '1');
      await saves.onStorageEvent('g1', 'session-set', 'game.state', 'B');

      final reloads = <String>[];
      final sub = saves.restoredEvents.listen(reloads.add);
      await saves.jumpToMoment('g1', a!.id);
      await Future<void>.delayed(Duration.zero);
      expect(reloads, ['g1'], reason: 'the running player is told to reload');
      expect(await saves.session('g1'), {'game.state': 'A'});

      // The old page is still running and writes its moment back.
      await saves.onStorageEvent('g1', 'session-set', 'game.state', 'B');
      expect(await saves.session('g1'), {'game.state': 'A'});
      await saves.onStorageEvent('g1', 'restored', null, null);
      await saves.onStorageEvent('g1', 'session-set', 'game.state', 'A2');
      expect(await saves.session('g1'), {'game.state': 'A2'});
      await sub.cancel();
    });

    test('the reloaded page takes the moment even though its sessionStorage survived the reload', () async {
      final hasNode = (await Process.run('which', ['node'])).exitCode == 0;
      if (!hasNode) return markTestSkipped('node not installed');
      await saves.onStorageEvent('g1', 'session-set', 'game.state', 'A');
      final a = await saves.saveMoment('g1', gameVersion: '1');
      await saves.jumpToMoment('g1', a!.id);
      final out = await runScriptFor(tmp, await saves.injectionScript('g1'), {'game.saves': 'slot1'},
          session: {'game.state': 'B', 'game.extra': 'x', '__folio_resumed': '1'});
      expect(out['session'], {'game.state': 'A', '__folio_resumed': '1'});
      expect(out['store'], {'game.saves': 'slot1', 'game.new': 'x'}, reason: 'saves untouched');
      expect(out['sent'], [
        ['restored', null, null]
      ]);
    });
  });
}
