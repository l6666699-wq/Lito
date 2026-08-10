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

## lucide_icons_flutter 3.1.15

LiteTodo uses the direct Flutter dependency `lucide_icons_flutter` version
`3.1.15` for UI, system, and action icons through `lib/icons/app_icons.dart`.

- Project: lucide_icons_flutter
- Homepage: <https://lucide.dev>
- Repository: <https://github.com/vqh2602/lucide-flutter-main>
- License: MIT
- The package `LICENSE` file is included in the pub.dev package distribution
  and was reviewed for this dependency.

The cached `LICENSE` file contains the MIT License notice and copyright
`(c) 2024 vqhapp`; the package is used unchanged at runtime.

## file_selector

LiteTodo uses the official Flutter `file_selector` package for the native
Windows open/save dialogs required by data import and export.  The existing
dependencies do not expose a supported native file-picker API: `path_provider`
only resolves application directories, while the window/tray packages do not
own file-dialog lifecycle or user cancellation semantics.  `file_selector` is
preferred over a custom Win32 FFI dialog because it keeps the Windows picker
implementation in the maintained Flutter plugin, avoids a second UI framework,
and does not add a runtime service or network dependency.  Its Windows
implementation is a small native plugin (no WebView or additional engine), so
the runtime and package-size impact is limited to the picker plugin and its
transitive platform registration.  The maintenance surface is the official
Flutter plugin API and platform package rather than bespoke FFI code.  The
package and its Windows implementation are distributed under the BSD 3-Clause
license; their license files are retained in the pub package cache and are not
modified by LiteTodo.

## screen_retriever

LiteTodo declares `screen_retriever` version `0.2.2` directly for reliable
display geometry queries used by Windows off-screen clamping.  The package was
already a transitive dependency of `window_manager`; the direct declaration
adds no new runtime plugin payload and only makes the API contract explicit.
The package is maintained by the Flutter community and is distributed under
the BSD 3-Clause license, retained unchanged from its pub package.
