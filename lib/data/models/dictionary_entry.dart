class DictionaryDefinition {
  /// 'EAS' (Easton's) or 'SMI' (Smith's) — see assets/dictionary/ATTRIBUTION.md.
  final String source;
  final String text;

  const DictionaryDefinition({required this.source, required this.text});

  factory DictionaryDefinition.fromJson(Map<String, dynamic> json) => DictionaryDefinition(
        source: json['source'] as String,
        text: json['text'] as String,
      );
}

class DictionaryEntry {
  /// Original (English) headword — also the key into terms_pt.json.
  final String term;

  /// Portuguese headword (names in Almeida spelling, e.g. Aaron → Arão),
  /// from assets/dictionary/terms_pt.json. Null if that file has no entry.
  final String? termPt;
  final List<DictionaryDefinition> definitions;
  final List<String> refs;

  const DictionaryEntry({
    required this.term,
    this.termPt,
    required this.definitions,
    required this.refs,
  });

  /// What the list shows as the title: Portuguese when available.
  String get displayTerm => termPt ?? term;

  factory DictionaryEntry.fromJson(Map<String, dynamic> json, {String? termPt}) => DictionaryEntry(
        term: json['term'] as String,
        termPt: termPt,
        definitions: (json['definitions'] as List)
            .cast<Map<String, dynamic>>()
            .map(DictionaryDefinition.fromJson)
            .toList(),
        refs: (json['refs'] as List).cast<String>(),
      );
}
