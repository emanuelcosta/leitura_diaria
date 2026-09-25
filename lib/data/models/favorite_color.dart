import 'package:flutter/material.dart' show Color, Colors;

/// The marker colors a favorited verse can have — each favorite carries its
/// own, so the text can be color-coded by study theme (the user names each
/// color in Configurações, e.g. Amarelo = Promessas). Purple and light blue
/// are left out on purpose: they already mean "dúvida" and "selecionado" in
/// the reading screen, so a marker in those colors would be ambiguous.
enum FavoriteColor {
  amber('Amarelo', Colors.amber),
  orange('Laranja', Colors.orange),
  green('Verde', Colors.green),
  teal('Azul-petróleo', Colors.teal),
  pink('Rosa', Colors.pink),
  red('Vermelho', Colors.red);

  /// The color's own name — the default marker name until the user renames it.
  final String label;
  final Color color;

  const FavoriteColor(this.label, this.color);

  /// Stored as [name] locally and in Supabase; anything unknown (older rows,
  /// a color removed later) falls back to amber, the original single color.
  static FavoriteColor fromName(String? name) =>
      FavoriteColor.values.firstWhere((c) => c.name == name, orElse: () => FavoriteColor.amber);

  /// Background tint behind a marked verse — light enough to keep the text
  /// readable in both themes.
  Color get highlight => color.withValues(alpha: 0.18);
}
