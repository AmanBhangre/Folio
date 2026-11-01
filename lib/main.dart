import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'services/cloud_sync.dart';
import 'state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CloudSync.init();
  final services = await AppServices.start();
  final games = await services.library.load();
  final prefs = await Prefs.load(services.paths);
  runApp(ProviderScope(
    overrides: [
      servicesProvider.overrideWithValue(services),
      initialGamesProvider.overrideWithValue(games),
      initialPrefsProvider.overrideWithValue(prefs),
    ],
    child: FolioApp(startAtOnboarding: games.isEmpty),
  ));
}

class FolioApp extends ConsumerStatefulWidget {
  const FolioApp({super.key, required this.startAtOnboarding});
  final bool startAtOnboarding;

  @override
  ConsumerState<FolioApp> createState() => _FolioAppState();
}

class _FolioAppState extends ConsumerState<FolioApp> with WidgetsBindingObserver {
  late final router = buildRouter(startAtOnboarding: widget.startAtOnboarding);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The OS can kill a backgrounded app without warning; flush saves first.
  /// iOS also suspends the local server's socket in the background, so it is
  /// restarted on resume.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    final services = ref.read(servicesProvider);
    if (s == AppLifecycleState.paused) services.saves.flushAll();
    if (s == AppLifecycleState.resumed) {
      services.server.stop().then((_) => services.server.start());
    }
  }

  @override
  Widget build(BuildContext context) {
    final follow = ref.watch(prefsProvider.select((p) => p.followSystemTheme));
    return MaterialApp.router(
      title: 'Folio',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: follow ? ThemeMode.system : ThemeMode.light,
      routerConfig: router,
    );
  }
}
