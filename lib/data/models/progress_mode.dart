/// What the home progress ring counts. Chapters is the plan's own unit;
/// verses weighs each chapter by its length (Salmo 117 has 2 verses, Salmo
/// 119 has 176), so it reflects how much of the text was actually read.
enum ProgressMode {
  chapters('Capítulos', 'capítulos'),
  verses('Versículos', 'versículos');

  /// Title-case, for the selector.
  final String label;

  /// Lowercase, for "123 / 1189 capítulos".
  final String unit;

  const ProgressMode(this.label, this.unit);
}
