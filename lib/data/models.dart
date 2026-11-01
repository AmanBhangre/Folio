// Plain data for the library. Persisted as JSON by [LibraryStore]; kept free
// of Flutter imports so the importer isolate can build them.

enum GameOrientation { auto, portrait, landscape }

class GameOptions {
  const GameOptions({
    this.orientation = GameOrientation.auto,
    this.fullScreen = true,
    this.keepAwake = false,
    this.inlineVideo = true,
    this.desktopLayout = false,
    this.textScale = 100,
  });

  final GameOrientation orientation;
  final bool fullScreen;
  final bool keepAwake;
  final bool inlineVideo;
  final bool desktopLayout;

  /// Percent, 80 to 150.
  final int textScale;

  GameOptions copyWith({GameOrientation? orientation, bool? fullScreen, bool? keepAwake, bool? inlineVideo, bool? desktopLayout, int? textScale}) =>
      GameOptions(
        orientation: orientation ?? this.orientation,
        fullScreen: fullScreen ?? this.fullScreen,
        keepAwake: keepAwake ?? this.keepAwake,
        inlineVideo: inlineVideo ?? this.inlineVideo,
        desktopLayout: desktopLayout ?? this.desktopLayout,
        textScale: textScale ?? this.textScale,
      );

  Map<String, Object?> toJson() => {
        'orientation': orientation.name,
        'fullScreen': fullScreen,
        'keepAwake': keepAwake,
        'inlineVideo': inlineVideo,
        'desktopLayout': desktopLayout,
        'textScale': textScale,
      };

  factory GameOptions.fromJson(Map<String, Object?> j) => GameOptions(
        orientation: GameOrientation.values.asNameMap()[j['orientation']] ?? GameOrientation.auto,
        fullScreen: j['fullScreen'] as bool? ?? true,
        keepAwake: j['keepAwake'] as bool? ?? false,
        inlineVideo: j['inlineVideo'] as bool? ?? true,
        desktopLayout: j['desktopLayout'] as bool? ?? false,
        textScale: (j['textScale'] as num?)?.toInt() ?? 100,
      );
}

class Game {
  const Game({
    required this.id,
    required this.title,
    required this.version,
    required this.engine,
    required this.entryPath,
    required this.sizeBytes,
    required this.fileCount,
    required this.mediaCount,
    required this.webmCount,
    required this.coverIndex,
    required this.addedAt,
    this.ifid,
    this.lastPlayedAt,
    this.isNew = true,
    this.updated = false,
    this.options = const GameOptions(),
    this.port = 0,
  });

  /// Folder name under games/ and the path segment the local server uses.
  final String id;

  /// The local port the game is served on. Browser storage belongs to an
  /// origin, so a port of its own gives each game storage of its own. It
  /// never changes for the game's life; 0 means not yet given one.
  final int port;
  final String title;

  /// Empty when the game does not state one.
  final String version;
  final String engine;

  /// Twine's story id. Same game, same IFID on every device, whatever the zip
  /// was called, so cloud sync keys saves on it.
  final String? ifid;

  /// index.html relative to the game folder (games can nest it in a subfolder).
  final String entryPath;
  final int sizeBytes;
  final int fileCount;
  final int mediaCount;
  final int webmCount;
  final int coverIndex;
  final DateTime addedAt;
  final DateTime? lastPlayedAt;
  final bool isNew;
  final bool updated;
  final GameOptions options;

  Game copyWith({
    String? title,
    String? version,
    String? engine,
    String? ifid,
    String? entryPath,
    int? sizeBytes,
    int? fileCount,
    int? mediaCount,
    int? webmCount,
    DateTime? lastPlayedAt,
    bool? isNew,
    bool? updated,
    GameOptions? options,
    int? port,
  }) =>
      Game(
        id: id,
        title: title ?? this.title,
        version: version ?? this.version,
        engine: engine ?? this.engine,
        ifid: ifid ?? this.ifid,
        entryPath: entryPath ?? this.entryPath,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        fileCount: fileCount ?? this.fileCount,
        mediaCount: mediaCount ?? this.mediaCount,
        webmCount: webmCount ?? this.webmCount,
        coverIndex: coverIndex,
        addedAt: addedAt,
        lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
        isNew: isNew ?? this.isNew,
        updated: updated ?? this.updated,
        options: options ?? this.options,
        port: port ?? this.port,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'version': version,
        'engine': engine,
        'ifid': ifid,
        'entryPath': entryPath,
        'sizeBytes': sizeBytes,
        'fileCount': fileCount,
        'mediaCount': mediaCount,
        'webmCount': webmCount,
        'coverIndex': coverIndex,
        'addedAt': addedAt.toIso8601String(),
        'lastPlayedAt': lastPlayedAt?.toIso8601String(),
        'isNew': isNew,
        'updated': updated,
        'options': options.toJson(),
        'port': port,
      };

  factory Game.fromJson(Map<String, Object?> j) => Game(
        id: j['id'] as String,
        title: j['title'] as String,
        version: j['version'] as String? ?? '',
        engine: j['engine'] as String? ?? 'HTML5',
        ifid: j['ifid'] as String?,
        entryPath: j['entryPath'] as String,
        sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
        fileCount: (j['fileCount'] as num?)?.toInt() ?? 0,
        mediaCount: (j['mediaCount'] as num?)?.toInt() ?? 0,
        webmCount: (j['webmCount'] as num?)?.toInt() ?? 0,
        coverIndex: (j['coverIndex'] as num?)?.toInt() ?? 0,
        addedAt: DateTime.parse(j['addedAt'] as String),
        lastPlayedAt: j['lastPlayedAt'] == null ? null : DateTime.parse(j['lastPlayedAt'] as String),
        isNew: j['isNew'] as bool? ?? false,
        updated: j['updated'] as bool? ?? false,
        options: GameOptions.fromJson((j['options'] as Map?)?.cast<String, Object?>() ?? const {}),
        port: (j['port'] as num?)?.toInt() ?? 0,
      );
}

/// A spot in a game the player chose to come back to. It holds where the
/// player was (the game's sessionStorage), never the game's own saves.
class Moment {
  const Moment({required this.id, required this.createdAt, required this.gameVersion, this.thumbPath});

  /// File stem under saves/moments/.
  final String id;
  final DateTime createdAt;

  /// The game version it was made in. A moment from an older version may not
  /// load in a newer one.
  final String gameVersion;

  /// Screenshot of the game at that moment, if one could be taken.
  final String? thumbPath;
}

/// What the importer found inside a zip, shown on the review step.
class ImportDetection {
  const ImportDetection({
    required this.title,
    required this.engine,
    required this.version,
    required this.ifid,
    required this.entryPath,
    required this.fileCount,
    required this.mediaCount,
    required this.webmCount,
    required this.sizeBytes,
    required this.stagingDir,
  });

  final String title, engine, version, entryPath;
  final String? ifid;
  final int fileCount, mediaCount, webmCount, sizeBytes;

  /// Where the zip was unpacked; moved into games/ on confirm, deleted on cancel.
  final String stagingDir;
}
