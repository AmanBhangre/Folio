import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/cloud_sync.dart';
import '../state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../ui/folio_icon.dart';
import '../ui/widgets.dart';

/// Replica screen 8: the paid feature.
///
/// UI is complete; sign-in, upload and the subscription check land with the
/// Supabase and RevenueCat step (see services/cloud_sync.dart). Until then the
/// switch is honest about it.
class CloudScreen extends ConsumerWidget {
  const CloudScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final prefs = ref.watch(prefsProvider);
    final n = ref.read(prefsProvider.notifier);

    return FolioScreen(children: [
      const TitleBar('Cloud saves'),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.accentSoft, border: Border.all(color: c.accent), borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Expanded(child: Text('Folio Sync', style: FolioType.display(c.fg, size: 22))),
            Text('[YOUR PRICE] / month', style: FolioType.mono(c.fg, size: 14)),
          ]),
          const SizedBox(height: 12),
          for (final line in const [
            'Your saves on every phone and tablet you sign in on',
            'Pick up on your tablet where you stopped on your phone',
            'Saves survive a lost or reset phone',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 2), child: FolioIcon(FolioIcons.check, size: 16, color: c.accent)),
                const SizedBox(width: 8),
                Expanded(child: Text(line, style: FolioType.body(c.fg, size: 14))),
              ]),
            ),
          const SizedBox(height: 8),
          Material(
            color: c.panel,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: SwitchItem(
              title: 'Sync saves',
              subtitle: CloudSync.available ? (prefs.syncOn ? 'On' : 'Off. Saves stay on this phone.') : 'Coming soon. Saves stay on this phone for now.',
              value: prefs.syncOn,
              onChanged: (v) {
                if (!CloudSync.available) {
                  showToast(context, 'Cloud sync is not switched on in this build yet.');
                  return;
                }
                n.update((p) => p.copyWith(syncOn: v));
              },
            ),
          ),
        ]),
      ),
      Section(label: 'Devices', children: [
        FolioList(children: const [FolioItem(icon: FolioIcons.phone, title: 'This phone', subtitle: 'Sign in to see your other devices')]),
      ]),
      Section(label: 'When two devices disagree', children: [
        Segmented<ConflictRule>(
          options: const [(ConflictRule.newest, 'Newest save wins'), (ConflictRule.ask, 'Ask me')],
          value: prefs.conflict,
          onChanged: (v) => n.update((p) => p.copyWith(conflict: v)),
        ),
        const SizedBox(height: 10),
        const Meta('The other version is kept as a backup either way.'),
      ]),
      FolioList(children: [
        SwitchItem(title: 'Sync on Wi-Fi only', subtitle: 'Saves are small, a few KB each', value: prefs.wifiOnly, onChanged: (v) => n.update((p) => p.copyWith(wifiOnly: v))),
      ]),
    ]);
  }
}
