import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/models.dart';
import '../state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../ui/folio_icon.dart';
import '../ui/widgets.dart';

/// Replica screen 5: the game, full screen, with a bar the player can pull
/// down.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final Game _game = ref.read(gameProvider(widget.id))!;
  late final Future<String> _script = _prepare();
  late final StreamSubscription<String> _restoredSub;
  InAppWebViewController? _web;
  var _controls = false;
  var _landscape = false;
  String? _loadError;

  /// The game's options as they are now. [_game] is the snapshot taken when
  /// the player opened; the options screen can change them while it runs.
  GameOptions get _options => ref.read(gameProvider(widget.id))?.options ?? _game.options;

  @override
  void initState() {
    super.initState();
    _applySystemUi(_game.options);
    ref.read(libraryProvider.notifier).markPlayed(widget.id);
    _restoredSub = ref.read(servicesProvider).saves.restoredEvents.where((id) => id == widget.id).listen((_) => _reloadWithRestoredSaves());
  }

  /// Starts serving the game on its port, then builds the start script.
  Future<String> _prepare() async {
    final services = ref.read(servicesProvider);
    try {
      await services.server.serve(_game.id, _game.port);
    } on SocketException {
      if (mounted) setState(() => _loadError = 'Another app is using port ${_game.port}. Close it and open the game again.');
    }
    return services.saves.injectionScript(widget.id);
  }

  void _applySystemUi(GameOptions o) {
    SystemChrome.setEnabledSystemUIMode(o.fullScreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    WakelockPlus.toggle(enable: o.keepAwake);
    _setOrientation(switch (o.orientation) {
      GameOrientation.portrait => false,
      GameOrientation.landscape => true,
      GameOrientation.auto => null,
    });
  }

  /// Applies option changes made while the game runs. Inline video and
  /// desktop layout are WebView creation settings, so those two still wait
  /// for the next time the game opens.
  void _applyLiveOptions(GameOptions before, GameOptions now) {
    if (before.textScale != now.textScale) _applyTextScale(now.textScale);
    if (before.fullScreen != now.fullScreen || before.keepAwake != now.keepAwake || before.orientation != now.orientation) {
      _applySystemUi(now);
    }
  }

  Future<void> _applyTextScale(int scale) async {
    final web = _web;
    if (web == null) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // textZoom is Android only; this is the iOS equivalent.
      await web.evaluateJavascript(source: "document.documentElement.style.webkitTextSizeAdjust='$scale%';");
    } else {
      final settings = await web.getSettings();
      if (settings == null) return;
      settings.textZoom = scale;
      await web.setSettings(settings: settings);
    }
  }

  /// The player went back to a moment. Reload the page with a fresh start
  /// script so the game opens at that moment, instead of the old page
  /// writing its state back over it.
  Future<void> _reloadWithRestoredSaves() async {
    final web = _web;
    if (web == null) return;
    final script = await ref.read(servicesProvider).saves.injectionScript(widget.id);
    await web.removeAllUserScripts();
    await web.addUserScript(userScript: UserScript(source: script, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START));
    await web.reload();
  }

  void _setOrientation(bool? landscape) {
    SystemChrome.setPreferredOrientations(switch (landscape) {
      null => DeviceOrientation.values,
      true => [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
      false => [DeviceOrientation.portraitUp],
    });
  }

  @override
  void dispose() {
    _restoredSub.cancel();
    ref.read(servicesProvider).saves.flushAll();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _saveMoment() async {
    final saves = ref.read(servicesProvider).saves;
    // Small JPEG so a moment is recognisable in the list without costing
    // much space. A failed screenshot still saves the moment.
    List<int>? thumb;
    try {
      thumb = await _web?.takeScreenshot(
          screenshotConfiguration: ScreenshotConfiguration(compressFormat: CompressFormat.JPEG, quality: 60, snapshotWidth: 320));
    } on Object {
      thumb = null;
    }
    final m = await saves.saveMoment(widget.id, gameVersion: _game.version, thumbnail: thumb);
    ref.invalidate(momentsProvider(widget.id));
    if (mounted) showToast(context, m == null ? 'Nothing to save yet. Play a little first.' : 'Moment saved');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final services = ref.read(servicesProvider);
    final o = _game.options;
    final url = services.server.entryUrl(_game.id, _game.entryPath, _game.port);
    ref.listen<GameOptions?>(gameProvider(widget.id).select((g) => g?.options), (before, now) {
      if (before != null && now != null) _applyLiveOptions(before, now);
    });

    return Scaffold(
      backgroundColor: c.gameBg,
      body: FutureBuilder<String>(
        future: _script,
        builder: (context, snap) {
          if (!snap.hasData) return const SizedBox.expand();
          return Stack(children: [
            Positioned.fill(
              child: SafeArea(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri.uri(url)),
                  initialUserScripts: UnmodifiableListView([
                    UserScript(source: snap.data!, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START),
                  ]),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    databaseEnabled: true,
                    mediaPlaybackRequiresUserGesture: !o.inlineVideo,
                    allowsInlineMediaPlayback: true,
                    textZoom: o.textScale,
                    preferredContentMode: o.desktopLayout ? UserPreferredContentMode.DESKTOP : UserPreferredContentMode.RECOMMENDED,
                    supportZoom: false,
                    disallowOverScroll: true,
                    useShouldOverrideUrlLoading: true,
                    javaScriptCanOpenWindowsAutomatically: false,
                    isInspectable: kDebugMode,
                    transparentBackground: false,
                  ),
                  onWebViewCreated: (controller) {
                    _web = controller;
                    controller.addJavaScriptHandler(
                      handlerName: 'folioStorage',
                      callback: (args) {
                        if (args.length < 3) return null;
                        services.saves.onStorageEvent(_game.id, '${args[0]}', args[1] as String?, args[2] as String?);
                        return null;
                      },
                    );
                  },
                  // Only the game's own pages load in the player. Links out of
                  // the game are dropped rather than replacing the game.
                  shouldOverrideUrlLoading: (controller, action) async {
                    final u = action.request.url;
                    final local = u != null && u.host == '127.0.0.1' && u.port == _game.port;
                    return local || u?.scheme == 'about' || u?.scheme == 'blob' || u?.scheme == 'data'
                        ? NavigationActionPolicy.ALLOW
                        : NavigationActionPolicy.CANCEL;
                  },
                  onLoadStop: (controller, _) async {
                    // Android's textZoom setting survives a reload; the iOS
                    // style does not, so it is set again on every load.
                    final scale = _options.textScale;
                    if (scale != 100 && defaultTargetPlatform == TargetPlatform.iOS) await _applyTextScale(scale);
                  },
                  onReceivedError: (controller, request, error) {
                    if (request.isForMainFrame ?? false) setState(() => _loadError = error.description);
                  },
                ),
              ),
            ),
            if (_loadError != null)
              Positioned.fill(
                child: ColoredBox(
                  color: c.gameBg,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('The game did not load', style: FolioType.heading(c.gameFg)),
                        const SizedBox(height: 8),
                        Text(_loadError!, textAlign: TextAlign.center, style: FolioType.body(c.gameFg.withValues(alpha: 0.7), size: 14)),
                        const SizedBox(height: 16),
                        FolioButton(label: 'Back', onPressed: () => context.pop()),
                      ]),
                    ),
                  ),
                ),
              ),
            _overlay(context),
          ]);
        },
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    final c = context.c;
    const ink = Color(0xFFF1EEE8);
    final top = MediaQuery.paddingOf(context).top;
    if (!_controls) {
      return Positioned(
        top: top + 8,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: const Color(0x24FFFFFF),
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => setState(() => _controls = true),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text('Show controls', style: FolioType.body(ink, size: 12, weight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      );
    }
    Widget dockButton(FolioIcons icon, String label, VoidCallback onTap) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: const Color(0xFF1F2125),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: SizedBox(
                  height: 56,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    FolioIcon(icon, color: c.gameFg),
                    const SizedBox(height: 4),
                    Text(label, style: FolioType.body(c.gameFg, size: 12, weight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ),
        );
    return Positioned.fill(
      child: Column(children: [
        Container(
          padding: EdgeInsets.fromLTRB(12, top + 12, 12, 24),
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xBF000000), Color(0x00000000)])),
          child: Row(children: [
            FolioIconButton(icon: FolioIcons.back, tooltip: 'Leave game', onPressed: () => context.pop(), background: const Color(0x1AFFFFFF), borderColor: const Color(0x24FFFFFF), color: ink),
            const SizedBox(width: 8),
            Expanded(child: Text(_game.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: FolioType.body(ink, size: 14, weight: FontWeight.w600))),
            FolioIconButton(icon: FolioIcons.full, tooltip: 'Hide controls', onPressed: () => setState(() => _controls = false), background: const Color(0x1AFFFFFF), borderColor: const Color(0x24FFFFFF), color: ink),
          ]),
        ),
        const Spacer(),
        Container(
          padding: EdgeInsets.fromLTRB(8, 10, 8, 14 + MediaQuery.paddingOf(context).bottom),
          decoration: const BoxDecoration(color: Color(0xFF141518), border: Border(top: BorderSide(color: Color(0xFF26292D)))),
          child: Row(children: [
            if (supportsMoments(_game)) ...[
              dockButton(FolioIcons.save, 'Save moment', _saveMoment),
              dockButton(FolioIcons.load, 'Moments', () => context.push('/game/${widget.id}/moments')),
            ],
            dockButton(FolioIcons.rotate, 'Rotate', () {
              _landscape = !_landscape;
              _setOrientation(_landscape);
            }),
            dockButton(FolioIcons.sliders, 'Options', () => context.push('/game/${widget.id}/options')),
          ]),
        ),
      ]),
    );
  }
}
