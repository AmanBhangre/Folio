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

enum _Filter { all, played, updated }

/// Replica screen 2.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});
  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _query = TextEditingController();
  var _filter = _Filter.all;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final games = ref.watch(libraryProvider);
    final sort = ref.watch(prefsProvider.select((p) => p.sort));
    final q = _query.text.trim().toLowerCase();

    final recent = [...games]..sort((a, b) => (b.lastPlayedAt ?? b.addedAt).compareTo(a.lastPlayedAt ?? a.addedAt));
    final list = (sort == LibrarySort.az ? ([...games]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()))) : recent)
        .where((g) => q.isEmpty || g.title.toLowerCase().contains(q))
        .where((g) => switch (_filter) {
              _Filter.all => true,
              _Filter.played => g.lastPlayedAt != null,
              _Filter.updated => g.isNew || g.updated,
            })
        .toList();
    final cont = recent.where((g) => g.lastPlayedAt != null).firstOrNull;
    final total = games.fold<int>(0, (a, g) => a + g.sizeBytes);

    return FolioScreen(children: [
      TitleBar('Library',
          trailing: FolioButton(label: 'Import', icon: FolioIcons.plus, kind: ButtonKind.primary, small: true, height: 44, onPressed: () => context.push('/import'))),
      _SearchField(controller: _query, hint: 'Search ${games.length} games', onChanged: () => setState(() {})),
      if (q.isEmpty && _filter == _Filter.all && cont != null)
        Section(label: 'Continue playing', children: [_ContinueCard(game: cont)]),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final (f, l) in [(_Filter.all, 'All'), (_Filter.played, 'Played'), (_Filter.updated, 'New and updated')]) ...[
            FilterChipPill(label: l, selected: _filter == f, onTap: () => setState(() => _filter = f)),
            const SizedBox(width: 8),
          ],
        ]),
      ),
      if (games.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Column(children: [
            Meta('No games yet.', align: TextAlign.center),
            const SizedBox(height: 12),
            FolioButton(label: 'How to add a game', onPressed: () => context.push('/onboarding')),
          ]),
        )
      else if (list.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 30), child: Meta('No games match “${_query.text}”.', align: TextAlign.center))
      else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.62),
          itemBuilder: (_, i) => _GameCard(game: list[i]),
        ),
      if (games.isNotEmpty) Meta('${games.length} games · ${formatSize(total)} on this phone', align: TextAlign.center),
    ]);
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hint, required this.onChanged});
  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        FolioIcon(FolioIcons.search, size: 18, color: c.muted),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            style: FolioType.body(c.fg),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: FolioType.body(c.muted),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.game});
  final Game game;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: c.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/game/${game.id}/play'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            SizedBox(width: 92, child: GameCover(game: game, height: 116)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(game.title, style: FolioType.heading(c.fg)),
                const SizedBox(height: 6),
                Meta(formatWhen(game.lastPlayedAt)),
                const SizedBox(height: 6),
                IgnorePointer(child: FolioButton(label: 'Resume', icon: FolioIcons.play, kind: ButtonKind.primary, small: true, onPressed: () {})),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game});
  final Game game;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      label: game.title,
      child: GestureDetector(
        onTap: () => context.push('/game/${game.id}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: GameCover(game: game)),
          const SizedBox(height: 8),
          Text(game.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: FolioType.body(c.fg, weight: FontWeight.w600)),
          Meta('${game.version.isEmpty ? '' : 'v${game.version} · '}${formatSize(game.sizeBytes)}', mono: true),
        ]),
      ),
    );
  }
}
