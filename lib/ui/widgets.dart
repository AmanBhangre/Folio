import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'folio_icon.dart';

/// The replica's component set. Every screen is assembled from these, which is
/// what keeps the app pixel-matched to the web design.

enum ButtonKind { normal, primary, danger, ghost }

class FolioButton extends StatelessWidget {
  const FolioButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = ButtonKind.normal,
    this.small = false,
    this.expand = false,
    this.height,
  });

  final String label;
  final VoidCallback? onPressed;
  final FolioIcons? icon;
  final ButtonKind kind;
  final bool small;
  final bool expand;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg, border) = switch (kind) {
      ButtonKind.primary => (c.accent, c.accentInk, c.accent),
      ButtonKind.danger => (c.badSoft, c.bad, c.badSoft),
      ButtonKind.ghost => (Colors.transparent, c.fg, Colors.transparent),
      ButtonKind.normal => (c.surface, c.fg, c.line),
    };
    final radius = BorderRadius.circular(small ? FolioSize.radiusButtonSm : FolioSize.radiusButton);
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[FolioIcon(icon!, size: 18, color: fg), const SizedBox(width: 8)],
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: FolioType.body(fg, size: small ? 13.5 : 15, weight: FontWeight.w600)),
        ),
      ],
    );
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          height: height ?? (small ? FolioSize.buttonHeightSm : FolioSize.buttonHeight),
          padding: EdgeInsets.symmetric(horizontal: small ? 12 : 16),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

class FolioIconButton extends StatelessWidget {
  const FolioIconButton({super.key, required this.icon, required this.onPressed, required this.tooltip, this.plain = false, this.color, this.background, this.borderColor});

  final FolioIcons icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool plain;
  final Color? color, background, borderColor;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background ?? (plain ? Colors.transparent : c.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor ?? (plain ? Colors.transparent : c.line)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: FolioSize.touch,
            child: Center(child: FolioIcon(icon, color: color ?? c.fg, semanticLabel: tooltip)),
          ),
        ),
      ),
    );
  }
}

/// Uppercase mono section label.
class FolioLabel extends StatelessWidget {
  const FolioLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: FolioType.label(context.c.muted));
}

class Meta extends StatelessWidget {
  const Meta(this.text, {super.key, this.mono = false, this.align});
  final String text;
  final bool mono;
  final TextAlign? align;
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: align,
      style: mono ? FolioType.mono(context.c.muted) : FolioType.body(context.c.muted, size: 13));
}

/// A label plus content with the replica's 10px gap.
class Section extends StatelessWidget {
  const Section({super.key, this.label, this.trailing, required this.children});
  final String? label;
  final Widget? trailing;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [Expanded(child: FolioLabel(label!)), if (trailing != null) trailing!]),
          ),
        ...children,
      ],
    );
  }
}

/// The scrolling body every non-player screen uses.
class FolioScreen extends StatelessWidget {
  const FolioScreen({super.key, required this.children, this.bottom, this.padded = true});
  final List<Widget> children;
  final Widget? bottom;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final list = ListView.separated(
      padding: padded
          ? const EdgeInsets.fromLTRB(FolioSize.screenPadH, FolioSize.screenPadTop, FolioSize.screenPadH, 24)
          : const EdgeInsets.only(bottom: 24),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: FolioSize.sectionGap),
      itemBuilder: (_, i) => children[i],
    );
    return Scaffold(
      backgroundColor: context.c.panel,
      body: SafeArea(bottom: bottom == null, child: list),
      bottomNavigationBar: bottom,
    );
  }
}

/// Large screen title row ("Library", "Cloud saves").
class TitleBar extends StatelessWidget {
  const TitleBar(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: FolioSize.touch,
        child: Row(children: [
          Expanded(child: Text(title, style: FolioType.display(context.c.fg))),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Back arrow plus a single-line heading.
class BackBar extends StatelessWidget {
  const BackBar(this.title, {super.key, required this.onBack, this.trailing});
  final String title;
  final VoidCallback onBack;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(children: [
        FolioIconButton(icon: FolioIcons.back, onPressed: onBack, tooltip: 'Back', plain: true),
        const SizedBox(width: 8),
        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: FolioType.heading(context.c.fg))),
        if (trailing != null) trailing!,
      ]);
}

/// Bordered list container; items are separated by hairlines.
class FolioList extends StatelessWidget {
  const FolioList({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(FolioSize.radiusCard),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: c.line),
          children[i],
        ],
      ]),
    );
  }
}

class FolioItem extends StatelessWidget {
  const FolioItem({super.key, required this.title, this.subtitle, this.icon, this.trailing, this.onTap, this.chevron = false, this.danger = false});
  final String title;
  final String? subtitle;
  final FolioIcons? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            if (icon != null) ...[FolioIcon(icon!, color: c.muted), const SizedBox(width: 12)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: FolioType.body(danger ? c.bad : c.fg, weight: FontWeight.w600)),
                if (subtitle != null) Text(subtitle!, style: FolioType.body(c.muted, size: 13)),
              ]),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            if (chevron) ...[const SizedBox(width: 8), FolioIcon(FolioIcons.chev, color: c.muted)],
          ]),
        ),
      ),
    );
  }
}

