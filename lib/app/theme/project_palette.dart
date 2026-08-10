import 'dart:ui';

class ProjectPaletteEntry {
  const ProjectPaletteEntry({
    required this.key,
    required this.accent,
    required this.softBackground,
    required this.border,
    required this.foreground,
  });

  final String key;
  final Color accent;
  final Color softBackground;
  final Color border;
  final Color foreground;
}

class ProjectPalette {
  const ProjectPalette._();

  static const values = <ProjectPaletteEntry>[
    ProjectPaletteEntry(
      key: 'red',
      accent: Color(0xFFE45A62),
      softBackground: Color(0x14E45A62),
      border: Color(0x44E45A62),
      foreground: Color(0xFFB83B45),
    ),
    ProjectPaletteEntry(
      key: 'orange',
      accent: Color(0xFFE99445),
      softBackground: Color(0x14E99445),
      border: Color(0x44E99445),
      foreground: Color(0xFFB86A1C),
    ),
    ProjectPaletteEntry(
      key: 'amber',
      accent: Color(0xFFE5B84B),
      softBackground: Color(0x14E5B84B),
      border: Color(0x44E5B84B),
      foreground: Color(0xFF9A7415),
    ),
    ProjectPaletteEntry(
      key: 'green',
      accent: Color(0xFF55B789),
      softBackground: Color(0x1455B789),
      border: Color(0x4455B789),
      foreground: Color(0xFF2D815B),
    ),
    ProjectPaletteEntry(
      key: 'teal',
      accent: Color(0xFF46B7AE),
      softBackground: Color(0x1446B7AE),
      border: Color(0x4446B7AE),
      foreground: Color(0xFF237B75),
    ),
    ProjectPaletteEntry(
      key: 'cyan',
      accent: Color(0xFF48B9D3),
      softBackground: Color(0x1448B9D3),
      border: Color(0x4448B9D3),
      foreground: Color(0xFF237F98),
    ),
    ProjectPaletteEntry(
      key: 'blue',
      accent: Color(0xFF6475F5),
      softBackground: Color(0x146475F5),
      border: Color(0x446475F5),
      foreground: Color(0xFF4A5AD0),
    ),
    ProjectPaletteEntry(
      key: 'indigo',
      accent: Color(0xFF6C70D9),
      softBackground: Color(0x146C70D9),
      border: Color(0x446C70D9),
      foreground: Color(0xFF4D51A4),
    ),
    ProjectPaletteEntry(
      key: 'violet',
      accent: Color(0xFF926CE6),
      softBackground: Color(0x14926CE6),
      border: Color(0x44926CE6),
      foreground: Color(0xFF6949B4),
    ),
    ProjectPaletteEntry(
      key: 'purple',
      accent: Color(0xFFB166D6),
      softBackground: Color(0x14B166D6),
      border: Color(0x44B166D6),
      foreground: Color(0xFF8246A5),
    ),
    ProjectPaletteEntry(
      key: 'pink',
      accent: Color(0xFFD66AA2),
      softBackground: Color(0x14D66AA2),
      border: Color(0x44D66AA2),
      foreground: Color(0xFFAD487D),
    ),
    ProjectPaletteEntry(
      key: 'gray',
      accent: Color(0xFF8B939E),
      softBackground: Color(0x148B939E),
      border: Color(0x448B939E),
      foreground: Color(0xFF616A76),
    ),
  ];

  static ProjectPaletteEntry resolve(String key) {
    for (final entry in values) {
      if (entry.key == key) return entry;
    }
    return values[5];
  }
}
