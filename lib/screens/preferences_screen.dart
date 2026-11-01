import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state.dart';
import '../ui/folio_icon.dart';
import '../ui/widgets.dart';

/// Replica screen 9.
class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  static const appVersion = '0.1.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider);
    final n = ref.read(prefsProvider.notifier);
    return FolioScreen(children: [
      const TitleBar('Settings'),
      Section(label: 'Library', children: [
        Segmented<LibrarySort>(
          options: const [(LibrarySort.recent, 'Recently played'), (LibrarySort.az, 'A to Z')],
          value: prefs.sort,
          onChanged: (v) => n.update((p) => p.copyWith(sort: v)),
        ),
      ]),
      Section(label: 'Appearance', children: [
        FolioList(children: [
          SwitchItem(
            title: 'Match phone theme',
            subtitle: 'Light or dark, as the system is set. Off keeps it light.',
            value: prefs.followSystemTheme,
            onChanged: (v) => n.update((p) => p.copyWith(followSystemTheme: v)),
          ),
        ]),
      ]),
      Section(label: 'Getting games in', children: [
        FolioList(children: [
          FolioItem(icon: FolioIcons.info, title: 'How to add a game', subtitle: 'From the Files app', chevron: true, onTap: () => context.push('/onboarding')),
        ]),
      ]),
      const Section(label: 'Privacy', children: [
        Meta("No account. Games and saves stay on this phone. Folio doesn't see what you play."),
      ]),
      const Section(label: 'About', children: [
        Meta('Version $appVersion', mono: true),
        SizedBox(height: 4),
        Meta('Plays Twine games (SugarCube, Harlowe, Snowman) and HTML5 games, including RPG Maker MV and MZ'),
        SizedBox(height: 4),
        Meta('Coming later: sync across devices.'),
      ]),
    ]);
  }
}
