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

/// The spots the player saved with "Save moment", newest first. Going back
/// to one changes only where the player is; the game's own saves stay.
class MomentsScreen extends ConsumerWidget {
  const MomentsScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final game = ref.watch(gameProvider(id));
    if (game == null) return FolioScreen(children: [BackBar('Moments', onBack: () => context.pop())]);
    final moments = ref.watch(momentsProvider(id));
    final saves = ref.read(servicesProvider).saves;

    Future<void> open(Moment m) async {
      final older = m.gameVersion != game.version;
      await showFolioSheet<void>(context,
          title: 'Go back to this moment?',
          body: 'From ${formatWhen(m.createdAt)}. The game goes back to this spot. '
              "Saves you made in the game's own menu are kept."
              '${older ? '\n\nMade in v${m.gameVersion}, so it may not work in v${game.version}.' : ''}',
          actions: (sheet) => [
                FolioButton(
                  label: 'Go back',
                  icon: FolioIcons.load,
                  kind: ButtonKind.primary,
                  expand: true,
                  onPressed: () async {
                    Navigator.pop(sheet);
                    final router = GoRouter.of(context);
                    await saves.jumpToMoment(id, m.id);
                    // Back to the game, which reloads at this moment.
                    if (router.canPop()) router.pop();
                  },
                ),
                FolioButton(
                  label: 'Delete moment',
                  icon: FolioIcons.trash,
                  kind: ButtonKind.danger,
                  expand: true,
                  onPressed: () async {
                    Navigator.pop(sheet);
                    await saves.deleteMoment(id, m.id);
                    ref.invalidate(momentsProvider(id));
                  },
                ),
                FolioButton(label: 'Cancel', expand: true, onPressed: () => Navigator.pop(sheet)),
              ]);
    }

    return FolioScreen(children: [
      BackBar('${game.title} moments', onBack: () => context.pop()),
      moments.when(
        loading: () => const SizedBox(height: 40),
        error: (e, _) => Meta('Could not read moments: $e'),
        data: (list) => list.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Meta('No moments yet. While playing, tap Save moment to keep a spot you want to come back to.', align: TextAlign.center),
              )
            : Column(children: [
                for (final m in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => open(m),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 112,
                                height: 70,
                                child: m.thumbPath == null
                                    ? ColoredBox(color: c.gameBg, child: Center(child: FolioIcon(FolioIcons.mark, color: c.muted)))
                                    : Image.file(File(m.thumbPath!), fit: BoxFit.cover),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(formatWhen(m.createdAt), style: FolioType.body(c.fg, size: 15, weight: FontWeight.w600)),
                                if (m.gameVersion.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  m.gameVersion == game.version
                                      ? Text('v${m.gameVersion}', style: FolioType.mono(c.muted, size: 12))
                                      : FolioBadge('Made in v${m.gameVersion}', kind: BadgeKind.warn),
                                ],
                              ]),
                            ),
                            FolioIcon(FolioIcons.chev, color: c.muted),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ]),
      ),
      const Meta("A moment keeps where you were. Going back never changes the saves in the game's own menu."),
    ]);
  }
}
