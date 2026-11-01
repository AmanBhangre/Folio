import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../ui/folio_icon.dart';
import '../ui/format.dart';
import '../ui/widgets.dart';

/// Replica screen 3. [updateGameId] is set when opened from a game's
/// "Update from a newer zip" row.
class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key, this.updateGameId});
  final String? updateGameId;

  Future<void> _pick(WidgetRef ref) async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
    final f = files.firstOrNull;
    final path = f?.path;
    if (f == null || path == null) return;
    await ref.read(importProvider.notifier).start(zipPath: path, fileName: f.name);
  }

  void _leave(BuildContext context, WidgetRef ref) {
    ref.read(importProvider.notifier).cancel();
    context.canPop() ? context.pop() : context.go('/library');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(importProvider);
    final body = switch (s.stage) {
      ImportStage.pick => _pickBody(context, ref),
      ImportStage.working => _workingBody(context, s),
      ImportStage.error => [
          FolioBanner(kind: BannerKind.bad, icon: FolioIcons.warn, title: 'Could not add this game', body: s.error ?? ''),
          FolioButton(label: 'Choose another file', expand: true, onPressed: () => ref.read(importProvider.notifier).reset()),
        ],
      ImportStage.review => _reviewBody(context, ref, s),
    };
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && s.stage == ImportStage.review) ref.read(importProvider.notifier).cancel();
      },
      child: FolioScreen(children: [BackBar('Import a game', onBack: () => _leave(context, ref)), ...body]),
    );
  }

  List<Widget> _pickBody(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.line, width: 2),
        ),
        child: Column(children: [
          FolioIcon(FolioIcons.zip, size: 34, color: c.accent),
          const SizedBox(height: 10),
          Text('Choose a game zip', style: FolioType.body(c.fg, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text('The zip a game ships in. Folio finds index.html inside it, even in a subfolder.',
              textAlign: TextAlign.center, style: FolioType.body(c.muted, size: 14)),
          const SizedBox(height: 10),
          FolioButton(label: 'Browse files', icon: FolioIcons.folder, kind: ButtonKind.primary, onPressed: () => _pick(ref)),
        ]),
      ),
      Section(label: 'Other ways in', children: [
        FolioList(children: const [
          FolioItem(icon: FolioIcons.share, title: 'Share sheet', subtitle: 'From Safari, Chrome or Downloads'),
          FolioItem(icon: FolioIcons.open, title: 'Open with Folio', subtitle: 'Tap a zip in any file app'),
        ]),
      ]),
    ];
  }

  List<Widget> _workingBody(BuildContext context, ImportState s) {
    final c = context.c;
    return [
      const SizedBox(height: 12),
      Section(label: 'Unpacking', children: [
        Text(s.fileName ?? '', style: FolioType.body(c.fg, weight: FontWeight.w700)),
        const SizedBox(height: 10),
        // The archive package reports no byte progress for zips, so this is
        // an honest indeterminate bar rather than a made-up percentage.
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(minHeight: 10, color: c.accent, backgroundColor: c.surface2),
        ),
        const SizedBox(height: 10),
        const Meta('Reading files, finding index.html, checking videos', mono: true),
      ]),
      const Meta('You can leave this screen. The game shows up for review when it is ready.'),
    ];
  }

  List<Widget> _reviewBody(BuildContext context, WidgetRef ref, ImportState s) {
    final c = context.c;
    final d = s.detection!;
    final lib = ref.read(libraryProvider.notifier);
    final match = updateGameId != null ? lib.byId(updateGameId!) : lib.matchFor(d);

    Widget kv(String k, String v, {bool mono = false, bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: FolioType.body(c.muted, size: 14)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(v,
                  textAlign: TextAlign.right,
                  style: mono ? FolioType.mono(c.fg, size: 13.5) : FolioType.body(c.fg, size: 14, weight: bold ? FontWeight.w700 : FontWeight.w400)),
            ),
          ]),
        );

    Future<void> finish(Future<dynamic> Function() action, String message, String Function() target) async {
      final router = GoRouter.of(context);
      final messenger = context;
      await action();
      ref.read(importProvider.notifier).reset();
      router.go(target());
      if (messenger.mounted) showToast(messenger, message);
    }

    return [
      const FolioBanner(kind: BannerKind.good, icon: FolioIcons.check, title: 'Ready to add', body: 'Found the game and everything it needs.'),
      Column(children: [
        kv('Title', d.title, bold: true),
        kv('Engine', d.engine),
        kv('Version', d.version.isEmpty ? 'Not stated' : d.version, mono: true),
        kv('Start file', d.entryPath, mono: true),
        kv('Files', '${d.fileCount} · ${d.mediaCount} media', mono: true),
        kv('Size unpacked', formatSize(d.sizeBytes), mono: true),
      ]),
      if (d.webmCount > 0)
        FolioBanner(
          kind: BannerKind.warn,
          icon: FolioIcons.warn,
          title: '${d.webmCount} WebM video${d.webmCount > 1 ? 's' : ''}',
          body: 'These may not play on older iPhones. MP4 plays everywhere.',
        ),
      if (match != null) ...[
        FolioBanner(
          kind: BannerKind.info,
          icon: FolioIcons.update,
          title: 'Matches ${match.title}${match.version.isEmpty ? '' : ' v${match.version}'} in your library',
          body: 'Updating replaces the game files and keeps every save.',
        ),
        FolioButton(
          label: 'Update and keep saves',
          icon: FolioIcons.update,
          kind: ButtonKind.primary,
          expand: true,
          onPressed: () {
            late String id;
            finish(() async => id = (await lib.updateFromImport(match, d)).id,
                'Updated${d.version.isEmpty ? '' : ' to v${d.version}'}. Saves kept.', () => '/game/$id');
          },
        ),
        FolioButton(
          label: 'Add as a separate game',
          expand: true,
          onPressed: () {
            late String id;
            finish(() async => id = (await lib.addFromImport(d)).id, '${d.title} added to your library', () => '/game/$id');
          },
        ),
      ] else
        FolioButton(
          label: 'Add to library',
          icon: FolioIcons.plus,
          kind: ButtonKind.primary,
          expand: true,
          onPressed: () {
            late String id;
            finish(() async => id = (await lib.addFromImport(d)).id, '${d.title} added to your library', () => '/game/$id');
          },
        ),
      FolioButton(label: 'Cancel', kind: ButtonKind.ghost, expand: true, onPressed: () => _leave(context, ref)),
    ];
  }
}
