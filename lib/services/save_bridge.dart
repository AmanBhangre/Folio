import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../data/library_store.dart';
import '../data/models.dart';

/// Keeps where the player is in a game (Resume) and the moments they save.
///
/// The game's own saves are not copied: the game keeps them in its browser
/// storage, which is its own because each game has its own port (see
/// GameServer). What Folio keeps is the game's sessionStorage, which
/// SugarCube reads back on load but the WebView loses whenever the player
/// screen or the app closes. A script injected before the game's own code
/// reports every sessionStorage write to Flutter, and puts it back on launch.
class SaveStore {
  SaveStore(this.paths);
  final AppPaths paths;

  /// Games jumped to a moment but not yet reloaded. The page that was
  /// running keeps writing its old state, which would land on top of the
  /// moment, so its writes are dropped until the reloaded page reports
  /// 'restored' (see [injectionScript]).
  final _awaitingReload = <String>{};
  final _restored = StreamController<String>.broadcast();

  /// Emits a game id after a jump to a moment, so a running player can
  /// reload the game at that moment.
  Stream<String> get restoredEvents => _restored.stream;

  /// Earlier builds served every game on one shared port and kept a copy of
  /// each game's localStorage in this file. The script hands that copy to
  /// the game's own origin once; Folio never writes it again.
  String _legacyFile(String id) => p.join(paths.savesDir(id), 'current.json');

  Future<Map<String, String>> _legacySaves(String gameId) async {
    final f = File(_legacyFile(gameId));
    if (!await f.exists()) return const {};
    try {
      return (jsonDecode(await f.readAsString()) as Map).cast<String, String>();
    } on FormatException {
      return const {};
    }
  }

  /// The game's sessionStorage: where the player is right now, saved or not.
  /// SugarCube keeps its current moment there and reads it back on load, but
  /// the WebView loses it whenever the app or the player screen closes.
  final _session = <String, Map<String, String>>{};
  final _sessionDirty = <String, Timer>{};

  String _sessionFile(String id) => p.join(paths.savesDir(id), 'session.json');

  Future<Map<String, String>> session(String gameId) async {
    final cached = _session[gameId];
    if (cached != null) return cached;
    final f = File(_sessionFile(gameId));
    final map = <String, String>{};
    if (await f.exists()) {
      try {
        map.addAll((jsonDecode(await f.readAsString()) as Map).cast<String, String>());
      } on FormatException {
        // Torn write: the game starts from its title screen, saves are untouched.
      }
    }
    return _session[gameId] = map;
  }

  /// Forgets where the player was, so the game next opens at its start. Used
  /// when the game's files change: an old moment can break a new version,
  /// while saves go through the game's own save migration.
  Future<void> clearSession(String gameId) async {
    _sessionDirty.remove(gameId)?.cancel();
    _session[gameId] = {};
    final f = File(_sessionFile(gameId));
    if (await f.exists()) await f.delete();
  }

  /// Called from the WebView for every sessionStorage write while [gameId]
  /// runs. Ops arrive as 'session-set', 'session-remove', 'session-clear'.
  Future<void> onStorageEvent(String gameId, String op, String? key, String? value) async {
    if (op == 'restored') {
      _awaitingReload.remove(gameId);
      return;
    }
    if (_awaitingReload.contains(gameId)) return;
    if (op.startsWith('session-')) return _onSessionEvent(gameId, op.substring('session-'.length), key, value);
  }

  Future<void> _onSessionEvent(String gameId, String op, String? key, String? value) async {
    final map = await session(gameId);
    switch (op) {
      case 'set':
        if (key == null || value == null || map[key] == value) return;
        map[key] = value;
      case 'remove':
        if (key == null || map.remove(key) == null) return;
      case 'clear':
        if (map.isEmpty) return;
        map.clear();
      default:
        return;
    }
    _sessionDirty[gameId]?.cancel();
    _sessionDirty[gameId] = Timer(const Duration(milliseconds: 600), () => _flushSession(gameId));
  }

  Future<void> _flushSession(String gameId) async {
    _sessionDirty.remove(gameId)?.cancel();
    final map = _session[gameId];
    if (map == null) return;
    await Directory(paths.savesDir(gameId)).create(recursive: true);
    final tmp = File('${_sessionFile(gameId)}.tmp');
    await tmp.writeAsString(jsonEncode(map));
    await tmp.rename(_sessionFile(gameId));
  }

  /// Flush pending writes; called when the player leaves a game and when the
  /// app goes to the background.
  Future<void> flushAll() async {
    for (final id in _sessionDirty.keys.toList()) {
      await _flushSession(id);
    }
  }

  // ---------------------------------------------------------------- moments

  static const maxMoments = 30;

  String _momentDir(String id) => p.join(paths.savesDir(id), 'moments');

  /// Games whose next page load must take its sessionStorage from a moment,
  /// even though the WebView still has the old one (a reload keeps it).
  final _pendingSessionForce = <String>{};

  /// Keeps where the player is now as a moment. Returns null when the game
  /// has not written any session state yet, so there is nothing to go back to.
  Future<Moment?> saveMoment(String gameId, {required String gameVersion, List<int>? thumbnail, DateTime? now}) async {
    final state = await session(gameId);
    if (state.isEmpty) return null;
    final at = now ?? DateTime.now();
    final dir = Directory(_momentDir(gameId));
    await dir.create(recursive: true);
    final id = '${at.millisecondsSinceEpoch}';
    await _writeMoment(gameId, id, at, gameVersion, state);
    String? thumbPath;
    if (thumbnail != null && thumbnail.isNotEmpty) {
      thumbPath = p.join(dir.path, '$id.jpg');
      await File(thumbPath).writeAsBytes(thumbnail);
    }
    for (final old in (await moments(gameId)).skip(maxMoments)) {
      await deleteMoment(gameId, old.id);
    }
    return Moment(id: id, createdAt: at, gameVersion: gameVersion, thumbPath: thumbPath);
  }

