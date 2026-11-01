import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../data/models.dart';

class ImportException implements Exception {
  ImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

final _media = RegExp(r'\.(png|jpe?g|gif|webp|avif|svg|mp4|webm|m4v|mov|ogg|mp3|wav|m4a|opus)$', caseSensitive: false);

/// Unpacks a game zip into [stagingDir] and reports what it found.
///
/// Runs in a background isolate: a 230 MB game must not freeze the UI.
/// The zip is streamed from disk, never loaded into memory whole.
Future<ImportDetection> unpackAndDetect({required String zipPath, required String stagingDir, required String originalName}) {
  return Isolate.run(() => _unpackSync(zipPath, stagingDir, originalName));
}

Future<ImportDetection> _unpackSync(String zipPath, String stagingDir, String originalName) async {
  // extractFileToDisk picks the decoder from the extension, so a picker copy
  // without one is renamed first.
  var src = zipPath;
  if (p.extension(src).toLowerCase() != '.zip') {
    src = '$stagingDir.zip';
    await File(zipPath).copy(src);
  }
  try {
    await extractFileToDisk(src, stagingDir);
  } on Object catch (e) {
    throw ImportException('This file could not be unpacked. Is it a .zip? ($e)');
  } finally {
    if (src != zipPath && File(src).existsSync()) File(src).deleteSync();
  }

  final files = Directory(stagingDir)
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((f) => !p.split(p.relative(f.path, from: stagingDir)).any((s) => s == '__MACOSX' || s.startsWith('.')))
      .toList();

  int depth(File f) => p.split(p.relative(f.path, from: stagingDir)).length;
  final indexes = files.where((f) => RegExp(r'^index\.html?$', caseSensitive: false).hasMatch(p.basename(f.path))).toList()
    ..sort((a, b) => depth(a).compareTo(depth(b)));
  final anyHtml = files.where((f) => RegExp(r'\.html?$', caseSensitive: false).hasMatch(f.path)).toList()
    ..sort((a, b) => depth(a).compareTo(depth(b)));
  final entry = indexes.isNotEmpty ? indexes.first : (anyHtml.isNotEmpty ? anyHtml.first : null);
  if (entry == null) {
    throw ImportException('No index.html in this zip. Pick the zip the game was shipped in, or a folder that has index.html at its top.');
  }

  // Only the head of the file is needed for the title and story data, and a
  // SugarCube build can be several MB of inlined passages.
  final head = await _readHead(entry, 2 * 1024 * 1024);
  final storyData = RegExp(r'<tw-storydata([^>]*)>', caseSensitive: false).firstMatch(head)?.group(1) ?? '';
  String? attr(String name) => RegExp('$name="([^"]*)"', caseSensitive: false).firstMatch(storyData)?.group(1);

  final format = attr('format') ?? '';
  final engine = RegExp('sugarcube', caseSensitive: false).hasMatch(format) || head.contains('SugarCube')
      ? 'SugarCube 2'
      : RegExp('harlowe', caseSensitive: false).hasMatch(format) || head.contains('Harlowe')
          ? 'Harlowe 3'
          : RegExp('snowman', caseSensitive: false).hasMatch(format)
              ? 'Snowman'
              : 'HTML5';

  final htmlTitle = RegExp(r'<title[^>]*>([^<]{1,120})</title>', caseSensitive: false).firstMatch(head)?.group(1)?.trim();
  final rawTitle = attr('name') ?? htmlTitle ?? '';
  final versionMatch = RegExp(r'v?(\d+(?:\.\d+){1,3})').firstMatch(htmlTitle ?? '') ?? RegExp(r'v?(\d+(?:\.\d+){1,3})').firstMatch(originalName);
  final title = _decodeEntities(rawTitle.replaceAll(RegExp(r'\s*v?\d+(\.\d+)+.*$'), '').trim());

  var size = 0;
  for (final f in files) {
    size += f.lengthSync();
  }

  return ImportDetection(
    title: title.isNotEmpty ? title : _titleFromFileName(originalName),
    engine: engine,
    version: versionMatch?.group(1) ?? '',
    ifid: attr('ifid')?.toUpperCase(),
    entryPath: p.relative(entry.path, from: stagingDir).replaceAll(r'\', '/'),
    fileCount: files.length,
    mediaCount: files.where((f) => _media.hasMatch(f.path)).length,
    webmCount: files.where((f) => f.path.toLowerCase().endsWith('.webm')).length,
    sizeBytes: size,
    stagingDir: stagingDir,
  );
}

Future<String> _readHead(File f, int maxBytes) async {
  final raf = await f.open();
  try {
    final bytes = await raf.read(maxBytes);
    return utf8.decode(bytes, allowMalformed: true);
  } finally {
    await raf.close();
  }
}

String _titleFromFileName(String name) => p
    .basenameWithoutExtension(name)
    .replaceAll(RegExp(r'[_-]v?\d.*$'), '')
    .replaceAll(RegExp(r'[_-]+'), ' ')
    .trim();

String _decodeEntities(String s) =>
    s.replaceAll('&amp;', '&').replaceAll('&#39;', "'").replaceAll('&apos;', "'").replaceAll('&quot;', '"').replaceAll('&lt;', '<').replaceAll('&gt;', '>');
