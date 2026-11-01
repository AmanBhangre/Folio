import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models.dart';

/// Supabase-backed save sync. Schema: supabase/migrations/0001_init.sql.
///
/// Configured at build time, so no key is ever committed:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
/// Without both, [available] is false and the app runs fully offline.
///
/// Not wired into the UI yet: sign-in screen, RevenueCat purchase and the
/// background upload loop are the next step. The calls below are the pieces
/// that loop will use.
class CloudSync {
  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get available => _url.isNotEmpty && _publishableKey.isNotEmpty;

  static Future<void> init() async {
    if (!available) return;
    await Supabase.initialize(url: _url, publishableKey: _publishableKey);
  }

  static SupabaseClient get _db => Supabase.instance.client;

  /// IFID when the game has one, else a hash of its title, so the same game
  /// matches on every device.
  static String gameKey(Game g) => g.ifid ?? 'title:${sha1.convert(utf8.encode(g.title.trim().toLowerCase()))}';

  /// Uploads a game's full save state if it changed since the last upload.
  static Future<void> pushSaves(Game game, Map<String, String> storage, {String? deviceId}) async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    final key = gameKey(game);
    final body = utf8.encode(jsonEncode(storage));
    final hash = sha256.convert(body).toString();

    final existing = await _db.from('saves').select('sha256').eq('user_id', user.id).eq('game_key', key).maybeSingle();
    if (existing != null && existing['sha256'] == hash) return;

    final path = '${user.id}/${Uri.encodeComponent(key)}.json';
    await _db.storage.from('saves').uploadBinary(path, body, fileOptions: const FileOptions(upsert: true, contentType: 'application/json'));
    await _db.from('games').upsert({'user_id': user.id, 'game_key': key, 'title': game.title, 'version': game.version});
    await _db.from('saves').upsert({
      'user_id': user.id,
      'game_key': key,
      'storage_path': path,
      'size_bytes': body.length,
      'sha256': hash,
      'device_id': deviceId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// The cloud copy and when it was written, or null if there is none.
  static Future<(Map<String, String>, DateTime)?> pullSaves(Game game) async {
    final user = _db.auth.currentUser;
    if (user == null) return null;
    final row = await _db.from('saves').select('storage_path, updated_at').eq('user_id', user.id).eq('game_key', gameKey(game)).maybeSingle();
    if (row == null) return null;
    final bytes = await _db.storage.from('saves').download(row['storage_path'] as String);
    final data = (jsonDecode(utf8.decode(bytes)) as Map).cast<String, String>();
    return (data, DateTime.parse(row['updated_at'] as String));
  }
}