  Future<void> _writeMoment(String gameId, String id, DateTime at, String gameVersion, Map<String, String> state) =>
      File(p.join(_momentDir(gameId), '$id.json')).writeAsString(jsonEncode({
        'createdAt': at.toIso8601String(),
        'gameVersion': gameVersion,
        'session': state,
      }));

  /// Newest first.
  Future<List<Moment>> moments(String gameId) async {
    final dir = Directory(_momentDir(gameId));
    if (!await dir.exists()) return [];
    final out = <Moment>[];
    await for (final f in dir.list()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      final id = p.basenameWithoutExtension(f.path);
      try {
        final j = jsonDecode(await f.readAsString()) as Map;
        final thumb = File(p.join(dir.path, '$id.jpg'));
        out.add(Moment(
          id: id,
          createdAt: DateTime.parse(j['createdAt'] as String),
          gameVersion: j['gameVersion'] as String? ?? '',
          thumbPath: await thumb.exists() ? thumb.path : null,
        ));
      } on Object {
        // A torn or foreign file is not a moment.
      }
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  Future<void> deleteMoment(String gameId, String momentId) async {
    for (final ext in ['json', 'jpg']) {
      final f = File(p.join(_momentDir(gameId), '$momentId.$ext'));
      if (await f.exists()) await f.delete();
    }
  }

  /// Takes the game back to [momentId]. Only where the player is changes;
  /// the game's own saves are untouched. A running player reloads at once
  /// (see [restoredEvents]); the old page's writes are dropped until the
  /// reloaded page reports 'restored'.
  Future<void> jumpToMoment(String gameId, String momentId) async {
    final j = jsonDecode(await File(p.join(_momentDir(gameId), '$momentId.json')).readAsString()) as Map;
    _sessionDirty.remove(gameId)?.cancel();
    _session[gameId] = (j['session'] as Map).cast<String, String>();
    _pendingSessionForce.add(gameId);
    _awaitingReload.add(gameId);
    await _flushSession(gameId);
    _restored.add(gameId);
  }

  /// Forgets everything Folio kept for the game. Its browser storage is
  /// left behind on its port, which no other game is ever given.
  Future<void> deleteAll(String gameId) async {
    _session.remove(gameId);
    _sessionDirty.remove(gameId)?.cancel();
    final d = Directory(paths.savesDir(gameId));
    if (await d.exists()) await d.delete(recursive: true);
  }

  /// Script run at document start, before any game code.
  ///
  /// It puts back the game's sessionStorage (where the player was), once per
  /// WebView: a marker in sessionStorage stops it running again on a reload,
  /// so the game's own Restart, which deletes its moment and reloads, still
  /// starts over. After a jump to a moment it replaces sessionStorage
  /// whatever the marker says, and reports 'restored' before any game write.
  ///
  /// localStorage is the game's own and is never reported or changed, except
  /// once: saves an earlier build kept are given to the game's new origin,
  /// filling only keys it does not have.
  Future<String> injectionScript(String gameId) async {
    final legacy = await _legacySaves(gameId);
    final sessionData = await session(gameId);
    final sessionForce = _pendingSessionForce.remove(gameId);
    return '''
(function () {
  var LEGACY = ${jsonEncode(legacy)};
  var SESSION = ${jsonEncode(sessionData)};
  var SESSION_FORCE = ${sessionForce ? 'true' : 'false'};
  var MARK = '__folio_resumed', SEEDED = '__folio_seeded';
  var ls = null, ss = null;
  try { ls = window.localStorage || null; } catch (e) {}
  try { ss = window.sessionStorage || null; } catch (e) {}
  if (!ss) return;
  var proto = Storage.prototype, set = proto.setItem, rem = proto.removeItem, clr = proto.clear;
  try {
    if (ls && Object.keys(LEGACY).length && ls.getItem(SEEDED) === null) {
      for (var key in LEGACY) { if (ls.getItem(key) === null) set.call(ls, key, LEGACY[key]); }
      set.call(ls, SEEDED, '1');
    }
  } catch (e) {}
  try {
    if (SESSION_FORCE) {
      clr.call(ss);
      for (var fk in SESSION) set.call(ss, fk, SESSION[fk]);
      set.call(ss, MARK, '1');
    } else if (ss.getItem(MARK) === null) {
      for (var sk in SESSION) { if (ss.getItem(sk) === null) set.call(ss, sk, SESSION[sk]); }
      set.call(ss, MARK, '1');
    }
  } catch (e) {}
  var queue = [];
  function send(op, k, v) {
    var b = window.flutter_inappwebview;
    if (b && b.callHandler) { b.callHandler('folioStorage', op, k, v); return; }
    queue.push([op, k, v]);
  }
  window.addEventListener('flutterInAppWebViewPlatformReady', function () {
    var q = queue; queue = [];
    q.forEach(function (a) { window.flutter_inappwebview.callHandler('folioStorage', a[0], a[1], a[2]); });
  });
  if (SESSION_FORCE) send('restored', null, null);
  proto.setItem = function (k, v) {
    set.call(this, k, v);
    if (this === ss && k !== MARK) send('session-set', String(k), String(v));
  };
  proto.removeItem = function (k) {
    rem.call(this, k);
    if (this === ss && k !== MARK) send('session-remove', String(k), null);
  };
  proto.clear = function () {
    clr.call(this);
    if (this === ss) { set.call(ss, MARK, '1'); send('session-clear', null, null); }
  };
})();
''';
  }
}
