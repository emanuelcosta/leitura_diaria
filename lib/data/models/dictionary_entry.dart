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
  final String term;
  final List<DictionaryDefinition> definitions;
  final List<String> refs;

  const DictionaryEntry({required this.term, required this.definitions, required this.refs});

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) => DictionaryEntry(
        term: json['term'] as String,
        definitions: (json['definitions'] as List)
            .cast<Map<String, dynamic>>()
            .map(DictionaryDefinition.fromJson)
            .toList(),
        refs: (json['refs'] as List).cast<String>(),
      );
}
