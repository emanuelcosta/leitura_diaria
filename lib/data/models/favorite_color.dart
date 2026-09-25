import 'package:flutter/material.dart' show Color, Colors;

/// Color used to mark favorited verses (verse highlight + star icon). One
/// choice for all favorites, saved as a setting. Purple and light blue are
/// left out on purpose: they already mean "dúvida" and "selecionado" in the
/// reading screen, so a favorite in those colors would be ambiguous.
enum FavoriteColor {
  amber('Amarelo', Colors.amber),
  orange('Laranja', Colors.orange),
  green('Verde', Colors.green),
  teal('Azul-petróleo', Colors.teal),
  pink('Rosa', Colors.pink),
  red('Vermelho', Colors.red);

  final String label;
  final Color color;

  const FavoriteColor(this.label, this.color);

  /// Background tint behind a favorited verse — light enough to keep the
  /// text readable in both themes.
  Color get highlight => color.withValues(alpha: 0.18);
}
