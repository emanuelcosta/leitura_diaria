import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../logic/text_normalize.dart';
import '../models/dictionary_entry.dart';

/// Serves Easton's/Smith's Bible dictionary entries from the bundled
/// assets/dictionary/easton_smith.json (definitions in English only — see
/// ATTRIBUTION.md in that folder for why). Headwords have a Portuguese
/// translation in terms_pt.json (English term → Portuguese), kept as a
/// separate file so the upstream dataset stays untouched. Parsed once and
/// cached, same pattern as BibleTextRepository.
class DictionaryRepository {
  static List<DictionaryEntry>? _cache;

  Future<List<DictionaryEntry>> _entries() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/dictionary/easton_smith.json');
    final rawPt = await rootBundle.loadString('assets/dictionary/terms_pt.json');
    final termsPt = (jsonDecode(rawPt) as Map<String, dynamic>).cast<String, String>();
    final entries = (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map((json) => DictionaryEntry.fromJson(json, termPt: termsPt[json['term']]))
        .toList();
    _cache = entries;
    return entries;
  }

  /// Terms starting with [query] first, then terms containing it elsewhere —
  /// matched against both the Portuguese and the English headword, accent/
  /// case-insensitive. Empty query returns nothing (the screen shows a hint
  /// instead of the whole 6k-entry list).
  Future<List<DictionaryEntry>> search(String query) async {
    final normalizedQuery = normalizeForSearch(query);
    if (normalizedQuery.isEmpty) return [];
    final entries = await _entries();
    final startsWith = <DictionaryEntry>[];
    final contains = <DictionaryEntry>[];
    for (final entry in entries) {
      final candidates = [
        normalizeForSearch(entry.term),
        if (entry.termPt != null) normalizeForSearch(entry.termPt!),
      ];
      if (candidates.any((t) => t.startsWith(normalizedQuery))) {
        startsWith.add(entry);
      } else if (candidates.any((t) => t.contains(normalizedQuery))) {
        contains.add(entry);
      }
    }
    return [...startsWith, ...contains];
  }
}