/// The replica's pill switch (48x28).
class FolioSwitch extends StatelessWidget {
  const FolioSwitch({super.key, required this.value, required this.onChanged, this.semanticLabel});
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      toggled: value,
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? c.accent : c.surface2,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: value ? c.accent : c.line),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 150),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: c.panel,
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 1))],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A list row whose whole surface toggles its switch.
class SwitchItem extends StatelessWidget {
  const SwitchItem({super.key, required this.title, required this.subtitle, required this.value, required this.onChanged});
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => FolioItem(
        title: title,
        subtitle: subtitle,
        onTap: () => onChanged(!value),
        trailing: FolioSwitch(value: value, onChanged: onChanged, semanticLabel: title),
      );
}

class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged});
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        for (final (v, label) in options)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Semantics(
                selected: v == value,
                button: true,
                child: GestureDetector(
                  onTap: () => onChanged(v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: v == value ? c.panel : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: v == value ? const [BoxShadow(color: Color(0x1F000000), blurRadius: 3, offset: Offset(0, 1))] : null,
                    ),
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FolioType.body(v == value ? c.fg : c.muted, size: 13.5, weight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class FilterChipPill extends StatelessWidget {
  const FilterChipPill({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: selected ? c.fg : Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: selected ? c.fg : c.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Text(label, style: FolioType.body(selected ? c.panel : c.muted, size: 13.5, weight: FontWeight.w600)),
        ),
      ),
    );
  }
}

enum BannerKind { info, warn, good, bad }

class FolioBanner extends StatelessWidget {
  const FolioBanner({super.key, required this.kind, required this.title, required this.body, required this.icon});
  final BannerKind kind;
  final String title, body;
  final FolioIcons icon;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, iconColor) = switch (kind) {
      BannerKind.info => (c.accentSoft, c.fg),
      BannerKind.warn => (c.warnSoft, c.warn),
      BannerKind.good => (c.goodSoft, c.good),
      BannerKind.bad => (c.badSoft, c.bad),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: FolioIcon(icon, color: iconColor)),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '$title\n', style: FolioType.body(c.fg, size: 14, weight: FontWeight.w700)),
            TextSpan(text: body, style: FolioType.body(c.fg, size: 14)),
          ])),
        ),
      ]),
    );
  }
}

enum BadgeKind { accent, good, warn }

class FolioBadge extends StatelessWidget {
  const FolioBadge(this.text, {super.key, this.kind = BadgeKind.accent, this.icon});
  final String text;
  final BadgeKind kind;
  final FolioIcons? icon;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg) = switch (kind) {
      BadgeKind.accent => (c.accent, c.accentInk),
      BadgeKind.good => (c.goodSoft, c.good),
      BadgeKind.warn => (c.warnSoft, c.warn),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[FolioIcon(icon!, size: 12, color: fg), const SizedBox(width: 4)],
        Text(text, style: FolioType.body(fg, size: 11.5, weight: FontWeight.w700)),
      ]),
    );
  }
}

/// A game's cover: its own art when the zip had one, else a color block with
/// the title's big initial, as in the replica.
class GameCover extends StatelessWidget {
  const GameCover({super.key, required this.game, this.height, this.big = false, this.square = false});
  final Game game;
  final double? height;
  final bool big;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final initial = game.title.replaceFirst(RegExp(r'^The\s+'), '');
    final badge = game.isNew ? 'New' : (game.updated ? 'Updated' : null);
    return ClipRRect(
      borderRadius: BorderRadius.circular(square ? 0 : FolioSize.radiusCover),
      child: Container(
        height: height,
        color: FolioColors.covers[game.coverIndex % FolioColors.covers.length],
        padding: EdgeInsets.all(big ? 18 : 10),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            right: big ? -14 : -16,
            top: big ? -68 : -28,
            child: ExcludeSemantics(
              child: Text(initial.isEmpty ? '?' : initial[0],
                  style: FolioType.display(FolioColors.coverInk.withValues(alpha: 0.22), size: big ? 260 : 110)),
            ),
          ),
          if (badge != null) Positioned(top: 0, left: 0, child: FolioBadge(badge)),
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: const Color(0x52000000), borderRadius: BorderRadius.circular(6)),
              child: Text(game.engine.toUpperCase(), style: FolioType.label(FolioColors.coverInk).copyWith(fontSize: 10.5)),
            ),
          ),
        ]),
      ),
    );
  }
}

class FolioProgress extends StatelessWidget {
  const FolioProgress({super.key, required this.value});
  final double value;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(value: value, minHeight: 10, color: context.c.accent, backgroundColor: context.c.surface2),
      );
}

/// Bottom sheet in the replica's style.
Future<T?> showFolioSheet<T>(BuildContext context, {required String title, String? body, required List<Widget> Function(BuildContext) actions}) {
  final c = context.c;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: c.panel,
    barrierColor: const Color(0x73000000),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(FolioSize.radiusSheet))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: FolioType.heading(c.fg, size: 20)),
          if (body != null) ...[const SizedBox(height: 14), Text(body, style: FolioType.body(c.muted))],
          for (final a in actions(ctx)) ...[const SizedBox(height: 14), a],
        ]),
      ),
    ),
  );
}

/// Dark toast pinned above the tab bar.
void showToast(BuildContext context, String message) {
  final c = context.c;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.fg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(milliseconds: 2600),
      content: Row(children: [
        FolioIcon(FolioIcons.check, size: 18, color: c.panel),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: FolioType.body(c.panel, size: 14, weight: FontWeight.w600))),
      ]),
    ));
}
