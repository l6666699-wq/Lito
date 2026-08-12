import 'package:flutter/widgets.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 28});

  static const assetPath = 'assets/logo.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .24),
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
