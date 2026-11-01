import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Serves unpacked games over http://127.0.0.1 so they run like a website.
///
/// Why a server and not file://: browser storage (where games keep their
/// saves) is tied to the page's origin. file:// origins are treated
/// inconsistently by WebViews, and some block storage outright.
///
/// Each game is served on its own port (see [Game.port]), so each game is
/// its own origin with its own localStorage and IndexedDB. Games cannot read
/// or overwrite each other's saves, even when they use the same key names,
/// as every RPG Maker MV game does. A port only ever serves its own game.
class GameServer {
  GameServer(this.gamesDir);

  final String gamesDir;
  final _servers = <int, HttpServer>{};

  /// Every port served since launch and its game, kept across [stop] so
  /// [start] can bring them back after iOS suspends the sockets.
  final _games = <int, String>{};

  /// URL the WebView opens for a game.
  Uri entryUrl(String gameId, String entryPath, int port) =>
      Uri(scheme: 'http', host: '127.0.0.1', port: port, pathSegments: ['g', gameId, ...entryPath.split('/')]);

  /// Starts serving [gameId] on [port] unless it already is. Throws a
  /// [SocketException] if another app holds the port.
  Future<void> serve(String gameId, int port) async {
    _games[port] = gameId;
    if (_servers.containsKey(port)) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    server.autoCompress = false;
    server.listen((req) => _handle(req, gameId), onError: (_) {});
    _servers[port] = server;
  }

  /// Serves again every game served before [stop].
  Future<void> start() async {
    for (final e in _games.entries.toList()) {
      try {
        await serve(e.value, e.key);
      } on SocketException {
        // The player reports it when that game is opened.
      }
    }
  }

  Future<void> stop() async {
    final all = _servers.values.toList();
    _servers.clear();
    for (final s in all) {
      await s.close(force: true);
    }
  }

  Future<void> _handle(HttpRequest req, String gameId) async {
    final res = req.response;
    try {
      if (req.method != 'GET' && req.method != 'HEAD') {
        res.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      final segs = req.uri.pathSegments;
      if (segs.length < 3 || segs.first != 'g' || segs[1] != gameId) {
        res.statusCode = HttpStatus.notFound;
        return;
      }
      final root = p.normalize(p.join(gamesDir, segs[1]));
      final path = p.normalize(p.joinAll([root, ...segs.skip(2)]));
      // Never serve outside the game's own folder (no ../ escapes).
      if (!p.isWithin(root, path)) {
        res.statusCode = HttpStatus.forbidden;
        return;
      }
      var file = File(path);
      if (!await file.exists()) {
        // Windows-made zips often differ in case from what the HTML asks for.
        file = await _caseInsensitive(root, segs.skip(2).toList()) ?? file;
        if (!await file.exists()) {
          res.statusCode = HttpStatus.notFound;
          return;
        }
      }
      await _sendFile(req, res, file);
    } catch (_) {
      res.statusCode = HttpStatus.internalServerError;
    } finally {
      await res.close().catchError((_) {});
    }
  }

  /// Video needs byte ranges: iOS refuses to play an mp4 that is served
  /// without them, and seeking needs them everywhere.
  Future<void> _sendFile(HttpRequest req, HttpResponse res, File file) async {
    final length = await file.length();
    final type = _mime[p.extension(file.path).toLowerCase()] ?? 'application/octet-stream';
    res.headers
      ..set(HttpHeaders.contentTypeHeader, type)
      ..set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..set(HttpHeaders.cacheControlHeader, type.startsWith('text/html') ? 'no-store' : 'max-age=3600');

    final range = req.headers.value(HttpHeaders.rangeHeader);
    final m = range == null ? null : RegExp(r'bytes=(\d*)-(\d*)').firstMatch(range);
    if (m != null && length > 0) {
      var start = int.tryParse(m.group(1)!) ;
      var end = int.tryParse(m.group(2)!);
      if (start == null && end != null) {
        start = length - end; // suffix range: last N bytes
        end = length - 1;
      }
      start ??= 0;
      end = (end == null || end >= length) ? length - 1 : end;
      if (start > end || start >= length) {
        res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$length');
        return;
      }
      res.statusCode = HttpStatus.partialContent;
      res.headers
        ..set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$length')
        ..contentLength = end - start + 1;
      if (req.method == 'GET') await res.addStream(file.openRead(start, end + 1));
      return;
    }
    res.contentLength = length;
    if (req.method == 'GET') await res.addStream(file.openRead());
  }

  Future<File?> _caseInsensitive(String root, List<String> segs) async {
    var dir = Directory(root);
    for (var i = 0; i < segs.length; i++) {
      final want = segs[i].toLowerCase();
      FileSystemEntity? hit;
      await for (final e in dir.list(followLinks: false)) {
        if (p.basename(e.path).toLowerCase() == want) {
          hit = e;
          break;
        }
      }
      if (hit == null) return null;
      if (i == segs.length - 1) return hit is File ? hit : null;
      if (hit is! Directory) return null;
      dir = hit;
    }
    return null;
  }

  static const _mime = <String, String>{
    '.html': 'text/html; charset=utf-8',
    '.htm': 'text/html; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.mjs': 'text/javascript; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.json': 'application/json',
    '.txt': 'text/plain; charset=utf-8',
    '.xml': 'application/xml',
    '.svg': 'image/svg+xml',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.avif': 'image/avif',
    '.ico': 'image/x-icon',
    '.mp4': 'video/mp4',
    '.m4v': 'video/mp4',
    '.mov': 'video/quicktime',
    '.webm': 'video/webm',
    '.mp3': 'audio/mpeg',
    '.m4a': 'audio/mp4',
    '.ogg': 'audio/ogg',
    '.opus': 'audio/ogg',
    '.wav': 'audio/wav',
    '.woff': 'font/woff',
    '.woff2': 'font/woff2',
    '.ttf': 'font/ttf',
    '.otf': 'font/otf',
    '.wasm': 'application/wasm',
  };
}
