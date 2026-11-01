import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/game_options_screen.dart';
import 'screens/game_screen.dart';
import 'screens/import_screen.dart';
import 'screens/library_screen.dart';
import 'screens/moments_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/player_screen.dart';
import 'screens/preferences_screen.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'ui/folio_icon.dart';

/// Screen map, same order as the replica's screen index.
GoRouter buildRouter({required bool startAtOnboarding}) => GoRouter(
      initialLocation: startAtOnboarding ? '/onboarding' : '/library',
      routes: [
        GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
        GoRoute(path: '/import', builder: (_, s) => ImportScreen(updateGameId: s.uri.queryParameters['update'])),
        GoRoute(path: '/game/:id', builder: (_, s) => GameScreen(id: s.pathParameters['id']!), routes: [
          GoRoute(path: 'play', builder: (_, s) => PlayerScreen(id: s.pathParameters['id']!)),
          GoRoute(path: 'moments', builder: (_, s) => MomentsScreen(id: s.pathParameters['id']!)),
          GoRoute(path: 'options', builder: (_, s) => GameOptionsScreen(id: s.pathParameters['id']!)),
        ]),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => _TabShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [GoRoute(path: '/library', builder: (_, _) => const LibraryScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: '/preferences', builder: (_, _) => const PreferencesScreen())]),
          ],
        ),
      ],
    );

class _TabShell extends StatelessWidget {
  const _TabShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget tab(int i, FolioIcons icon, String label) {
      final on = shell.currentIndex == i;
      final color = on ? c.accent : c.muted;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          label: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => shell.goBranch(i, initialLocation: i == shell.currentIndex),
            child: SizedBox(
              height: 52,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                FolioIcon(icon, size: 22, color: color),
                const SizedBox(height: 3),
                Text(label, style: FolioType.body(color, size: 12, weight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(color: c.panel, border: Border(top: BorderSide(color: c.line))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
            child: Row(children: [
              tab(0, FolioIcons.library, 'Library'),
              tab(1, FolioIcons.gear, 'Settings'),
            ]),
          ),
        ),
      ),
    );
  }
}
