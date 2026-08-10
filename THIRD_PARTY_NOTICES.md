# Third-party notices

## IconPark

LiteTodo bundles 57 static SVG assets generated from the official ByteDance
IconPark SVG renderer package `@icon-park/svg` version `1.4.2`.

- Project: ByteDance IconPark
- Official repository: <https://github.com/bytedance/IconPark>
- Official package: <https://www.npmjs.com/package/@icon-park/svg>
- Package source tarball used for the one-time export:
  <https://registry.npmjs.org/@icon-park/svg/-/svg-1.4.2.tgz>
- License: Apache License 2.0
- License text: <https://github.com/bytedance/IconPark/blob/master/packages/svg/LICENSE>

The exported files are checked into `assets/icons/iconpark/` and are rendered
locally with `flutter_svg`.  LiteTodo stores only a stable `iconKey`; it does
not request icon data from the network at runtime.  The package was used only
as an asset-generation source and is not a Flutter or runtime dependency.
