import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'icon_catalog.dart';

/// Lightweight local SVG widget used for project/sidebar affordances only.
/// Todo rows intentionally keep their checkbox/indent path as Flutter base
/// widgets to avoid turning every visible row into a heavyweight SVG subtree.
class LocalProjectIcon extends StatelessWidget {
  const LocalProjectIcon({
    super.key,
    required this.iconKey,
    required this.color,
    this.size = 17,
  });

  final String iconKey;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final entry = IconCatalog.resolve(iconKey);
    return SvgPicture.asset(
      entry.assetPath,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}
