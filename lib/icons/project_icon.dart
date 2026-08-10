import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'project_icons.dart';

/// Renders a persisted project [iconKey] from the checked-in IconPark assets.
class ProjectIcon extends StatelessWidget {
  const ProjectIcon({
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
    final entry = ProjectIcons.resolve(iconKey);
    return SvgPicture.asset(
      entry.assetPath,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}
