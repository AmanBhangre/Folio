import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../ui/folio_icon.dart';
import '../ui/format.dart';
import '../ui/widgets.dart';

/// Replica screen 7. Text size, full screen, keep awake and orientation apply
/// to a running game at once; inline video and desktop layout apply the next
/// time the game opens.
class GameOptionsScreen extends ConsumerStatefulWidget {
  const GameOptionsScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<GameOptionsScreen> createState() => _GameOptionsScreenState();
}

class _GameOptionsScreenState extends ConsumerState<GameOptionsScreen> {
  int? _savesBytes;

  @override
  void initState() {
    super.initState();
    _measureSaves();
  }

  Future<void> _measureSaves() async {
    final dir = Directory(ref.read(servicesProvider).paths.savesDir(widget.id));
    var total = 0;
    if (await dir.exists()) {
      await for (final f in dir.list(recursive: true)) {
        if (f is File) total += await f.length();
      }
    }
    if (mounted) setState(() => _savesBytes = total);
  }

  void _set(GameOptions o) => ref.read(libraryProvider.notifier).setOptions(widget.id, o);

  Future<void> _confirmDelete(Game g) => showFolioSheet<void>(context,
      title: 'Delete ${g.title}?',
      body: 'Removes ${formatSize(g.sizeBytes)} of game files from this phone, with its saves and moments. Importing it again starts it fresh.',
      actions: (sheet) => [
            FolioButton(
              label: 'Delete game',
              icon: FolioIcons.trash,
              kind: ButtonKind.danger,
              expand: true,
              onPressed: () async {
                Navigator.pop(sheet);
                final router = GoRouter.of(context);
                await ref.read(libraryProvider.notifier).delete(g.id);
                router.go('/library');
              },
            ),
            FolioButton(label: 'Cancel', expand: true, onPressed: () => Navigator.pop(sheet)),
          ]);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final g = ref.watch(gameProvider(widget.id));
    if (g == null) return FolioScreen(children: [BackBar('Game settings', onBack: () => context.pop())]);
    final o = g.options;
    final saves = _savesBytes ?? 0;
    final total = (g.sizeBytes + saves).clamp(1, 1 << 62);

    return FolioScreen(children: [
      BackBar('Game settings', onBack: () => context.pop()),
      Section(label: 'Orientation', children: [
        Segmented<GameOrientation>(
          options: const [(GameOrientation.auto, 'Auto'), (GameOrientation.portrait, 'Portrait'), (GameOrientation.landscape, 'Landscape')],
          value: o.orientation,
          onChanged: (v) => _set(o.copyWith(orientation: v)),
        ),
      ]),
      Section(label: 'Screen and video', children: [
        FolioList(children: [
          SwitchItem(title: 'Full screen', subtitle: 'Hide system bars while playing', value: o.fullScreen, onChanged: (v) => _set(o.copyWith(fullScreen: v))),
          SwitchItem(title: 'Keep screen on', subtitle: 'Stops the phone sleeping mid-scene', value: o.keepAwake, onChanged: (v) => _set(o.copyWith(keepAwake: v))),
          SwitchItem(
              title: 'Play videos inline',
              subtitle: 'Videos start on their own, without going full screen',
              value: o.inlineVideo,
              onChanged: (v) => _set(o.copyWith(inlineVideo: v))),
          SwitchItem(title: 'Desktop layout', subtitle: 'For games that break on narrow screens', value: o.desktopLayout, onChanged: (v) => _set(o.copyWith(desktopLayout: v))),
        ]),
      ]),
      Section(
        label: 'Text size',
        trailing: Text('${o.textScale}%', style: FolioType.mono(c.muted)),
        children: [
          Slider(
            value: o.textScale.toDouble(),
            min: 80,
            max: 150,
            divisions: 14,
            label: '${o.textScale}%',
            onChanged: (v) => _set(o.copyWith(textScale: v.round())),
          ),
          const Meta("Scales the game's text without breaking its layout."),
        ],
      ),
      Section(
        label: 'Storage',
        trailing: Text(formatSize(total), style: FolioType.mono(c.muted)),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 12,
              child: Row(children: [
                Expanded(flex: (g.sizeBytes * 1000 ~/ total).clamp(1, 1000), child: ColoredBox(color: c.accent)),
                Expanded(flex: (saves * 1000 ~/ total).clamp(15, 1000), child: ColoredBox(color: c.good)),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 14, runSpacing: 6, children: [
            _legend(c.accent, 'Game ${formatSize(g.sizeBytes)}', c),
            _legend(c.good, 'Saves ${formatSize(saves)}', c),
          ]),
          const SizedBox(height: 10),
          FolioButton(label: 'Delete game', icon: FolioIcons.trash, kind: ButtonKind.danger, expand: true, onPressed: () => _confirmDelete(g)),
        ],
      ),
    ]);
  }

  Widget _legend(Color color, String text, FolioColors c) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(text, style: FolioType.body(c.muted, size: 13)),
      ]);
}
