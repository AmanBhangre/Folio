import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The replica's stroke icons, same paths, so the app matches it exactly.
enum FolioIcons {
  library('<path d="M4 5h6v14H4zM14 5h6v6h-6zM14 15h6v4h-6z"/>'),
  cloud('<path d="M7 18h10a4 4 0 0 0 .5-7.97A6 6 0 0 0 6.1 9.5 4.5 4.5 0 0 0 7 18z"/>'),
  gear('<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1A1.7 1.7 0 0 0 4.6 9a1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>'),
  plus('<path d="M12 5v14M5 12h14"/>'),
  search('<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>'),
  back('<path d="M15 18l-6-6 6-6"/>'),
  chev('<path d="M9 18l6-6-6-6"/>'),
  play('<path d="M7 5v14l12-7z"/>'),
  zip('<path d="M6 3h9l5 5v13H6z"/><path d="M14 3v6h6M10 7h2M10 10h2M10 13h2M10 16h2v2h-2z"/>'),
  share('<path d="M12 3v12M7 8l5-5 5 5"/><path d="M5 13v7h14v-7"/>'),
  folder('<path d="M3 6h6l2 2h10v11H3z"/>'),
  open('<path d="M14 4h6v6M20 4l-9 9"/><path d="M18 14v6H4V6h6"/>'),
  save('<path d="M5 3h11l3 3v15H5z"/><path d="M8 3v6h8V3M8 21v-7h8v7"/>'),
  load('<path d="M3 12a9 9 0 1 0 3-6.7"/><path d="M3 4v5h5"/>'),
  rotate('<path d="M4 12a8 8 0 0 1 14-5.3L20 9"/><path d="M20 4v5h-5"/><rect x="7" y="11" width="10" height="9" rx="1.5"/>'),
  full('<path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/>'),
  dots('<circle cx="5" cy="12" r="1.4"/><circle cx="12" cy="12" r="1.4"/><circle cx="19" cy="12" r="1.4"/>'),
  check('<path d="M5 12.5l4.5 4.5L19 7.5"/>'),
  warn('<path d="M12 4 2.5 20h19z"/><path d="M12 10v4M12 17v.5"/>'),
  info('<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5v.5"/>'),
  export('<path d="M12 15V3M7 8l5-5 5 5"/><path d="M4 14v6h16v-6"/>'),
  import('<path d="M12 3v12M7 10l5 5 5-5"/><path d="M4 14v6h16v-6"/>'),
  trash('<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>'),
  update('<path d="M20 11a8 8 0 0 0-14.9-3M4 13a8 8 0 0 0 14.9 3"/><path d="M4 4v4h4M20 20v-4h-4"/>'),
  phone('<rect x="7" y="2.5" width="10" height="19" rx="2"/><path d="M11 18.5h2"/>'),
  tablet('<rect x="4" y="3" width="16" height="18" rx="2"/><path d="M11 18h2"/>'),
  sliders('<path d="M4 7h10M18 7h2M4 17h4M12 17h8"/><circle cx="16" cy="7" r="2"/><circle cx="10" cy="17" r="2"/>'),
  mark('<rect x="4" y="4" width="16" height="16" rx="3"/><path d="M10 9v6l5-3z"/>');

  const FolioIcons(this.paths);
  final String paths;
}

class FolioIcon extends StatelessWidget {
  const FolioIcon(this.icon, {super.key, this.size = 20, this.color, this.semanticLabel});

  final FolioIcons icon;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? DefaultTextStyle.of(context).style.color ?? const Color(0xFF000000);
    final svg = '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" fill="none" stroke="#000" '
        'stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${icon.paths}</svg>';
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
