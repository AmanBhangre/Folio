import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../ui/folio_icon.dart';
import '../ui/widgets.dart';

/// Replica screen 1: first launch, empty library.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget step(FolioIcons icon, String title, String body) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: FolioIcon(icon, color: c.fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: FolioType.body(c.fg, weight: FontWeight.w700)),
              Text(body, style: FolioType.body(c.muted, size: 14)),
            ]),
          ),
        ]);

    Widget format(String t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(6)),
          child: Text(t, style: FolioType.mono(c.muted, size: 11.5)),
        );

    return Scaffold(
      backgroundColor: c.panel,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: FolioSize.screenPadH, vertical: 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(18)),
                  alignment: Alignment.center,
                  child: FolioIcon(FolioIcons.mark, size: 34, color: c.accentInk),
                ),
              ),
              const SizedBox(height: 22),
              Text('Play HTML games offline, saves included', style: FolioType.display(c.fg, size: 34).copyWith(height: 1.05)),
              const SizedBox(height: 10),
              Text('Add a game you downloaded. Folio keeps it on this phone, ready to play offline.', style: FolioType.body(c.muted)),
              const SizedBox(height: 22),
              step(FolioIcons.folder, 'Pick a zip from Files', 'Downloads, iCloud Drive, Google Drive, a USB stick.'),
              const SizedBox(height: 22),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final f in ['HTML5', 'SugarCube', 'Harlowe', 'Snowman', 'RPG Maker', '.zip']) format(f)]),
              const SizedBox(height: 22),
              FolioButton(label: 'Import a game', icon: FolioIcons.plus, kind: ButtonKind.primary, expand: true, onPressed: () => context.go('/import')),
              const SizedBox(height: 10),
              FolioButton(label: 'Go to library', expand: true, onPressed: () => context.go('/library')),
            ]),
          ),
        ),
      ),
    );
  }
}
