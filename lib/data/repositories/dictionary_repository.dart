import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../logic/text_normalize.dart';
import '../models/dictionary_entry.dart';

/// Serves Easton's/Smith's Bible dictionary entries from the bundled
/// assets/dictionary/easton_smith.json (English only — see ATTRIBUTION.md
/// in that folder for why). Parsed once and cached, same pattern as
/// BibleTextRepository.
class DictionaryRepository {
  static List<DictionaryEntry>? _cache;

  Future<List<DictionaryEntry>> _entries() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/dictionary/easton_smith.json');
    final entries = (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map(DictionaryEntry.fromJson).toList();
    _cache = entries;
    return entries;
  }

  /// Terms starting with [query] first, then terms containing it elsewhere —
  /// both accent/case-insensitive. Empty query returns nothing (the screen
  /// shows a hint instead of the whole 6k-entry list).
  Future<List<DictionaryEntry>> search(String query) async {
    final normalizedQuery = normalizeForSearch(query);
    if (normalizedQuery.isEmpty) return [];
    final entries = await _entries();
    final startsWith = <DictionaryEntry>[];
    final contains = <DictionaryEntry>[];
    for (final entry in entries) {
      final normalizedTerm = normalizeForSearch(entry.term);
      if (normalizedTerm.startsWith(normalizedQuery)) {
        startsWith.add(entry);
      } else if (normalizedTerm.contains(normalizedQuery)) {
        contains.add(entry);
      }
    }
    return [...startsWith, ...contains];
  }
}
